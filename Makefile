SHELL := /bin/zsh

# Stow packages (subdirs that mirror $HOME)
PACKAGES := zsh claude starship

# --- zsh lint + test ---
ZTR_PATH := /opt/homebrew/share/zsh-test-runner/ztr.zsh
ZSH_DIR := zsh/.zsh
SOURCE_FILES := $(ZSH_DIR)/.zsh_core $(ZSH_DIR)/.zsh_aliases $(ZSH_DIR)/.zsh_functions
TEST_FILES := $(wildcard $(ZSH_DIR)/.*.test.zsh)

.PHONY: help install uninstall restow lint test check sbx

help:
	@echo "Usage:"
	@echo "  make install           Stow all packages into \$$HOME"
	@echo "  make uninstall         Unstow all packages"
	@echo "  make restow            Re-stow all packages (fixes stale links)"
	@echo "  make install-<pkg>     Stow a single package (e.g. make install-zsh)"
	@echo "  make uninstall-<pkg>   Unstow a single package"
	@echo "  make lint              zsh -n syntax check on source files"
	@echo "  make test              Run ztr tests"
	@echo "  make check             lint + test"
	@echo "  make sbx               Build the sbx image (~/.claude-personal)"
	@echo ""
	@echo "Packages: $(PACKAGES)"

install:
	@for pkg in $(PACKAGES); do \
		echo "==> stow $$pkg"; \
		stow --target=$$HOME --no-folding --ignore='\.test\.zsh$$' --ignore='\.zsh_plugins\.zsh$$' $$pkg; \
	done

uninstall:
	@for pkg in $(PACKAGES); do \
		echo "==> unstow $$pkg"; \
		stow --target=$$HOME --delete $$pkg; \
	done

restow:
	@for pkg in $(PACKAGES); do \
		echo "==> restow $$pkg"; \
		stow --target=$$HOME --no-folding --ignore='\.test\.zsh$$' --ignore='\.zsh_plugins\.zsh$$' --restow $$pkg; \
	done

install-%:
	stow --target=$$HOME --no-folding --ignore='\.test\.zsh$$' --ignore='\.zsh_plugins\.zsh$$' $*

uninstall-%:
	stow --target=$$HOME --delete $*

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
		zsh -c 'source $(ZTR_PATH) && source "'"$$f"'"' || fail=1; \
		echo; \
	done; \
	exit $$fail

check: lint test

sbx:
	@sbx/claude/build.sh
