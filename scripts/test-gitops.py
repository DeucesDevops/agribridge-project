"""Release safety and real Helm rendering checks; no AWS, Docker or Git writes."""
import copy
import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import yaml

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release", ROOT / "scripts/gitops-release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
TAG = "a" * 40 + "-123-1"
IMAGES = {
    "api": {"repository": "docker.io/macroni607/agribridge-api", "tag": TAG, "digest": "sha256:" + "1" * 64},
    "web": {"repository": "docker.io/macroni607/agribridge-web", "tag": TAG, "digest": "sha256:" + "2" * 64},
}


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.directory.name)
        Path("argocd").mkdir()
        for environment in ("staging", "production"):
            source = yaml.safe_load((ROOT / "argocd" / (environment + "-values.yaml")).read_text())
            Path("argocd/" + environment + "-values.yaml").write_text(yaml.safe_dump(source))
        Path("release.json").write_text(json.dumps({"gitSha": "a" * 40, "images": IMAGES}))

    def tearDown(self):
        os.chdir(self.previous)
        self.directory.cleanup()

    def test_stage_preserves_runtime_configuration(self):
        before = yaml.safe_load(release.values_path("staging").read_text())
        release.stage(Path("release.json"))
        after = yaml.safe_load(release.values_path("staging").read_text())
        self.assertEqual(after["api"], IMAGES["api"])
        self.assertTrue(after["releaseEnabled"])
        for key in ("hostname", "secretArn", "region", "backup"):
            self.assertEqual(after[key], before[key])

    def test_production_gets_identical_digests_and_keeps_its_own_runtime(self):
        production = yaml.safe_load(release.values_path("production").read_text())
        release.stage(Path("release.json"))
        release.promote(TAG)
        result = yaml.safe_load(release.values_path("production").read_text())
        self.assertEqual({key: result[key] for key in IMAGES}, IMAGES)
        for key in ("hostname", "secretArn", "region", "backup"):
            self.assertEqual(result[key], production[key])

    def test_rejects_promotion_of_a_different_staging_release(self):
        release.stage(Path("release.json"))
        with self.assertRaises(ValueError):
            release.promote("b" * 40 + "-123-1")

    def test_rejects_unpinned_or_mixed_images(self):
        for key, replacement in (("digest", ""), ("tag", "latest"), ("repository", "docker.io/macroni607/agribridge-web")):
            bad = copy.deepcopy(IMAGES)
            bad["api"][key] = replacement
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.validate_images(bad)
        bad = copy.deepcopy(IMAGES)
        bad["web"]["tag"] = "b" * 40 + "-123-1"
        with self.assertRaises(ValueError):
            release.validate_images(bad)

    def test_commit_command_cannot_publish_from_a_local_shell(self):
        release.stage(Path("release.json"))
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}), self.assertRaises(ValueError):
            release.commit("staging", TAG)

    def test_record_requires_the_actual_pushed_repository_digest(self):
        with patch.dict(os.environ, {"API_IMAGE": IMAGES["api"]["repository"], "WEB_IMAGE": IMAGES["web"]["repository"],
                                     "IMAGE_TAG": TAG, "GITHUB_SHA": "a" * 40}):
            def inspect(*args, **kwargs):
                image = args[3].split(":")[0]
                component = "api" if image.endswith("-api") else "web"
                return subprocess.CompletedProcess(args, 0, json.dumps([image + "@" + IMAGES[component]["digest"]]))
            with patch.object(release, "run", side_effect=inspect):
                release.record(Path("published.json"))
            self.assertEqual(json.loads(Path("published.json").read_text())["images"], IMAGES)
            with patch.object(release, "run", return_value=subprocess.CompletedProcess([], 0, "[]")), self.assertRaises(ValueError):
                release.record(Path("invalid.json"))

    def test_regenerating_runtime_values_preserves_an_existing_release(self):
        release.stage(Path("release.json"))
        staged = yaml.safe_load(release.values_path("staging").read_text())
        metadata = {"namespace": "agribridge-staging", "region": staged["region"],
                    "hostname": staged["hostname"], "secret_arn": staged["secretArn"],
                    "api_repository": staged["api"]["repository"], "web_repository": staged["web"]["repository"],
                    "backup_bucket": staged["backup"]["bucket"], "backup_role": staged["backup"]["role"]}
        Path("metadata.json").write_text(json.dumps(metadata))
        command = [sys.executable, str(ROOT / "scripts/render-gitops-values.py"), "staging", "metadata.json"]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        after = yaml.safe_load(release.values_path("staging").read_text())
        self.assertEqual(after["api"], IMAGES["api"])
        self.assertTrue(after["releaseEnabled"])
        metadata["secret_arn"] = metadata["secret_arn"].replace("237258628535", "000000000000")
        Path("metadata.json").write_text(json.dumps(metadata))
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(yaml.safe_load(release.values_path("staging").read_text()), after)

    def test_argo_install_flag_is_preserved_on_followup_platform_plans(self):
        script = (ROOT / "scripts/plan-platform.sh").read_text()
        marker = "python3 - \".runtime/platform-output-$run_id.json\" <<'PY'\n"
        body = script.split(marker, 1)[1].split("\nPY\n", 1)[0]
        Path(".runtime").mkdir()
        platform = {"region": "us-east-1", "zone_name": "agribridge.deuces.dev",
                    "zone_id": "ZTEST", "certificate_arn": "arn:aws:acm:us-east-1:237258628535:certificate/test",
                    "secrets_role": "arn:aws:iam::237258628535:role/agribridge-external-secrets",
                    "logs_role": "arn:aws:iam::237258628535:role/agribridge-logs"}
        Path(".runtime/output.json").write_text(json.dumps(platform))
        base = dict(os.environ, KUBECONFIG=str(Path(".runtime/kubeconfig").resolve()))
        base.pop("AGRIBRIDGE_ENABLE_ARGOCD", None)
        for override, expected in ((None, False), ("true", True), (None, True)):
            env = dict(base)
            if override is not None:
                env["AGRIBRIDGE_ENABLE_ARGOCD"] = override
            result = subprocess.run([sys.executable, "-c", body, ".runtime/output.json"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(Path(".runtime/platform.tfvars.json").read_text())["enable_argocd"], expected)
        result = subprocess.run([sys.executable, "-c", body, ".runtime/output.json"],
                                env=dict(base, AGRIBRIDGE_ENABLE_ARGOCD="invalid"), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)


class RenderTests(unittest.TestCase):
    def test_terraform_bootstrap_chart_renders_exactly_the_reviewed_definitions(self):
        paths = ["project.yaml", "staging-application.yaml", "production-application.yaml"]
        expected = [yaml.safe_load((ROOT / "argocd" / path).read_text()) for path in paths]
        with tempfile.TemporaryDirectory() as directory:
            values = Path(directory) / "values.yaml"
            values.write_text(yaml.safe_dump({"resources": expected}))
            result = subprocess.run(["helm", "template", "argocd-bootstrap",
                                     str(ROOT / "helm/argocd-bootstrap"), "-n", "argocd",
                                     "-f", str(values)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(yaml.safe_load_all(result.stdout)), expected)

    def render(self, environment, enabled=True, invalid=False):
        command = ["helm", "template", "agribridge", str(ROOT / "helm/agribridge"),
                   "--namespace", "agribridge-" + environment,
                   "-f", str(ROOT / "helm/agribridge" / ("values-" + environment + ".yaml")),
                   "-f", str(ROOT / "argocd" / (environment + "-values.yaml")),
                   "--set", "releaseEnabled=" + str(enabled).lower()]
        if enabled:
            for component, image in IMAGES.items():
                command += ["--set-string", component + ".digest=" + ("" if invalid else image["digest"]),
                            "--set-string", component + ".tag=" + TAG]
        return subprocess.run(command, capture_output=True, text=True)

    def test_bootstrap_renders_no_placeholder_workloads(self):
        for environment in ("staging", "production"):
            result = self.render(environment, enabled=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(yaml.safe_load_all(result.stdout)), [])

    def test_live_release_requires_published_digests(self):
        result = self.render("staging", invalid=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("require published image digests", result.stderr)

    def test_both_environment_renders_keep_secrets_external_and_storage_persistent(self):
        project = yaml.safe_load((ROOT / "argocd/project.yaml").read_text())
        allowed = {(entry["group"], entry["kind"]) for entry in project["spec"]["namespaceResourceWhitelist"]}
        for environment in ("staging", "production"):
            result = self.render(environment)
            self.assertEqual(result.returncode, 0, result.stderr)
            documents = [d for d in yaml.safe_load_all(result.stdout) if d]
            resources = {(d["kind"], d["metadata"]["name"]): d for d in documents}
            for document in documents:
                group = document["apiVersion"].split("/")[0] if "/" in document["apiVersion"] else ""
                self.assertIn((group, document["kind"]), allowed)
                self.assertNotEqual(document["kind"], "Secret")
            config = resources[("ConfigMap", "agribridge-config")]["data"]
            self.assertFalse(set(config) & {"PGPASSWORD", "JWT_SECRET", "SEED_PASSWORD"})
            external = resources[("ExternalSecret", "agribridge")]
            self.assertEqual(external["metadata"]["annotations"]["argocd.argoproj.io/sync-wave"], "-2")
            self.assertIn("agribridge-" + environment + "/runtime-v2-", external["spec"]["dataFrom"][0]["extract"]["key"])
            for component in ("api", "web"):
                deployment = resources[("Deployment", "agribridge-" + component)]
                container = deployment["spec"]["template"]["spec"]["containers"][0]
                self.assertEqual(container["image"], IMAGES[component]["repository"] + "@" + IMAGES[component]["digest"])
            database = resources[("StatefulSet", "agribridge-postgres")]
            claim = database["spec"]["volumeClaimTemplates"][0]["spec"]
            self.assertEqual(claim["storageClassName"], "agribridge-gp3")
            self.assertEqual(claim["resources"]["requests"]["storage"], "20Gi")
            self.assertEqual(("Job", "agribridge-seed") in resources, environment == "staging")

    def test_backup_upload_command_has_a_valid_s3_destination(self):
        stub = 'aws() { [ "$#" -eq 5 ] || return 90; [ "$1" = s3 ] || return 91; [ "$2" = cp ] || return 92; printf "%s\\n" "$4"; }\n'
        for environment in ("staging", "production"):
            with self.subTest(environment=environment):
                rendered = self.render(environment)
                self.assertEqual(rendered.returncode, 0, rendered.stderr)
                job = next(doc for doc in yaml.safe_load_all(rendered.stdout) if doc and doc["kind"] == "CronJob")
                command = job["spec"]["jobTemplate"]["spec"]["template"]["spec"]["containers"][0]["args"][0]
                result = subprocess.run(["sh", "-ec", stub + command], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                values = yaml.safe_load((ROOT / "argocd" / (environment + "-values.yaml")).read_text())
                prefix = "s3://" + values["backup"]["bucket"] + "/" + values["backup"]["prefix"] + "/"
                self.assertRegex(result.stdout.strip(), "^" + re.escape(prefix) + r"\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z\.dump$")

    def test_workflow_deployment_uses_git_and_has_no_cluster_credentials(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/delivery.yaml").read_text())
        jobs = workflow["jobs"]
        self.assertEqual(jobs["publish"]["needs"], "checks")
        self.assertIn("staging", jobs["production"]["needs"])
        for environment in ("staging", "production"):
            rendered = yaml.safe_dump(jobs[environment])
            self.assertIn("gitops-release.py", rendered)
            self.assertNotIn("scripts/deploy.sh", rendered)
            self.assertNotIn("configure-aws-credentials", rendered)
            self.assertNotIn("id-token", rendered)
        for environment in ("staging", "production"):
            app = yaml.safe_load((ROOT / "argocd" / (environment + "-application.yaml")).read_text())
            self.assertEqual(app["spec"]["destination"]["namespace"], "agribridge-" + environment)
            self.assertEqual(app["spec"]["source"]["helm"]["releaseName"], "agribridge")
            self.assertFalse(app["spec"]["syncPolicy"]["automated"]["prune"])
            for value in app["spec"]["source"]["helm"]["valueFiles"]:
                self.assertTrue((ROOT / "helm/agribridge" / value).resolve().is_file())


if __name__ == "__main__":
    unittest.main(verbosity=2)
