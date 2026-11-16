"""Operations guards and cleanup behaviour without contacting a cluster."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import yaml
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('operations',ROOT/'.github/ci/operations.py')
ops=importlib.util.module_from_spec(spec)
spec.loader.exec_module(ops)


class OperationsTests(unittest.TestCase):
    def test_production_resilience_and_cross_environment_restore_are_rejected(self):
        for task, environment, key in [('staging-resilience','production',''),
                                        ('restore-test','staging','production/example.dump')]:
            with patch.dict(os.environ, {'TASK':task,'ENVIRONMENT':environment,'BACKUP_KEY':key,
                                         'NAMESPACE':'agribridge-'+environment}):
                with self.assertRaises(ValueError): ops.validate()

    def test_unknown_namespace_cannot_target_another_application(self):
        with patch.dict(os.environ, {'TASK':'check','ENVIRONMENT':'staging','NAMESPACE':'other-application'}):
            with self.assertRaisesRegex(ValueError,'namespace'): ops.validate()

    def test_backup_uses_the_existing_helm_managed_cronjob(self):
        with patch.dict(os.environ, {'NAMESPACE':'agribridge-staging'}):
            with patch.object(ops,'job_name',return_value='backup-123'), patch.object(ops,'wait_for_job') as wait:
                with patch.object(ops,'kubectl') as command: ops.backup()
            command.assert_called_once_with('create','job','backup-123','--from=cronjob/agribridge-backup')
            wait.assert_called_once_with('backup-123','upload')

    def test_private_files_are_removed_even_when_job_deletion_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime=Path(directory)/'private'
            runtime.mkdir()
            (runtime/'kubeconfig').write_text('private credential')
            with patch.object(ops,'RUNTIME',runtime), patch.dict(os.environ,{'OPERATION_JOB':'backup-123'}):
                with patch.object(ops,'kubectl',side_effect=subprocess.CalledProcessError(1,['kubectl'])):
                    with self.assertRaises(subprocess.CalledProcessError): ops.cleanup()
            self.assertFalse(runtime.exists())

    def test_workflow_keeps_each_operation_visible_without_shell_blocks(self):
        workflow=yaml.safe_load((ROOT/'.github/workflows/operations.yaml').read_text())
        steps=workflow['jobs']['maintenance']['steps']
        for step in steps: self.assertIn('uses',step)
        for task in ['validate','health','backup','restore','resilience','diagnostics','cleanup']:
            self.assertIn(task,[step.get('with',{}).get('task') for step in steps])
        setup=next(step for step in steps if step['uses']=='./.github/actions/cloud-tools')
        self.assertNotEqual(setup['with'].get('terraform'),'true')


if __name__=='__main__': unittest.main()
