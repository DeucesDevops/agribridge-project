.DEFAULT_GOAL := help
PYTHON ?= python3
.PHONY: help local stop check sonar-up sonar-scan sonar-down

help:
	@printf '%s\n' \
		'AgriBridge local commands:' \
		'  make local        Build and start Compose' \
		'  make stop         Stop Compose and keep database data' \
		'  make check        Helm lint, Terraform fmt, SonarQube helper tests' \
		'  make sonar-up     Start local SonarQube' \
		'  make sonar-scan   Run coverage and a local SonarQube scan' \
		'  make sonar-down   Stop SonarQube and keep its data' \
		'' \
		'Cloud setup is docs/SETUP.md. The pipeline is .github/workflows/cicd.yaml.'

local:
	docker compose up --build -d --wait

stop:
	docker compose down

check:
	$(PYTHON) -m unittest discover -s sonarqube -p 'test_*.py' -v
	$(PYTHON) -m unittest discover -s scripts -p 'test_*.py' -v
	terraform fmt -check -recursive terraform
	helm lint helm/agribridge
	helm lint helm/agribridge-application
	helm template agribridge helm/agribridge --namespace agribridge-production -f helm/agribridge/values-production.yaml >/dev/null
	helm template agribridge-application helm/agribridge-application --namespace argocd >/dev/null

sonar-up:
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml up -d --wait --wait-timeout 360 db sonarqube

sonar-scan:
	npm run test:coverage --prefix api
	npm run test:coverage --prefix frontend
	$(PYTHON) sonarqube/prepare-coverage.py
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml --profile scan run --rm scanner

sonar-down:
	docker compose --env-file sonarqube/.env -f sonarqube/compose.yaml down
