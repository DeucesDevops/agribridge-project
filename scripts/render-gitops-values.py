"""Consume non-secret Terraform-published SSM metadata; preserve image selections."""
import argparse
import json
from pathlib import Path
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("environment", choices=["staging", "production"])
parser.add_argument("metadata", type=Path)
args = parser.parse_args()
data = json.loads(args.metadata.read_text())
environment = args.environment
if data["namespace"] != "agribridge-" + environment:
    raise SystemExit("Unexpected environment namespace")
if data["region"] != "us-east-1" or data["hostname"] != environment + ".agribridge.deuces.dev":
    raise SystemExit("Unexpected region or hostname")
if not data["secret_arn"].startswith("arn:aws:secretsmanager:us-east-1:237258628535:secret:agribridge-" + environment + "/runtime-v2-"):
    raise SystemExit("Unexpected runtime secret identity")
if data["backup_bucket"] != "agribridge-backups-237258628535":
    raise SystemExit("Unexpected backup bucket")
if data["backup_role"] != "arn:aws:iam::237258628535:role/agribridge-" + environment + "-backup":
    raise SystemExit("Unexpected backup role")
path = Path("argocd") / (environment + "-values.yaml")
values = yaml.safe_load(path.read_text()) if path.exists() else {}
values.setdefault("releaseEnabled", False)
values["requireImageDigests"] = True
for key in ("hostname", "region"):
    values[key] = data[key]
values["secretArn"] = data["secret_arn"]
for component, source in (("api", "api_repository"), ("web", "web_repository")):
    image = values.setdefault(component, {})
    image["repository"] = data[source]
    image.setdefault("tag", "awaiting-first-ci-build")
    image.setdefault("digest", "")
values["backup"] = {"enabled": True, "bucket": data["backup_bucket"],
                    "role": data["backup_role"], "prefix": environment}
path.write_text("# Generated from Terraform-published non-secret metadata; images are managed by CI.\n"
                + yaml.safe_dump(values, sort_keys=False))
