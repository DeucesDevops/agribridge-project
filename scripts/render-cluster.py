"""Render a private operator-scoped kOps manifest from bootstrap outputs."""
import ipaddress, json, os
from pathlib import Path
import yaml
outputs = json.loads(Path('.runtime/bootstrap-outputs.json').read_text())
cidrs = [str(ipaddress.ip_network(s.strip(), strict=True)) for s in os.environ['AGRIBRIDGE_API_CIDRS'].split(',')]
for cidr in cidrs:
    network = ipaddress.ip_network(cidr)
    if not network.is_global or network.prefixlen < (24 if network.version == 4 else 64):
        raise SystemExit('API access must use a narrow public operator/VPN CIDR.')
docs = list(yaml.safe_load_all(Path('kubedefs/cluster.yaml').read_text()))
cluster = next(d for d in docs if d['kind'] == 'Cluster')
assert cluster['metadata']['name'] == os.environ['CLUSTER_NAME']
cluster['spec']['kubernetesApiAccess'] = cidrs
cluster['spec']['configBase'] = outputs['kops_state_store']['value'] + '/' + os.environ['CLUSTER_NAME']
cluster['spec']['serviceAccountIssuerDiscovery']['discoveryStore'] = outputs['discovery_store']['value']
Path('.runtime/cluster.yaml').write_text(yaml.safe_dump_all(docs, sort_keys=False))
