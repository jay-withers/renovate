.DEFAULT_GOAL := help

.PHONY: help install lint validate

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: ## Install pre-commit hooks (run once after cloning)
	pre-commit install
	pre-commit install --hook-type commit-msg

lint: ## Run all pre-commit hooks against every file
	pre-commit run --all-files

validate: ## Validate every Renovate preset with renovate-config-validator
	npx --yes --package renovate -- renovate-config-validator --strict \
		$$(git ls-files '*.json' | grep -v '/')
