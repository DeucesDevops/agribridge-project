# CIDRs, zones, and tags come from kops/cluster.yaml through the kOps render.
# scripts/patch_kops_terraform.py writes them into main.tf. This module has
# no inputs; the production and dev roots read its outputs.
