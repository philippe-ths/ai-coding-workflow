#!/usr/bin/env bash
set -eu

git symbolic-ref --quiet --short HEAD 2>/dev/null || true
