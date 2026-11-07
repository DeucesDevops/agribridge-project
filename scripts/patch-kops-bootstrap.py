"""Scope the kOps 1.36 LB service webhook to LoadBalancer services.

Without this, installing the webhook before default/kubernetes exists deadlocks
cold bootstrap. Keep the fix in generated Terraform input before every apply.
--live reconciles an already-created cluster via the Kubernetes API (no SSH).
"""
import json
import subprocess
import sys
from pathlib import Path
import yaml
condition = [{"name": "load-balancer-only", "expression": "object.spec.type == 'LoadBalancer'"}]
for path in Path('terraform/generated/kops/data').glob('*aws-load-balancer*content'):
    docs = list(yaml.safe_load_all(path.read_text()))
    for doc in docs:
        if not doc or doc.get('kind') != 'MutatingWebhookConfiguration':
            continue
        for i, hook in enumerate(doc['webhooks']):
            if hook['name'] == 'mservice.elbv2.k8s.aws':
                hook['matchConditions'] = condition
                if '--live' in sys.argv:
                    subprocess.run(['kubectl', 'patch', 'mutatingwebhookconfiguration',
                        doc['metadata']['name'], '--type=json', '-p', json.dumps([
                            {'op': 'add', 'path': f'/webhooks/{i}/matchConditions', 'value': condition}
                        ])], check=True)
    path.write_text(yaml.safe_dump_all(docs, sort_keys=False))
