"""Verify public HTTPS readiness and exact build identity after an Argo CD sync."""
import argparse
import json
from pathlib import Path
import time
from urllib.request import urlopen
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("environment", choices=["staging", "production"])
parser.add_argument("image_tag")
parser.add_argument("--timeout", type=int, default=900)
args = parser.parse_args()
values = yaml.safe_load(Path("argocd/" + args.environment + "-values.yaml").read_text())
hostname = values["hostname"]
if hostname != args.environment + ".agribridge.deuces.dev":
    raise SystemExit("Unexpected release hostname")
origin = "https://" + hostname
deadline = time.monotonic() + args.timeout
last_error = "not checked"
while time.monotonic() < deadline:
    try:
        with urlopen(origin + "/readyz", timeout=10) as response:
            if response.status != 200:
                raise ValueError("API is not ready")
        with urlopen(origin + "/version", timeout=10) as response:
            version = json.loads(response.read(65536))
        if version.get("imageTag") != args.image_tag:
            raise ValueError("Waiting for requested image tag")
        if version.get("gitSha") != args.image_tag.split("-")[0]:
            raise ValueError("Running source commit does not match the artifact")
        with urlopen(origin + "/", timeout=10) as response:
            if response.status != 200:
                raise ValueError("Frontend is not ready")
        print(args.environment + " HTTPS, readiness and build identity passed.")
        break
    except Exception as error:
        last_error = type(error).__name__ + ": " + str(error)
        time.sleep(10)
else:
    raise SystemExit("Release verification timed out: " + last_error)
