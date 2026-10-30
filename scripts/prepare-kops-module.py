"""Keep generated kOps resources reusable while providers stay in the root module.

Run after every `kops update --target terraform`. Resource names and contents are
untouched. Terraform's aws.files alias is passed explicitly by terraform/cluster.
Existing address migrations in terraform/cluster/moved.tf are retained.
"""
import re
from pathlib import Path

source = Path('terraform/modules/kops-cluster/kubernetes.tf')
text = source.read_text()
text = re.sub(r'(?ms)^provider "aws" \{.*?^\}\n?', '', text)
source.write_text(text)
outputs = re.findall(r'^output "([^"]+)"', text, re.MULTILINE)
Path('terraform/cluster/outputs.tf').write_text('\n\n'.join(
    f'output "{name}" {{\n  value = module.cluster.{name}\n}}'
    for name in outputs
) + '\n')
