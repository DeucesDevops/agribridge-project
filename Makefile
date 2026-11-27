.DEFAULT_GOAL := help
.PHONY: help local stop

help:
	@printf '%s\n' \
		'AgriBridge local commands:' \
		'  make local        Build and start Compose' \
		'  make stop         Stop Compose and keep database data'

local:
	docker compose up --build -d --wait

stop:
	docker compose down
