"""Controlled staging-only Redis/PostgreSQL pod restarts and recovery evidence.

Run explicitly from the operator workstation. Production is not restarted.
No application rows are written; credentials remain inside the API pod.
"""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
OUT = ROOT / ".runtime/final-evidence"
OUT.mkdir(parents=True, exist_ok=True)
KUBE = ["kubectl", "--kubeconfig=" + str(ROOT / ".runtime/kubeconfig")]
STAGING = KUBE + ["-n", "agribridge-staging"]


def run(arguments, **options):
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=options.pop("timeout", 60), **options)
    if result.returncode:
        raise RuntimeError(result.stderr[-1500:])
    return result.stdout


def api_script(source):
    return run(STAGING + ["exec", "-i", "deployment/agribridge-api", "--", "node", "--input-type=module", "-"], input=source)


SNAPSHOT = r'''
import {pool} from './src/db.js';
const snapshot={};
for(const table of ['users','lots','orders','order_events','schema_migrations']){
 const result=await pool.query("SELECT count(*)::int AS count, md5(COALESCE(string_agg((to_jsonb(t)-'password_hash')::text,'' ORDER BY (to_jsonb(t)-'password_hash')::text),'')) AS fingerprint FROM "+table+' t');
 snapshot[table]=result.rows[0];
}
await pool.end();console.log(JSON.stringify(snapshot));
'''

CACHE_OBSERVER = r'''
const origin='http://localhost:3000';
const read=async path=>{const response=await fetch(origin+path,{signal:AbortSignal.timeout(5000)});return {status:response.status,data:await response.json()};};
const login=await fetch(origin+'/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'amina.yusuf@example.ng',password:process.env.SEED_PASSWORD})});
if(login.status!==200)throw Error('Staging login failed before resilience test');
const cookie=login.headers.get('set-cookie')?.split(';')[0];
if(!cookie)throw Error('Login session missing');
const stats=async()=>{const r=await fetch(origin+'/api/stats/summary',{headers:{Cookie:cookie},signal:AbortSignal.timeout(5000)});if(r.status!==200)throw Error('Database-backed stats failed');const data=await r.json();return {status:r.status,cached:data.cached===true,open_lots:data.open_lots};};
const metric=async()=>{const r=await fetch(origin+'/metrics');return (await r.text()).split('\n').filter(x=>x.startsWith('cache_operations_total{'));};
const baseline=await read('/readyz');
if(baseline.status!==200||baseline.data.degraded||!baseline.data.checks.cache.ok)throw Error('Cache is not healthy at baseline');
await stats();await stats();
console.log(JSON.stringify({phase:'baseline',readiness:baseline,cache_metrics:await metric()}));
let degraded=false,recovered=false;
const deadline=Date.now()+150000;
while(Date.now()<deadline){
 const ready=await read('/readyz');
 if(ready.status===200&&ready.data.degraded&&!degraded){
  if(!ready.data.checks.database.ok)throw Error('Database failed during cache test');
  degraded=true;console.log(JSON.stringify({phase:'degraded',readiness:ready,stats:await stats(),cache_metrics:await metric()}));
 }
 if(degraded&&ready.status===200&&!ready.data.degraded&&ready.data.checks.cache.ok){
  await stats();const result=await stats();
  if(!result.cached)throw Error('Cache did not resume serving hits');
  recovered=true;console.log(JSON.stringify({phase:'recovered',readiness:ready,stats:result,cache_metrics:await metric()}));break;
 }
 await new Promise(resolve=>setTimeout(resolve,200));
}
if(!degraded||!recovered)throw Error('Did not observe both cache degradation and recovery');
'''


