"""Render the pinned ingress chart and verify its TLS/NLB contract without AWS."""
import argparse
from pathlib import Path
import subprocess
import tempfile

import yaml


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chart", default="oci://ghcr.io/nginx/charts/nginx-ingress")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        values = Path(directory) / "values.yaml"
        values.write_text(Path("helm/platform/nginx-ingress-values.yaml.tftpl").read_text().replace(
            "${certificate_arn}", "arn:aws:acm:us-east-1:123456789012:certificate/validation"))
        rendered = subprocess.run([
            "helm", "template", "nginx-ingress", args.chart, "--version", "2.8.0",
            "--namespace", "ingress", "--kube-version", "1.36.6", "--skip-crds",
            "--values", str(values),
        ], check=True, capture_output=True, text=True).stdout
    service = next(resource for resource in yaml.safe_load_all(rendered)
                   if resource and resource.get("kind") == "Service"
                   and resource["metadata"]["name"] == "nginx-ingress-controller")
    spec = service["spec"]
    if spec["type"] != "LoadBalancer" or spec["loadBalancerClass"] != "service.k8s.aws/nlb":
        raise ValueError("NGINX must use the AWS NLB service contract")
    if len(spec["ports"]) != 1 or spec["ports"][0]["port"] != 443 or spec["ports"][0]["targetPort"] != 80:
        raise ValueError("Expected only TLS 443 to backend HTTP 80")
    print("Pinned NGINX chart passed the TLS/NLB service contract.")


if __name__ == "__main__":
    main()
