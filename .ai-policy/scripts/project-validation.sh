#!/usr/bin/env bash
set -eu

bash -n ./.ai-policy/scripts/*.sh ./.ai-policy/hooks/*.sh ./.githooks/*
./.ai-policy/scripts/test-claude-code-enforcement.sh
./.ai-policy/scripts/test-codex-enforcement.sh
