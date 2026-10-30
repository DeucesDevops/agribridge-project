.DEFAULT_GOAL := help
.PHONY: help check local stop provision resume

help:
	@printf '%s\n' 'AgriBridge commands — run from the project root:' '' '  make local      Build and start the local application stack' '  make stop       Stop local containers; preserve database data' '  make check      Check Terraform formatting, shell syntax and Helm chart' '  make provision  Provision all four infrastructure stacks in order' '  make resume     Finish services/platform on an existing cluster' '' 'Rebuild sequence: docs/REBUILD-GUIDE.md' 'Inputs and configuration: docs/CONFIGURATION.md'

check:
	terraform fmt -check -recursive terraform
	@for script in scripts/*.sh; do bash -n "$$script" || exit; done
	helm lint helm/agribridge --set secretArn=validation

local:
	docker compose up --build -d --wait

stop:
	docker compose down

provision:
	bash scripts/provision.sh

resume:
	bash scripts/resume-platform.sh
