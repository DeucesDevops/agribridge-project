"""Prepare kOps Terraform input and wait for platform prerequisites.

GitHub Actions owns sequencing and Terraform execution. This helper only handles
kOps-specific manifest generation and its pinned bootstrap compatibility fix.
"""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import time

import yaml


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def render(outputs, cidrs, cluster_name):
    networks = [ipaddress.ip_network(item.strip(), strict=True) for item in cidrs.split(",")]
    for network in networks:
        if not network.is_global or network.prefixlen < (24 if network.version == 4 else 64):
            raise ValueError("API access requires narrow public runner/VPN CIDRs")
    documents = list(yaml.safe_load_all(Path("kubedefs/cluster.yaml").read_text()))
    cluster = next(item for item in documents if item["kind"] == "Cluster")
    if cluster["metadata"]["name"] != cluster_name:
        raise ValueError("Unexpected cluster identity")
    cluster["spec"]["kubernetesApiAccess"] = [str(network) for network in networks]
    cluster["spec"]["configBase"] = outputs["kops_state_store"]["value"] + "/" + cluster_name
    cluster["spec"]["serviceAccountIssuerDiscovery"]["discoveryStore"] = outputs["discovery_store"]["value"]
    return yaml.safe_dump_all(documents, sort_keys=False)


def prepare_generated(directory):
    source = directory / "kubernetes.tf"
    text = source.read_text()
    # Keep provider configuration in the handwritten root, with its aws.files alias.
    source.write_text(re.sub(r'(?ms)^provider "aws" \{.*?^\}\n?', "", text))
    expected = set(re.findall(r'^output "([^"]+)"', Path("terraform/cluster/outputs.tf").read_text(), re.M))
    actual = set(re.findall(r'^output "([^"]+)"', text, re.M))
    if not expected <= actual:
        raise ValueError("kOps output contract changed: " + ", ".join(sorted(expected - actual)))
    for path in (directory / "data").glob("*aws-load-balancer*content"):
        documents = list(yaml.safe_load_all(path.read_text()))
        for document in documents:
            if document and document.get("kind") == "MutatingWebhookConfiguration":
                for hook in document["webhooks"]:
                    if hook["name"] == "mservice.elbv2.k8s.aws":
                        hook["matchConditions"] = [{"name": "load-balancer-only",
                                                    "expression": "object.spec.type == 'LoadBalancer'"}]
        path.write_text(yaml.safe_dump_all(documents, sort_keys=False))


def generate(outputs_path, cidrs, destroy):
    outputs = json.loads(outputs_path.read_text())
    cluster_name = os.environ["CLUSTER_NAME"]
    os.environ["KOPS_STATE_STORE"] = outputs["kops_state_store"]["value"]
    # DNS delegation must already point to the Terraform-managed child zone.
    names = run("dig", "+short", "NS", "agribridge.deuces.dev", capture_output=True).stdout
    if {name.rstrip(".").lower() for name in names.split()} != {
        name.rstrip(".").lower() for name in outputs["name_servers"]["value"]
    }:
        raise ValueError("Delegate the project DNS zone before planning the cluster")
    if not destroy:
        Path(".runtime/automation/cluster.yaml").write_text(render(outputs, cidrs, cluster_name))
        # List successfully before deciding absence; never mistake access failure for absence.
        result = subprocess.run(["kops", "get", "clusters", "-o", "json"], text=True, capture_output=True)
        if result.returncode:
            if result.stderr.strip().splitlines()[-1:] != ["Error: no clusters found"] or result.stdout.strip():
                raise RuntimeError("Cannot read the kOps state store; refusing to create a cluster")
            clusters = []
        else:
            data = json.loads(result.stdout)
            clusters = data if isinstance(data, list) else data["items"]
        exists = any(item["metadata"]["name"] == cluster_name for item in clusters)
        run("kops", "replace" if exists else "create", "-f", ".runtime/automation/cluster.yaml")
    run("kops", "update", "cluster", cluster_name, "--target=terraform",
        "--out=terraform/generated/kops", "--create-kube-config=false")
    prepare_generated(Path("terraform/generated/kops"))


def wait():
    run("kubectl", "wait", "--for=condition=Ready", "nodes", "--all", "--timeout=900s")
    for deployment in ("aws-load-balancer-controller", "pod-identity-webhook", "ebs-csi-controller"):
        run("kubectl", "-n", "kube-system", "rollout", "status", "deployment/" + deployment, "--timeout=900s")
    for service in ("aws-load-balancer-webhook-service", "pod-identity-webhook"):
        for attempt in range(90):
            result = run("kubectl", "-n", "kube-system", "get", "endpointslices", "-l",
                         "kubernetes.io/service-name=" + service, "-o", "json", capture_output=True)
            slices = json.loads(result.stdout)["items"]
            if any(endpoint.get("conditions", {}).get("ready") and endpoint.get("addresses")
                   for item in slices for endpoint in item.get("endpoints", [])):
                break
            time.sleep(5)
        else:
            raise RuntimeError("Admission service has no ready endpoints: " + service)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    generate_parser = commands.add_parser("generate")
    generate_parser.add_argument("--outputs", type=Path, default=Path(".runtime/bootstrap-outputs.json"))
    generate_parser.add_argument("--cidrs", default=os.environ.get("AGRIBRIDGE_API_CIDRS", ""))
    generate_parser.add_argument("--destroy", action="store_true")
    commands.add_parser("wait")
    args = parser.parse_args()
    if args.command == "generate":
        generate(args.outputs, args.cidrs, args.destroy)
    else:
        wait()


if __name__ == "__main__":
    main()
