SHELL := /bin/zsh

ZTR_PATH := /opt/homebrew/share/zsh-test-runner/ztr.zsh
SOURCE_FILES := .zsh_core .zsh_aliases .zsh_functions
TEST_FILES := $(wildcard *.test.zsh)

.PHONY: lint test check

lint:
	@echo "==> Linting (zsh -n)..."
	@fail=0; \
	for f in $(SOURCE_FILES); do \
		zsh -n "$$f" || fail=1; \
	done; \
	[ $$fail -eq 0 ] && echo "All files passed syntax check."

test:
	@echo "==> Running tests (ztr)..."
	@fail=0; \
	for f in $(TEST_FILES); do \
		echo "--- $$f ---"; \
		zsh -c 'source $(ZTR_PATH) && source "'"$$f"'" && ztr summary' || fail=1; \
		echo; \
	done; \
	exit $$fail

check: lint test
