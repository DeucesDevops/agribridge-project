.DEFAULT_GOAL := help
PYTHON ?= python3
ENV ?= staging
.PHONY: help local stop local-verify check render sonar-up sonar-scan sonar-down

help:
	@printf '%s\n' 'AgriBridge local commands:' '  make local          Build and start Compose' '  make stop           Stop Compose; retain database data' '  make local-verify   Exercise disposable containers and database persistence' '  make check          Check helpers, Helm and Terraform formatting' '  make render ENV=staging  Inspect the GitOps Helm manifests' '  make sonar-up       Start local SonarQube' '  make sonar-scan     Run coverage and SonarQube analysis' '  make sonar-down     Stop SonarQube; retain its data' '' 'Cloud tasks run in GitHub Actions: delivery.yaml, infrastructure.yaml, operations.yaml.' 'Setup and rebuild sequence: docs/REPRODUCTION.md'

local:
	docker compose up --build -d --wait

stop:
	docker compose down

local-verify:
	bash scripts/verify-local.sh

check:
	$(PYTHON) -m unittest discover -s scripts/tests -p 'test_*.py' -v
	$(PYTHON) -m unittest discover -s sonarqube -p 'test_*.py' -v
	bash -n scripts/verify-local.sh
	terraform fmt -check -recursive terraform
	helm lint helm/agribridge --set secretArn=validation

render:
	@case "$(ENV)" in staging|production) ;; *) echo 'ENV must be staging or production'; exit 2 ;; esac
	helm template agribridge helm/agribridge -n agribridge-$(ENV) -f helm/agribridge/values-$(ENV).yaml -f argocd/$(ENV)-values.yaml

sonar-up:
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml up -d --wait --wait-timeout 360 db sonarqube

sonar-scan:
	npm run test:coverage --prefix api
	npm run test:coverage --prefix frontend
	$(PYTHON) sonarqube/prepare-coverage.py
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml --profile scan run --rm scanner

sonar-down:
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml down