def main():
    context = run(KUBE + ["config", "current-context"]).strip()
    if context != "k8s.agribridge.deuces.dev":
        raise RuntimeError("Unexpected Kubernetes context")
    before = json.loads(api_script(SNAPSHOT))
    process = subprocess.Popen(STAGING + ["exec", "-i", "deployment/agribridge-api", "--", "node", "--input-type=module", "-"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    process.stdin.write(CACHE_OBSERVER)
    process.stdin.close()
    process.stdin = None
    first = process.stdout.readline()
    baseline = json.loads(first)
    if baseline.get("phase") != "baseline":
        raise RuntimeError("Cache observer did not establish its healthy baseline")
    redis = json.loads(run(STAGING + ["get", "pods", "-l", "app=agribridge-redis", "-o", "json"]))["items"]
    if len(redis) != 1:
        raise RuntimeError("Expected exactly one staging Redis pod")
    redis_name = redis[0]["metadata"]["name"]
    run(STAGING + ["delete", "pod", redis_name, "--wait=false"])
    rest, error = process.communicate(timeout=180)
    run(STAGING + ["rollout", "status", "deployment/agribridge-redis", "--timeout=120s"], timeout=140)
    if process.returncode:
        raise RuntimeError(error[-1500:])
    phases = [baseline] + [json.loads(line) for line in rest.splitlines() if line.strip()]
    if {row["phase"] for row in phases} != {"baseline", "degraded", "recovered"}:
        raise RuntimeError("Cache evidence is incomplete")
    (OUT / "cache-resilience.json").write_text(json.dumps({"passed": True, "restarted_pod": redis_name, "observations": phases}, indent=2) + "\n")
    print("Staging cache: HTTP 200 degradation, database fallback, login and cache-hit recovery passed.", flush=True)

    old = json.loads(run(STAGING + ["get", "pod", "agribridge-postgres-0", "-o", "json"]))
    claim_before = json.loads(run(STAGING + ["get", "pvc", "data-agribridge-postgres-0", "-o", "json"]))
    (OUT / "persistence-before.json").write_text(json.dumps({"old_pod_uid": old["metadata"]["uid"], "claim_uid": claim_before["metadata"]["uid"], "volume": claim_before["spec"]["volumeName"], "tables_before": before}, indent=2) + "\n")
    run(STAGING + ["delete", "pod", "agribridge-postgres-0", "--wait=true", "--timeout=90s"], timeout=110)
    deadline = time.monotonic() + 180
    new = None
    while time.monotonic() < deadline:
        result = subprocess.run(STAGING + ["get", "pod", "agribridge-postgres-0", "-o", "json"], capture_output=True, text=True, timeout=25)
        if result.returncode == 0:
            candidate = json.loads(result.stdout)
            ready = any(x["type"] == "Ready" and x["status"] == "True" for x in candidate["status"].get("conditions", []))
            if candidate["metadata"]["uid"] != old["metadata"]["uid"] and ready:
                new = candidate
                break
        time.sleep(2)
    if not new:
        raise RuntimeError("Replacement PostgreSQL pod did not become ready")
    # Pod readiness precedes endpoint/DNS propagation for a headless Service.
    after = None
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        try:
            after = json.loads(api_script(SNAPSHOT))
            break
        except RuntimeError:
            time.sleep(2)
    if after is None:
        raise RuntimeError("PostgreSQL Service did not become queryable after replacement")
    claim_after = json.loads(run(STAGING + ["get", "pvc", "data-agribridge-postgres-0", "-o", "json"]))
    if before != after:
        raise RuntimeError("Database row counts/fingerprints changed during the restart")
    if claim_before["metadata"]["uid"] != claim_after["metadata"]["uid"] or claim_before["spec"]["volumeName"] != claim_after["spec"]["volumeName"]:
        raise RuntimeError("The PostgreSQL claim identity changed")
    evidence = {"passed": True, "old_pod_uid": old["metadata"]["uid"], "new_pod_uid": new["metadata"]["uid"], "volume": claim_after["spec"]["volumeName"], "claim_uid": claim_after["metadata"]["uid"], "tables_before": before, "tables_after": after}
    (OUT / "database-persistence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print("Staging PostgreSQL: replacement pod reused the same claim and preserved all five table fingerprints.", flush=True)


if __name__ == "__main__":
    main()
