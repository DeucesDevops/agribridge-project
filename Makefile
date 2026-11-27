.DEFAULT_GOAL := help
PYTHON ?= python3
.PHONY: help local stop validate plan apply teardown test

help:
	@printf '%s\n' \
		'AgriBridge commands:' \
		'  make local        Build and start Compose' \
		'  make stop         Stop Compose and keep database data' \
		'  make validate     Terraform fmt, init, validate, Helm, shellcheck, actionlint' \
		'  make plan         Plan the production root. Talks to AWS. Does not apply' \
		'  make apply        Create the environment: infra and cluster, then platform' \
		'  make teardown     Remove the environment. Keeps the state buckets' \
		'  make test         Unit tests for the API, the web app, and the scripts' \
		'' \
		'A cloud rebuild starts with scripts/bootstrap-state.sh. See docs/SETUP.md.' \
		'plan and apply talk to AWS. validate does not.'

local:
	docker compose up --build -d --wait

stop:
	docker compose down

validate:
	./scripts/terraform-validate.sh
	helm lint helm/agribridge
	helm lint helm/agribridge-application
	helm template agribridge helm/agribridge --namespace agribridge-production -f helm/agribridge/values-production.yaml >/dev/null
	helm template agribridge-application helm/agribridge-application --namespace argocd >/dev/null
	shellcheck scripts/*.sh scripts/lib/*.sh tests/smoke/*.sh
	actionlint

plan:
	terraform -chdir=terraform/environments/production init -backend-config=backend.hcl -input=false
	terraform -chdir=terraform/environments/production plan -input=false -var install_platform=false

apply:
	./scripts/apply-environment.sh

teardown:
	./scripts/teardown-environment.sh

test:
	$(PYTHON) -m unittest discover -s scripts -p 'test_*.py' -v
	$(PYTHON) -m unittest discover -s sonarqube -p 'test_*.py' -v
	npm test --prefix api
	npm test --prefix frontend
