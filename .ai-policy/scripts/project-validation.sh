#!/usr/bin/env bash
set -eu

bash -n ./.ai-policy/scripts/*.sh ./.githooks/*
