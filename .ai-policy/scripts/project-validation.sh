#!/usr/bin/env bash
set -eu

bash -n ./.ai-policy/scripts/*.sh ./.ai-policy/hooks/*.sh ./.githooks/*
./.ai-policy/scripts/test-claude-code-enforcement.sh
./.ai-policy/scripts/test-codex-enforcement.sh
./.ai-policy/scripts/test-vscode-copilot-enforcement.sh
./.ai-policy/scripts/test-gemini-enforcement.sh
./.ai-policy/scripts/test-changelog-hook.sh
./.ai-policy/scripts/test-session-tags-hook.sh
