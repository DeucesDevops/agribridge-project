"""Offline regression checks for approved plans, private evidence and teardown guards."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('infrastructure', ROOT / '.github/ci/infrastructure.py')
infra = importlib.util.module_from_spec(spec)
spec.loader.exec_module(infra)


class InfrastructureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.temporary.name)
        infra.RUNTIME.mkdir(parents=True)
        Path('terraform/bootstrap').mkdir(parents=True)
        self.variables = patch.dict(os.environ, {
            'STAGE': 'cluster', 'ACTION': 'apply', 'CONFIRMATION': '', 'CLUSTER_NAME': 'cluster',
            'STATE_BUCKET': 'private-state', 'AWS_REGION': 'us-east-1',
            'GITHUB_OUTPUT': 'outputs', 'GITHUB_STEP_SUMMARY': 'summary',
            'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
            'GITHUB_WORKSPACE': str(Path.cwd()), 'PLAN_WORKSPACE': str(Path.cwd()),
            'PLAN_KEY': 'automation-plans/123/1/plan.tgz', 'PLAN_CHECKSUM': 'not-the-checksum',
        })
        self.variables.start()

    def tearDown(self):
        self.variables.stop()
        os.chdir(self.previous)
        self.temporary.cleanup()

    def test_unsafe_destroy_requests_fail_before_any_cloud_command(self):
        for stage, confirmation in [('bootstrap', 'cluster'), ('cluster', 'wrong')]:
            with patch.dict(os.environ, {'STAGE': stage, 'ACTION': 'destroy', 'CONFIRMATION': confirmation}):
                with patch.object(infra, 'run') as command, self.assertRaises(ValueError):
                    infra.select()
                command.assert_not_called()

    def test_backend_override_is_valid_terraform_hcl(self):
        infra.backend_override()
        result = subprocess.run(['terraform', 'fmt', '-check', 'terraform/bootstrap/backend_override.tf'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_only_apply_or_destroy_can_execute_the_saved_plan(self):
        with patch.dict(os.environ, {'ACTION': 'plan'}), patch.object(infra, 'run') as command:
            with self.assertRaises(ValueError): infra.apply()
            command.assert_not_called()
        with patch.object(infra, 'run') as command:
            infra.apply()
        args = command.call_args.args
        self.assertIn('apply', args)
        self.assertTrue(args[-1].endswith('/.runtime/automation/plan.tfplan'))
        self.assertNotIn('-auto-approve', args)
        self.assertNotIn('plan', args)

    def test_existing_platform_blocks_dependency_destruction(self):
        objects = json.dumps({'Contents':[{'Key':'platform/terraform.tfstate'}]})
        state = json.dumps({'resources':[{'mode':'managed','instances':[{}]}]})
        with patch.dict(os.environ, {'ACTION':'destroy','CONFIRMATION':'cluster'}):
            with patch.object(infra, 'capture', side_effect=[objects,state]):
                with self.assertRaisesRegex(ValueError, 'Destroy the platform'): infra.guard_destroy()

    def test_workloads_or_pvcs_block_platform_destruction(self):
        with patch.dict(os.environ, {'STAGE':'platform','ACTION':'destroy','CONFIRMATION':'cluster'}):
            with patch.object(infra, 'capture', return_value='persistentvolumeclaim/database\n'):
                with self.assertRaisesRegex(ValueError, 'decommission'): infra.guard_destroy()

    def test_bundle_excludes_credentials_and_raw_state_but_keeps_plan_evidence(self):
        (infra.RUNTIME/'plan.tfplan').write_bytes(b'exact binary plan')
        (infra.RUNTIME/'checkov-plan.json').write_text('{"summary":{"passed":1}}')
        (infra.RUNTIME/'kubeconfig').write_text('private cluster credential')
        (infra.RUNTIME/'platform-state.json').write_text('raw state')
        with patch.object(infra, 'run'): infra.bundle()
        with tarfile.open(infra.BUNDLE) as archive:
            names = archive.getnames()
        self.assertIn(str(infra.RUNTIME/'plan.tfplan'), names)
        self.assertIn(str(infra.RUNTIME/'checkov-plan.json'), names)
        self.assertNotIn(str(infra.RUNTIME/'kubeconfig'), names)
        self.assertNotIn(str(infra.RUNTIME/'platform-state.json'), names)
        self.assertIn(hashlib.sha256(infra.BUNDLE.read_bytes()).hexdigest(), Path('outputs').read_text())

    def test_checksum_and_workspace_mismatch_prevent_backend_access(self):
        infra.BUNDLE.write_bytes(b'tampered plan')
        with patch.object(infra, 'run') as command, patch.object(infra, 'init') as init:
            with self.assertRaisesRegex(ValueError, 'checksum'): infra.restore()
            init.assert_not_called()
        with patch.dict(os.environ, {'PLAN_WORKSPACE':'/another-workspace'}):
            with patch.object(infra, 'run') as command, self.assertRaisesRegex(ValueError, 'workspace'): infra.restore()
            command.assert_not_called()

    def test_verified_bundles_still_reject_traversal_and_links(self):
        for filename, symlink in [('../escaped',False),('.runtime/automation/link',True)]:
            with tarfile.open(infra.BUNDLE, 'w:gz') as archive:
                member=tarfile.TarInfo(filename)
                if symlink:
                    member.type=tarfile.SYMTYPE
                    member.linkname='/tmp/elsewhere'
                    archive.addfile(member)
                else:
                    member.size=1
                    archive.addfile(member,io.BytesIO(b'x'))
            checksum=hashlib.sha256(infra.BUNDLE.read_bytes()).hexdigest()
            with patch.dict(os.environ, {'PLAN_CHECKSUM':checksum}), patch.object(infra,'run'):
                with self.assertRaisesRegex(ValueError,'Unexpected path or link'): infra.restore()

    def test_failed_plan_scan_is_blocking_and_its_output_stays_private(self):
        report=infra.RUNTIME/'checkov-plan.json'
        def fail_private(path,*args):
            path.write_text('{"summary":{"failed":1}}')
            raise subprocess.CalledProcessError(1,args)
        with patch.object(infra,'private_output',side_effect=fail_private):
            with self.assertRaises(subprocess.CalledProcessError): infra.scan()
        self.assertTrue(report.exists())
        self.assertFalse(Path('summary').exists())

    def test_infrastructure_workflow_has_no_embedded_shell_programs(self):
        workflow=yaml.safe_load((ROOT/'.github/workflows/infrastructure.yaml').read_text())
        for job in workflow['jobs'].values():
            for step in job['steps']: self.assertIn('uses',step)
        plan=workflow['jobs']['plan']
        tasks=[step.get('with',{}).get('task') for step in plan['steps']]
        self.assertLess(tasks.index('plan'),tasks.index('scan'))
        self.assertLess(tasks.index('scan'),tasks.index('bundle'))
        self.assertEqual(workflow['jobs']['apply']['environment'],'infrastructure')


if __name__=='__main__': unittest.main()
