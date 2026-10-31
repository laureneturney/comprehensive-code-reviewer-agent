.PHONY: install doctor verify review lint clean docker

CCRA := bin/ccra

install:          ## Offline install into .ccra/ (binaries + python venv)
	scripts/install.sh

doctor:           ## Show what is installed/configured
	$(CCRA) doctor

verify:           ## Verify checksums of vendored assets
	scripts/verify-assets.sh

review:           ## AI review of the working tree, printed locally
	$(CCRA) review --reporter local

lint:             ## Run config/reviewdog.yml linters locally
	$(CCRA) lint -reporter=local -diff="git diff"

docker:           ## Build the all-in-one image from vendored assets
	docker build -f docker/Dockerfile -t ccra:local .

clean:            ## Remove the local install
	rm -rf .ccra .ccra-review

help:
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
