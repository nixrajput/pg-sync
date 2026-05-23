# pg-sync — developer Makefile
# All targets are phony; this is a convenience wrapper, not a build dependency graph.

.PHONY: help lint test build install uninstall clean release-check publish-tap

SHELL := /usr/bin/env bash
SCRIPT := src/pg-sync
PREFIX ?= $(HOME)/.local
VERSION := $(shell grep -E '^readonly SCRIPT_VERSION=' $(SCRIPT) | sed -E 's/.*"([^"]+)".*/\1/')

help:  ## Show this help
	@echo "pg-sync v$(VERSION)"
	@echo
	@echo "Targets:"
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)        (override install location)"

lint:  ## Static-check the script (bash -n + shellcheck if available)
	@echo "==> bash -n $(SCRIPT)"
	@bash -n $(SCRIPT)
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "==> shellcheck $(SCRIPT)"; \
		shellcheck -S warning $(SCRIPT); \
	else \
		echo "    shellcheck not installed — skipping"; \
	fi
	@echo "    OK"

test:  ## Run smoke tests under tests/
	@if [[ -d tests ]] && ls tests/*.sh >/dev/null 2>&1; then \
		for t in tests/*.sh; do \
			echo "==> $$t"; \
			bash "$$t" || exit 1; \
		done; \
		echo "    All tests passed"; \
	else \
		echo "    No tests under tests/ — skipping"; \
	fi

build:  ## Build release artifacts into dist/
	@bash scripts/build.sh

install:  ## Install the working copy to $(PREFIX)/bin (no build needed)
	@mkdir -p $(PREFIX)/bin
	@install -m 0755 $(SCRIPT) $(PREFIX)/bin/pg-sync
	@echo "==> Installed to $(PREFIX)/bin/pg-sync"
	@case ":$$PATH:" in *":$(PREFIX)/bin:"*) ;; *) \
		echo "    Note: $(PREFIX)/bin is not on your PATH."; \
		echo "    Add this to your shell rc:"; \
		echo "        export PATH=\"$(PREFIX)/bin:\$$PATH\"";; \
	esac

uninstall:  ## Remove the installed binary
	@rm -f $(PREFIX)/bin/pg-sync
	@echo "==> Removed $(PREFIX)/bin/pg-sync"

clean:  ## Remove dist/ and bin/
	@rm -rf dist bin
	@echo "==> Cleaned dist/ and bin/"

release-check:  ## Verify the working tree is clean and CHANGELOG has an entry for the current version
	@git diff --quiet --exit-code || { echo "Working tree dirty — commit first"; exit 1; }
	@grep -q "^## \[$(VERSION)\]" CHANGELOG.md || { echo "CHANGELOG.md has no entry for $(VERSION)"; exit 1; }
	@echo "==> Ready to tag v$(VERSION) (run: git tag -a v$(VERSION) -m \"v$(VERSION)\" && git push origin v$(VERSION))"

publish-tap:  ## Publish the current release to the Homebrew tap (after GitHub release exists)
	@bash scripts/publish-tap.sh
