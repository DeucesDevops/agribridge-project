"""Focused operations tasks for the existing Helm-managed application."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import yaml

RUNTIME = Path('.runtime/automation')


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def validate():
    task, environment = os.environ['TASK'], os.environ['ENVIRONMENT']
    if environment not in ('staging', 'production') or task not in ('check', 'backup', 'restore-test', 'staging-resilience'):
        raise ValueError('Unknown operations task or environment')
    if task == 'staging-resilience' and environment != 'staging':
        raise ValueError('Resilience tests are restricted to staging')
    key = os.environ.get('BACKUP_KEY', '')
    if task == 'restore-test' and not (key.startswith(environment + '/') and key.endswith('.dump')):
        raise ValueError('Backup key must belong to the selected environment')
    if os.environ['NAMESPACE'] != 'agribridge-' + environment:
        raise ValueError('Unexpected application namespace')


def kubectl(*args, **kwargs):
    return run('kubectl', '-n', os.environ['NAMESPACE'], *args, **kwargs)


def health():
    kubectl('wait', '--for=condition=Ready', 'externalsecret/agribridge', '--timeout=300s')
    for kind, name in [('statefulset', 'postgres'), ('deployment', 'api'),
                       ('deployment', 'web'), ('deployment', 'redis')]:
        kubectl('rollout', 'status', kind + '/agribridge-' + name, '--timeout=300s')
    kubectl('get', 'pvc')
    environment = os.environ['ENVIRONMENT']
    values = yaml.safe_load(Path('argocd/' + environment + '-values.yaml').read_text())
    run(sys.executable, 'scripts/smoke-test.py', environment, values['api']['tag'], '--runtime')


def job_name(kind):
    name = f'agribridge-{kind}-{os.environ["GITHUB_RUN_ID"]}-{os.environ["GITHUB_RUN_ATTEMPT"]}'
    with open(os.environ['GITHUB_ENV'], 'a') as output:
        output.write('OPERATION_JOB=' + name + '\n')
    return name


def wait_for_job(name, container):
    kubectl('wait', '--for=condition=complete', 'job/' + name, '--timeout=1800s')
    kubectl('logs', 'job/' + name, '-c', container)


def backup():
    name = job_name('backup')
    kubectl('create', 'job', name, '--from=cronjob/agribridge-backup')
    wait_for_job(name, 'upload')


def restore():
    name, environment = job_name('restore'), os.environ['ENVIRONMENT']
    settings = RUNTIME / 'restore-values.json'
    settings.write_text(json.dumps({'restoreTest': {'enabled': True, 'jobName': name,
                                                   'key': os.environ['BACKUP_KEY']}}))
    manifest = RUNTIME / 'restore-job.yaml'
    with manifest.open('w') as output:
        run('helm', 'template', 'agribridge', 'helm/agribridge', '-n', os.environ['NAMESPACE'],
            '-f', 'helm/agribridge/values-' + environment + '.yaml',
            '-f', 'argocd/' + environment + '-values.yaml', '-f', str(settings),
            '--show-only', 'templates/restore-test.yaml', stdout=output)
    kubectl('create', '-f', str(manifest))
    wait_for_job(name, 'verify')


def resilience():
    run(sys.executable, 'scripts/check-resilience.py')


def diagnostics():
    if os.environ.get('OPERATION_JOB'):
        kubectl('describe', 'job/' + os.environ['OPERATION_JOB'])
        kubectl('logs', 'job/' + os.environ['OPERATION_JOB'], '--all-containers=true', '--tail=100')


def cleanup():
    try:
        if os.environ.get('OPERATION_JOB'):
            kubectl('delete', 'job', os.environ['OPERATION_JOB'], '--ignore-not-found', '--wait=false')
    finally:
        if RUNTIME.exists():
            shutil.rmtree(RUNTIME)


TASKS = {'validate': validate, 'health': health, 'backup': backup, 'restore': restore,
         'resilience': resilience, 'diagnostics': diagnostics, 'cleanup': cleanup}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', choices=TASKS)
    args = parser.parse_args()
    os.umask(0o077)
    # Validate destructive/task-specific inputs before executing any cluster command.
    if args.task not in ('diagnostics', 'cleanup'):
        validate()
    TASKS[args.task]()
