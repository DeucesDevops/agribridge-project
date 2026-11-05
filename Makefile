.DEFAULT_GOAL := help
.PHONY: help check local local-verify plan-bootstrap plan-cluster plan-services plan-platform plan-argocd prepare-gitops test-gitops check-delivery stop provision resume sonar-up sonar-scan sonar-down

help:
	@printf '%s\n' 'AgriBridge commands — run from the project root:' '' '  make local      Build and start the local application stack' '  make local-verify  Verify isolated containers, integration and resilience' '  make stop       Stop local containers; preserve database data' '  make plan-bootstrap  Save the first AWS plan for review; do not apply' '  make plan-cluster  Prepare kOps metadata and save a cluster plan; do not apply' '  make check      Check Terraform formatting, shell syntax and Helm chart' '  make provision  Provision infrastructure in order (applies automatically)' '  make resume     Finish services/platform on an existing cluster' '' 'Rebuild sequence: docs/REBUILD-GUIDE.md' 'Inputs and configuration: docs/CONFIGURATION.md'
	@printf '%s\n' '  make plan-services  Save the AWS services plan for review; do not apply'
	@printf '%s\n' '  make plan-platform  Check services drift and save the Kubernetes platform plan; do not apply'
	@printf '%s\n' '  make plan-argocd  Generate runtime references and plan Argo CD; do not apply' '  make test-gitops  Check release promotion and Helm rendering' '  make check-delivery  Read GitHub access and CI credential-name readiness'
	@printf '%s\n' '  make sonar-up   Start only local SonarQube and its database' '  make sonar-scan Run coverage and SonarQube analysis; require a passing quality gate' '  make sonar-down Stop SonarQube; preserve its analysis history' '  SonarQube setup: sonarqube/README.md'

check:
	python3 -m unittest discover -s sonarqube -p 'test_*.py'
	terraform fmt -check -recursive terraform
	@for script in scripts/*.sh; do bash -n "$$script" || exit; done
	helm lint helm/agribridge --set secretArn=validation

local:
	docker compose up --build -d --wait

local-verify:
	bash scripts/verify-local.sh

plan-bootstrap:
	bash scripts/plan-bootstrap.sh

plan-cluster:
	bash scripts/plan-cluster.sh

plan-services:
	bash scripts/plan-services.sh

plan-platform:
	bash scripts/plan-platform.sh

plan-argocd:
	bash scripts/plan-argocd.sh

prepare-gitops:
	bash scripts/prepare-gitops.sh

test-gitops:
	python3 scripts/test-gitops.py

check-delivery:
	bash scripts/check-delivery-access.sh

stop:
	docker compose down

provision:
	bash scripts/provision.sh

resume:
	bash scripts/resume-platform.sh

sonar-up:
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml up -d --wait --wait-timeout 360 db sonarqube

sonar-scan:
	npm run test:coverage --prefix api
	npm run test:coverage --prefix frontend
	python3 sonarqube/prepare-coverage.py
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml --profile scan run --rm scanner

sonar-down:
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml down
