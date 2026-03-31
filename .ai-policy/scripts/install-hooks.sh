#!/usr/bin/env bash
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks

chmod +x "$ROOT_DIR/.ai-policy/scripts/"*.sh
chmod +x "$ROOT_DIR/.githooks/"*

echo "Installed Git hooks from .githooks"
