SHELL := /bin/bash
COMPOSE ?= docker compose
SERVICE ?= windrose
CONTAINER ?= windrose_server
ENV_FILE ?= .env

.PHONY: help config build pull up up-build down down-v restart stop start ps logs logs-f sh prune

help:
	@echo "Available targets:"
	@echo "  make config     - render and validate compose config"
	@echo "  make build      - build container image"
	@echo "  make pull       - pull images referenced by compose"
	@echo "  make up         - start services in detached mode"
	@echo "  make up-build   - build and start services in detached mode"
	@echo "  make down       - stop and remove containers/network"
	@echo "  make down-v     - same as down, plus named volumes"
	@echo "  make restart    - restart services"
	@echo "  make stop       - stop services"
	@echo "  make start      - start existing services"
	@echo "  make ps         - list service status"
	@echo "  make logs       - show recent logs"
	@echo "  make logs-f     - follow logs"
	@echo "  make sh         - open shell in container"
	@echo "  make prune      - remove unused docker images"

config:
	$(COMPOSE) --env-file $(ENV_FILE) config

build:
	$(COMPOSE) --env-file $(ENV_FILE) build

pull:
	$(COMPOSE) --env-file $(ENV_FILE) pull

up:
	$(COMPOSE) --env-file $(ENV_FILE) up -d

up-build:
	$(COMPOSE) --env-file $(ENV_FILE) up -d --build

down:
	$(COMPOSE) --env-file $(ENV_FILE) down

down-v:
	$(COMPOSE) --env-file $(ENV_FILE) down -v

restart:
	$(COMPOSE) --env-file $(ENV_FILE) restart

stop:
	$(COMPOSE) --env-file $(ENV_FILE) stop

start:
	$(COMPOSE) --env-file $(ENV_FILE) start

ps:
	$(COMPOSE) --env-file $(ENV_FILE) ps

logs:
	$(COMPOSE) --env-file $(ENV_FILE) logs --tail=200

logs-f:
	$(COMPOSE) --env-file $(ENV_FILE) logs -f

sh:
	$(COMPOSE) --env-file $(ENV_FILE) exec $(SERVICE) bash

prune:
	docker image prune -f
