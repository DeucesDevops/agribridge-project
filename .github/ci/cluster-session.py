"""Shared short-lived cluster session for trusted infrastructure/operations jobs."""
import os
from pathlib import Path
import subprocess


def main():
    cluster = os.environ["CLUSTER_NAME"]
    path = Path(os.environ["GITHUB_WORKSPACE"]) / ".runtime/automation/kubeconfig"
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.environ["KUBECONFIG"] = str(path)
    subprocess.run(["kops", "export", "kubeconfig", cluster, "--admin=1h", "--kubeconfig", str(path)], check=True)
    context = subprocess.check_output(["kubectl", "config", "current-context"], text=True).strip()
    server = subprocess.check_output([
        "kubectl", "config", "view", "--minify", "-o", "jsonpath={.clusters[0].cluster.server}"
    ], text=True).strip()
    if context != cluster or server != "https://api." + cluster:
        raise ValueError("Refusing an unexpected cluster context or API endpoint")
    path.chmod(0o600)
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write(f"KUBECONFIG={path}\n")


if __name__ == "__main__":
    main()
