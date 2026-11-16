"""Exercise blocking CI gates, empty-scan handling and image publication ordering."""
import importlib.util
import os
from pathlib import Path
import subprocess
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("checkov_report", ROOT / ".github/ci/verify-checkov.py")
checkov_report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checkov_report)


class SecurityReportTests(unittest.TestCase):
    def test_accepts_scanned_and_passing_policies(self):
        checkov_report.validate({"summary": {"passed": 12, "failed": 0, "parsing_errors": 0}})

    def test_rejects_empty_failed_or_partially_parsed_scans(self):
        reports = [[], {}, {"summary": {"passed": 0, "failed": 0}},
                   {"summary": {"passed": 12, "failed": 1}},
                   {"summary": {"passed": 12, "parsing_errors": 1}},
                   {"summary": {"passed": 12}, "results": {"parsing_errors": ["invalid.yaml"]}}]
        for report in reports:
            with self.subTest(report=report), self.assertRaises(ValueError):
                checkov_report.validate(report)


class DeliveryGateTests(unittest.TestCase):
    def setUp(self):
        self.workflow = yaml.safe_load((ROOT / ".github/workflows/delivery.yaml").read_text())
        self.jobs = self.workflow["jobs"]

    def run_gate(self, job, environment):
        source = self.jobs[job]["steps"][0]["run"]
        return subprocess.run(["bash", "-euo", "pipefail", "-c", source],
                              env=dict(os.environ, **environment), capture_output=True, text=True)

    def test_source_gate_rejects_failed_cancelled_and_skipped_prerequisites(self):
        passing = {"FAILED": "false", "CANCELLED": "false", "SKIPPED": "false"}
        self.assertEqual(self.run_gate("validation", passing).returncode, 0)
        for key in passing:
            with self.subTest(key=key):
                self.assertNotEqual(self.run_gate("validation", dict(passing, **{key: "true"})).returncode, 0)

    def test_required_gate_never_accepts_missing_container_evidence(self):
        for validation in ("success", "failure", "skipped", "cancelled"):
            for containers in ("success", "failure", "skipped", "cancelled"):
                with self.subTest(validation=validation, containers=containers):
                    result = self.run_gate("checks", {"VALIDATION": validation,
                                                     "CONTAINERS": containers, "ANALYSIS_ONLY": "false"})
                    self.assertEqual(result.returncode == 0, validation == containers == "success")

    def test_analysis_only_allows_only_an_intentionally_skipped_container_job(self):
        for containers in ("success", "failure", "skipped", "cancelled"):
            result = self.run_gate("checks", {"VALIDATION": "success", "CONTAINERS": containers,
                                              "ANALYSIS_ONLY": "true"})
            self.assertEqual(result.returncode == 0, containers == "skipped")

    def test_every_validation_job_is_required_and_no_fail_open_overrides_exist(self):
        validators = {"gitleaks-scan", "checkov", "trivy-fs", "lint", "test", "integration-test",
                      "sonarqube", "client-build", "platform", "terraform"}
        self.assertEqual(set(self.jobs["validation"]["needs"]), validators)
        self.assertEqual(self.jobs["validation"]["if"], "always()")
        for job in self.jobs.values():
            self.assertFalse(job.get("continue-on-error", False))
            for step in job.get("steps", []):
                self.assertFalse(step.get("continue-on-error", False))

    def test_publishing_is_main_only_and_uses_images_built_and_scanned_once(self):
        steps = self.jobs["publish"]["steps"]
        builds = [i for i, step in enumerate(steps) if "docker/bake-action@" in step.get("uses", "")]
        scans = [i for i, step in enumerate(steps) if "trivy-action@" in step.get("uses", "")]
        pushes = [i for i, step in enumerate(steps) if step.get("run", "").startswith("docker push")]
        self.assertEqual(len(builds), 1)
        self.assertEqual(len(scans), 2)
        self.assertEqual(len(pushes), 2)
        self.assertLess(builds[0], min(scans))
        self.assertLess(max(scans), min(pushes))
        self.assertFalse(steps[builds[0]]["with"]["push"])
        for index in pushes:
            self.assertIn("github.ref == 'refs/heads/main'", steps[index]["if"])
            self.assertIn("github.event_name != 'pull_request'", steps[index]["if"])


if __name__ == "__main__":
    unittest.main()
