"""Guarded infrastructure tasks; Actions owns ordering, credentials and approvals."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

RUNTIME = Path('.runtime/automation')
BUNDLE = Path('.runtime/automation-plan.tgz')
BOUNDARIES = {
    'bootstrap': ('terraform/bootstrap', 'bootstrap/terraform.tfstate'),
    'cluster': ('terraform/cluster', 'kops/terraform.tfstate'),
    'services': ('terraform', 'services/terraform.tfstate'),
    'platform': ('terraform/platform', 'platform/terraform.tfstate'),
}


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def capture(*args):
    return run(*args, capture_output=True).stdout


def private_output(path, *args):
    with path.open('w') as output, path.with_suffix(path.suffix + '.stderr').open('w') as errors:
        run(*args, stdout=output, stderr=errors)


def output(**values):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as destination:
        destination.writelines(f'{key}={value}\n' for key, value in values.items())


def summary(text):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as destination:
        destination.write(text)


def request():
    stage, action = os.environ['STAGE'], os.environ['ACTION']
    if stage not in BOUNDARIES or action not in ('plan', 'apply', 'destroy'):
        raise ValueError('Unknown infrastructure stage or action')
    if action == 'destroy':
        if os.environ.get('CONFIRMATION') != os.environ['CLUSTER_NAME']:
            raise ValueError('Destroy requires the exact cluster name')
        if stage == 'bootstrap':
            raise ValueError('Bootstrap state and DNS are retained')
    return stage, action, *BOUNDARIES[stage]


def init(directory, key):
    run('terraform', '-chdir=' + directory, 'init', '-input=false', '-reconfigure', '-lockfile=readonly',
        '-backend-config=bucket=' + os.environ['STATE_BUCKET'],
        '-backend-config=region=' + os.environ['AWS_REGION'], '-backend-config=key=' + key,
        '-backend-config=encrypt=true', '-backend-config=use_lockfile=true')


def backend_override():
    Path('terraform/bootstrap/backend_override.tf').write_text('terraform {\n  backend "s3" {}\n}\n')


def select():
    stage, action, directory, key = request()  # Reject unsafe requests before cloud commands.
    output(directory=directory, key=key)
    run('aws', 's3api', 'head-object', '--bucket', os.environ['STATE_BUCKET'],
        '--key', BOUNDARIES['bootstrap'][1], stdout=subprocess.DEVNULL)
    backend_override()
    init(*BOUNDARIES['bootstrap'])
    private_output(RUNTIME / 'bootstrap-outputs.json', 'terraform', '-chdir=terraform/bootstrap', 'output', '-json')


def generate():
    args = ['--destroy'] if os.environ['ACTION'] == 'destroy' else []
    run(sys.executable, 'scripts/prepare-cluster.py', 'generate', '--outputs',
        str(RUNTIME / 'bootstrap-outputs.json'), *args)
    run('terraform', 'fmt', '-recursive', 'terraform/generated/kops')


def platform_inputs():
    run(sys.executable, 'scripts/prepare-cluster.py', 'wait')
    init(*BOUNDARIES['services'])
    platform = json.loads(capture('terraform', '-chdir=terraform', 'output', '-json', 'platform'))
    (RUNTIME / 'platform.tfvars.json').write_text(json.dumps({
        'platform': platform, 'kubeconfig_path': os.environ['KUBECONFIG'],
        'expected_account_id': os.environ['EXPECTED_AWS_ACCOUNT_ID'],
        'enable_argocd': True, 'enable_legacy_pipeline': False,
    }))


def guard_destroy():
    stage, action, directory, key = request()
    if action != 'destroy':
        return
    if stage in ('cluster', 'services'):
        state_key = BOUNDARIES['platform'][1]
        objects = json.loads(capture('aws', 's3api', 'list-objects-v2', '--bucket',
                                    os.environ['STATE_BUCKET'], '--prefix', state_key, '--output', 'json'))
        if any(item['Key'] == state_key for item in objects.get('Contents', [])):
            state = json.loads(capture('aws', 's3', 'cp',
                               f's3://{os.environ["STATE_BUCKET"]}/{state_key}', '-', '--only-show-errors'))
            if any(resource.get('instances') for resource in state.get('resources', [])
                   if resource.get('mode') == 'managed'):
                raise ValueError('Destroy the platform before its services or cluster')
    else:
        for namespace in ('agribridge-staging', 'agribridge-production'):
            resources = capture('kubectl', '-n', namespace, 'get',
                                'deployment,statefulset,cronjob,job,pvc', '-o', 'name')
            if resources.strip():
                raise ValueError('Back up and decommission application workloads and PVCs first; see OPERATIONS.md')


def plan():
    stage, action, directory, key = request()
    init(directory, key)
    run('terraform', '-chdir=' + directory, 'validate', '-no-color')
    args = ['-var-file=' + str((RUNTIME / 'platform.tfvars.json').resolve())] if stage == 'platform' else []
    if action == 'destroy':
        args.append('-destroy')
    private_output(RUNTIME / 'plan.txt', 'terraform', '-chdir=' + directory, 'plan', '-input=false',
                   '-lock-timeout=5m', *args, '-out=' + str((RUNTIME / 'plan.tfplan').resolve()))
    private_output(RUNTIME / 'plan.json', 'terraform', '-chdir=' + directory, 'show', '-json',
                   str((RUNTIME / 'plan.tfplan').resolve()))
    changes = json.loads((RUNTIME / 'plan.json').read_text()).get('resource_changes', [])
    counts = Counter('/'.join(change['change']['actions']) for change in changes)
    summary('### Terraform plan\n\nStage: ' + stage + '\n\n' +
            ''.join(f'- {kind}: {count}\n' for kind, count in sorted(counts.items())))


def scan():
    stage, action, directory, key = request()
    if stage == 'platform' or action == 'destroy':
        summary('\nAWS plan policies are not applicable to platform-only or destroy plans. '
                'Platform workload policy is checked against rendered Helm manifests in delivery.\n')
        return
    # Full resolved plans/reports may contain credentials: never stream them into Actions logs.
    report = RUNTIME / 'checkov-plan.json'
    private_output(report, 'checkov', '--file', str(RUNTIME / 'plan.json'), '--framework', 'terraform_plan',
                   '--config-file', '.github/checkov.yaml', '--output', 'json', '--skip-download')
    run(sys.executable, '.github/ci/verify-checkov.py', str(report))
    summary('\nSelected AWS security policies passed for the resolved Terraform plan.\n')


def bundle():
    generated = Path('terraform/generated/kops')
    generated.mkdir(parents=True, exist_ok=True)

    def allowed(member):
        if member.issym() or member.islnk():
            raise ValueError('Refusing links in a private plan bundle')
        name = Path(member.name).name
        return None if name == 'kubeconfig' or name.endswith('-state.json') else member

    with tarfile.open(BUNDLE, 'w:gz') as archive:
        archive.add(RUNTIME, filter=allowed)
        archive.add(generated, filter=allowed)
    key = f'automation-plans/{os.environ["GITHUB_RUN_ID"]}/{os.environ["GITHUB_RUN_ATTEMPT"]}/plan.tgz'
    run('aws', 's3', 'cp', str(BUNDLE), f's3://{os.environ["STATE_BUCKET"]}/{key}',
        '--sse', 'AES256', '--only-show-errors')
    output(bundle=key, checksum=hashlib.sha256(BUNDLE.read_bytes()).hexdigest(), workspace=os.environ['GITHUB_WORKSPACE'])
    summary(f'\nPrivate plan bundle: s3://{os.environ["STATE_BUCKET"]}/{key}\n'
            'Review plan.txt and any Checkov report before approving the infrastructure environment.\n')


def restore():
    if os.environ['GITHUB_WORKSPACE'] != os.environ['PLAN_WORKSPACE']:
        raise ValueError('Plan and apply require the same runner workspace path')
    stage, action, directory, key = request()
    run('aws', 's3', 'cp', f's3://{os.environ["STATE_BUCKET"]}/{os.environ["PLAN_KEY"]}',
        str(BUNDLE), '--only-show-errors')
    if hashlib.sha256(BUNDLE.read_bytes()).hexdigest() != os.environ['PLAN_CHECKSUM']:
        raise ValueError('Saved plan bundle checksum does not match')
    roots = [RUNTIME.resolve(), Path('terraform/generated/kops').resolve()]
    with tarfile.open(BUNDLE) as archive:
        for member in archive.getmembers():
            path = Path(member.name).resolve()
            if not (member.isfile() or member.isdir()) or not any(path == root or root in path.parents for root in roots):
                raise ValueError('Unexpected path or link in saved plan bundle')
        archive.extractall()  # Paths and links were checked above; bundle SHA verified before opening.
    backend_override()
    init(directory, key)


def apply():
    stage, action, directory, key = request()
    if action not in ('apply', 'destroy'):
        raise ValueError('Plan-only requests cannot apply infrastructure')
    run('terraform', '-chdir=' + directory, 'apply', '-input=false', '-lock-timeout=5m',
        str((RUNTIME / 'plan.tfplan').resolve()))


def verify_cluster():
    run('kops', 'validate', 'cluster', os.environ['CLUSTER_NAME'], '--wait=15m')
    run(sys.executable, 'scripts/prepare-cluster.py', 'wait')


def publish():
    run('git', 'fetch', 'origin', 'main')
    run('git', 'switch', '--detach', 'origin/main')
    for environment in ('staging', 'production'):
        metadata = RUNTIME / (environment + '.json')
        private_output(metadata, 'aws', 'ssm', 'get-parameter', '--region', os.environ['AWS_REGION'],
                       '--name', '/agribridge/' + environment + '/deployment', '--query', 'Parameter.Value', '--output', 'text')
        run(sys.executable, 'scripts/release.py', 'configure', environment, str(metadata))
    files = ['argocd/staging-values.yaml', 'argocd/production-values.yaml']
    changed = subprocess.run(['git', 'diff', '--quiet', '--', *files])
    if changed.returncode == 0:
        return
    if changed.returncode != 1:
        raise RuntimeError('Could not inspect runtime configuration changes')
    run('git', 'config', 'user.name', 'github-actions[bot]')
    run('git', 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    run('git', 'add', '--', *files)
    run('git', 'commit', '--only', '-m', 'Refresh Terraform runtime references [skip ci]', '--', *files)
    run('git', 'push', 'origin', 'HEAD:main')


def cleanup():
    for path in (RUNTIME, Path('terraform/generated/kops')):
        if path.exists():
            shutil.rmtree(path)
    for path in (BUNDLE, Path('terraform/bootstrap/backend_override.tf')):
        path.unlink(missing_ok=True)


TASKS = {'select': select, 'generate': generate, 'platform-inputs': platform_inputs,
         'guard-destroy': guard_destroy, 'plan': plan, 'scan': scan, 'bundle': bundle,
         'restore': restore, 'apply': apply, 'verify-cluster': verify_cluster,
         'publish': publish, 'cleanup': cleanup}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', choices=TASKS)
    args = parser.parse_args()
    os.umask(0o077)
    TASKS[args.task]()
