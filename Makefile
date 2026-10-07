# Entry point for every local workflow. Targets mirror docs/07-infrastructure.md;
# `k3s-create` is added by ADR-014. Compatible with the GNU make 3.81 shipped with macOS.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# [DRY] One definition of how Compose is invoked; every target below reuses it.
COMPOSE_FILE := infra/compose/docker-compose.yml
COMPOSE := docker compose -f $(COMPOSE_FILE)
# Profiles group the application services; the platform containers have no profile and always start.
ALL_PROFILES := --profile '*'
COMPOSE_NETWORK := hushold_default

CORE_DIR := services/core-service
MEDIA_DIR := services/media-service

# Tool images are pinned so that `make migrate` behaves identically on every machine.
FLYWAY_IMAGE := flyway/flyway:11
MIGRATE_IMAGE := migrate/migrate:v4.20.1

.PHONY: help up down reset logs migrate migrate-core migrate-media test test-core test-media \
	lint lint-core lint-media lint-contracts openapi-gen events-validate \
	k3s-create k3s-deploy k3s-argocd

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_%-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## ---------- Local platform (Docker Compose on OrbStack) ----------

up: ## Start the platform and all application services, wait until healthy
	$(COMPOSE) $(ALL_PROFILES) up -d --build --wait

up-%: ## Start the platform plus one profile, for example `make up-core`
	$(COMPOSE) --profile $* up -d --build --wait

down: ## Stop all containers, keep volumes
	$(COMPOSE) $(ALL_PROFILES) down

reset: ## Stop all containers and delete volumes (local data is lost)
	$(COMPOSE) $(ALL_PROFILES) down --volumes --remove-orphans

logs: ## Follow logs; narrow with SERVICE=core-service
	$(COMPOSE) $(ALL_PROFILES) logs -f --tail=200 $(SERVICE)

## ---------- Database migrations ----------
# Services migrate on startup. These targets run the same migration files on demand,
# for example after `make reset` without starting the services.

migrate: migrate-core migrate-media ## Apply migrations of every service to the local database

migrate-core:
	docker run --rm --network $(COMPOSE_NETWORK) \
		-v $(CURDIR)/$(CORE_DIR)/src/main/resources/db/migration:/flyway/sql:ro \
		$(FLYWAY_IMAGE) -url=jdbc:postgresql://postgres:5432/core -user=core -password=local-only-core migrate

migrate-media:
	docker run --rm --network $(COMPOSE_NETWORK) \
		-v $(CURDIR)/$(MEDIA_DIR)/internal/adapters/postgres/migrations:/migrations:ro \
		$(MIGRATE_IMAGE) -path=/migrations \
		-database "postgres://media:local-only-media@postgres:5432/media?sslmode=disable" up

## ---------- Quality gates ----------

test: test-core test-media ## Run unit and Testcontainers tests of every service

test-core:
	cd $(CORE_DIR) && ./gradlew test

test-media:
	cd $(MEDIA_DIR) && go test ./...

lint: lint-core lint-media lint-contracts ## Run every linter that CI runs

lint-core:
	cd $(CORE_DIR) && ./gradlew spotlessCheck

lint-media:
	cd $(MEDIA_DIR) && golangci-lint run --config $(CURDIR)/.golangci.yml ./...

lint-contracts:
	npx --yes @stoplight/spectral-cli@6 lint --ruleset .spectral.yaml contracts/openapi/*.yaml

## ---------- Contracts ----------

openapi-gen: ## Regenerate server interfaces from contracts/openapi
	cd $(CORE_DIR) && ./gradlew openApiGenerate

events-validate: ## Validate event examples against the envelope and their schemas
	./scripts/validate-events.sh

## ---------- Kubernetes on the OrbStack Linux machine ----------

k3s-create: ## Create the hushold-k3s OrbStack machine with k3s and print its nodes
	./scripts/k3s-create.sh

# [YAGNI] Helm charts and ArgoCD arrive in M7; the targets exist so the interface in docs/07 is stable.
k3s-deploy: ## (M7) Install the Helm charts into hushold-k3s
	@echo "k3s-deploy is implemented in M7 (tasks/M7-cloud-rehearsal-and-release.md, 7.1)." >&2; exit 1

k3s-argocd: ## (M7) Install ArgoCD into hushold-k3s
	@echo "k3s-argocd is implemented in M7 (tasks/M7-cloud-rehearsal-and-release.md, 7.1)." >&2; exit 1
