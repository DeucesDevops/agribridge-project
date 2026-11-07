"""Offline checks for cluster preparation, destructive guards and restore isolation."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("cluster", ROOT / "scripts/prepare-cluster.py")
cluster = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cluster)


def workflow(name):
    return yaml.safe_load((ROOT / ".github/workflows" / name).read_text())


def step_named(job, name):
    return next(step for step in job["steps"] if step.get("name") == name)


class ClusterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.directory.name)
        Path("kubedefs").mkdir()
        Path("kubedefs/cluster.yaml").write_text((ROOT / "kubedefs/cluster.yaml").read_text())
        Path(".runtime/automation").mkdir(parents=True)
        self.outputs = {"kops_state_store": {"value": "s3://kops-state-607"},
                        "discovery_store": {"value": "s3://agribridge-oidc-237258628535"},
                        "name_servers": {"value": ["ns.example.net."]}}

    def tearDown(self):
        os.chdir(self.previous)
        self.directory.cleanup()

    def test_runner_cidr_replaces_placeholder_without_changing_instance_groups(self):
        before = list(yaml.safe_load_all(Path("kubedefs/cluster.yaml").read_text()))
        after = list(yaml.safe_load_all(cluster.render(self.outputs, "8.8.8.8/32", "k8s.agribridge.deuces.dev")))
        self.assertEqual(after[0]["spec"]["kubernetesApiAccess"], ["8.8.8.8/32"])
        self.assertEqual(after[1:], before[1:])

    def test_refuses_broad_private_or_missing_api_cidrs(self):
        for cidrs in ("0.0.0.0/0", "8.8.0.0/16", "10.0.0.1/32", ""):
            with self.subTest(cidrs=cidrs), self.assertRaises(ValueError):
                cluster.render(self.outputs, cidrs, "k8s.agribridge.deuces.dev")

    def test_state_store_access_failure_never_becomes_cluster_creation(self):
        Path("outputs.json").write_text(json.dumps(self.outputs))
        with patch.dict(os.environ, {"CLUSTER_NAME": "k8s.agribridge.deuces.dev"}), \
             patch.object(cluster, "run", return_value=subprocess.CompletedProcess([], 0, "ns.example.net.\n")) as run, \
             patch.object(cluster.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "AccessDenied")):
            with self.assertRaises(RuntimeError):
                cluster.generate(Path("outputs.json"), "8.8.8.8/32", False)
            self.assertEqual(run.call_count, 1)  # Only DNS was read; no kOps create/replace/update.

    def test_generated_provider_fix_preserves_resources_and_scopes_only_lb_webhook(self):
        Path("terraform/cluster").mkdir(parents=True)
        Path("terraform/cluster/outputs.tf").write_text('output "cluster_name" {}\n')
        directory = Path("generated")
        (directory / "data").mkdir(parents=True)
        source = 'provider "aws" {\n  region = "us-east-1"\n}\nresource "aws_vpc" "cluster" {}\noutput "cluster_name" {}\n'
        (directory / "kubernetes.tf").write_text(source)
        webhook = {"kind": "MutatingWebhookConfiguration", "webhooks": [
            {"name": "mservice.elbv2.k8s.aws"}, {"name": "unrelated.example.org"}]}
        path = directory / "data/aws-load-balancer-controller-content"
        path.write_text(yaml.safe_dump(webhook))
        cluster.prepare_generated(directory)
        result = (directory / "kubernetes.tf").read_text()
        self.assertNotIn('provider "aws"', result)
        self.assertIn('resource "aws_vpc" "cluster" {}', result)
        hooks = yaml.safe_load(path.read_text())["webhooks"]
        self.assertIn("LoadBalancer", hooks[0]["matchConditions"][0]["expression"])
        self.assertNotIn("matchConditions", hooks[1])
        cluster.prepare_generated(directory)
        self.assertEqual((directory / "kubernetes.tf").read_text(), result)


class WorkflowTests(unittest.TestCase):
    def run_guard(self, name, job, step, variables):
        source = step_named(workflow(name)["jobs"][job], step)["run"]
        return subprocess.run(["bash", "-euo", "pipefail", "-c", source],
                              env=dict(os.environ, **variables), capture_output=True, text=True)

    def test_bootstrap_destroy_is_rejected_before_cloud_commands(self):
        result = self.run_guard("infrastructure.yaml", "plan",
                                "Validate request and select the existing state boundary",
                                {"ACTION": "destroy", "STAGE": "bootstrap", "CONFIRMATION": "cluster",
                                 "CLUSTER_NAME": "cluster"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Bootstrap state and DNS are retained", result.stdout)

    def test_destroy_requires_exact_confirmation_before_cloud_commands(self):
        result = self.run_guard("infrastructure.yaml", "plan",
                                "Validate request and select the existing state boundary",
                                {"ACTION": "destroy", "STAGE": "cluster", "CONFIRMATION": "wrong",
                                 "CLUSTER_NAME": "cluster"})
        self.assertNotEqual(result.returncode, 0)

    def test_production_resilience_is_rejected_before_cluster_commands(self):
        result = self.run_guard("operations.yaml", "maintenance",
                                "Validate task and establish a short-lived cluster session",
                                {"TASK": "staging-resilience", "ENVIRONMENT": "production"})
        self.assertNotEqual(result.returncode, 0)

    def test_restore_key_cannot_select_another_environments_backup(self):
        result = self.run_guard("operations.yaml", "maintenance",
                                "Validate task and establish a short-lived cluster session",
                                {"TASK": "restore-test", "ENVIRONMENT": "staging",
                                 "BACKUP_KEY": "production/example.dump"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Backup key must belong", result.stdout)

    def test_cloud_workflows_are_manual_and_share_maintenance_lock(self):
        for name in ("infrastructure.yaml", "operations.yaml"):
            value = workflow(name)
            triggers = value.get("on", value.get(True))
            self.assertEqual(set(triggers), {"workflow_dispatch"})
            self.assertEqual(value["concurrency"]["group"], "agribridge-cloud-maintenance")


class RestoreTests(unittest.TestCase):
    def render(self, key):
        return subprocess.run(["helm", "template", "agribridge", str(ROOT / "helm/agribridge"),
                               "-n", "agribridge-staging", "-f", str(ROOT / "argocd/staging-values.yaml"),
                               "--set", "restoreTest.enabled=true", "--set", "restoreTest.jobName=restore-test",
                               "--set-string", "restoreTest.key=" + key,
                               "--show-only", "templates/restore-test.yaml"], capture_output=True, text=True)

    def test_restore_job_uses_only_temporary_storage_and_restores_into_a_database(self):
        result = self.render("staging/example.dump")
        self.assertEqual(result.returncode, 0, result.stderr)
        documents = list(yaml.safe_load_all(result.stdout))
        self.assertEqual(len(documents), 1)
        job = documents[0]
        self.assertEqual(job["kind"], "Job")
        pod = job["spec"]["template"]["spec"]
        self.assertTrue(all("emptyDir" in volume for volume in pod["volumes"]))
        command = pod["containers"][0]["args"][0]
        self.assertIn("--dbname=restore_check", command)
        self.assertIn("listen_addresses=127.0.0.1", command)
        self.assertNotIn("secretKeyRef", result.stdout)
        self.assertNotIn("agribridge-postgres", result.stdout)
        self.assertEqual(pod["serviceAccountName"], "agribridge-backup")

    def test_helm_rejects_cross_environment_restore_even_outside_workflow(self):
        result = self.render("production/example.dump")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("selected environment", result.stderr)


if __name__ == "__main__":
    unittest.main()
