"""Record published digests and update the reviewed GitOps values.

Secret values are never read. Only CI's commit command writes to GitHub.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import re
import subprocess

import yaml


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def validate_images(images):
    for component in ("api", "web"):
        image = images[component]
        if not re.fullmatch(r"docker\.io/[a-z0-9_-]+/agribridge-(api|web)", image["repository"]):
            raise ValueError("Unexpected image repository")
        if not image["repository"].endswith("/agribridge-" + component):
            raise ValueError("Image component mismatch")
        if not re.fullmatch(r"[0-9a-f]{40}-[0-9]+-[0-9]+", image["tag"]):
            raise ValueError("Expected commit/run/attempt image tag")
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", image["digest"]):
            raise ValueError("A published immutable image digest is required")
    if images["api"]["tag"] != images["web"]["tag"]:
        raise ValueError("API and frontend must belong to the same release")


def values_path(environment):
    return Path("argocd") / (environment + "-values.yaml")


def configure(environment, metadata_path):
    """Refresh Terraform-published runtime references without changing a release."""
    data = json.loads(metadata_path.read_text())
    account = os.environ.get("EXPECTED_AWS_ACCOUNT_ID", "237258628535")
    if data["namespace"] != "agribridge-" + environment:
        raise ValueError("Unexpected environment namespace")
    if data["region"] != "us-east-1" or data["hostname"] != environment + ".agribridge.deuces.dev":
        raise ValueError("Unexpected region or hostname")
    if not data["secret_arn"].startswith(
        "arn:aws:secretsmanager:us-east-1:" + account + ":secret:agribridge-" + environment + "/runtime-v2-"
    ):
        raise ValueError("Unexpected runtime secret identity")
    if data["backup_bucket"] != "agribridge-backups-" + account:
        raise ValueError("Unexpected backup bucket")
    if data["backup_role"] != "arn:aws:iam::" + account + ":role/agribridge-" + environment + "-backup":
        raise ValueError("Unexpected backup role")
    path = values_path(environment)
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
    path.write_text(yaml.safe_dump(values, sort_keys=False))


def record(destination):
    images = {}
    for component, variable in (("api", "API_IMAGE"), ("web", "WEB_IMAGE")):
        repository, tag = os.environ[variable], os.environ["IMAGE_TAG"]
        raw = run("docker", "image", "inspect", repository + ":" + tag,
                  "--format", "{{json .RepoDigests}}", capture_output=True).stdout
        candidates = json.loads(raw) or []
        canonical = repository.removeprefix("docker.io/")
        matches = [entry.split("@", 1)[1] for entry in candidates
                   if entry.split("@", 1)[0].removeprefix("docker.io/") == canonical]
        if len(set(matches)) != 1:
            raise ValueError("Cannot identify the pushed digest for " + component)
        images[component] = {"repository": repository, "tag": tag, "digest": matches[0]}
    validate_images(images)
    release = {"gitSha": os.environ["GITHUB_SHA"], "images": images}
    if release["gitSha"] != images["api"]["tag"].split("-")[0]:
        raise ValueError("Build commit and release tag disagree")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(release, indent=2) + "\n")


def stage(release_path):
    release = json.loads(release_path.read_text())
    validate_images(release["images"])
    if release["gitSha"] != release["images"]["api"]["tag"].split("-")[0]:
        raise ValueError("Release commit and image tags disagree")
    path = values_path("staging")
    values = yaml.safe_load(path.read_text())
    values.update(copy.deepcopy(release["images"]))
    values["releaseEnabled"] = True
    values["release"] = {"gitSha": release["gitSha"]}
    path.write_text(yaml.safe_dump(values, sort_keys=False))


def promote(expected_tag):
    staging = yaml.safe_load(values_path("staging").read_text())
    validate_images(staging)
    if not staging["releaseEnabled"] or staging["api"]["tag"] != expected_tag:
        raise ValueError("Staging no longer contains the release that passed verification")
    if staging["release"]["gitSha"] != expected_tag.split("-")[0]:
        raise ValueError("Staging commit and release tag disagree")
    path = values_path("production")
    production = yaml.safe_load(path.read_text())
    for key in ("api", "web", "release"):
        production[key] = copy.deepcopy(staging[key])
    production["releaseEnabled"] = True
    path.write_text(yaml.safe_dump(production, sort_keys=False))


def commit(environment, expected_tag):
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Automatic Git writes are restricted to GitHub Actions")
    path = values_path(environment)
    values = yaml.safe_load(path.read_text())
    validate_images(values)
    if not values["releaseEnabled"] or values["api"]["tag"] != expected_tag:
        raise ValueError("Refusing to commit an unexpected release")
    # A new source push must be built and checked by its own queued workflow.
    run("git", "diff", "--exit-code", expected_tag.split("-")[0], "HEAD", "--",
        "api", "frontend", "helm/agribridge", "scripts", ".github/workflows",
        "docker-compose.yml", "argocd/project.yaml",
        "argocd/staging-application.yaml", "argocd/production-application.yaml")
    changed = subprocess.run(["git", "diff", "--quiet", "--", str(path)])
    if changed.returncode == 0:
        print("Desired release already matches Git.")
        return
    if changed.returncode != 1:
        raise RuntimeError("Could not inspect the release diff")
    run("git", "config", "user.name", "github-actions[bot]")
    run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    run("git", "add", "--", str(path))
    run("git", "commit", "--only", "-m",
        "Release " + environment + ": " + expected_tag + " [skip ci]", "--", str(path))
    # A concurrent main update rejects this push; never force or overwrite it.
    run("git", "push", "origin", "HEAD:main")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    record_parser = commands.add_parser("record")
    record_parser.add_argument("destination", type=Path)
    configure_parser = commands.add_parser("configure")
    configure_parser.add_argument("environment", choices=["staging", "production"])
    configure_parser.add_argument("metadata", type=Path)
    stage_parser = commands.add_parser("stage")
    stage_parser.add_argument("release", type=Path)
    promote_parser = commands.add_parser("promote")
    promote_parser.add_argument("--expected-tag", required=True)
    commit_parser = commands.add_parser("commit")
    commit_parser.add_argument("environment", choices=["staging", "production"])
    commit_parser.add_argument("--expected-tag", required=True)
    args = parser.parse_args()
    if args.command == "configure":
        configure(args.environment, args.metadata)
    elif args.command == "record":
        record(args.destination)
    elif args.command == "stage":
        stage(args.release)
    elif args.command == "promote":
        promote(args.expected_tag)
    else:
        commit(args.environment, args.expected_tag)


if __name__ == "__main__":
    main()
