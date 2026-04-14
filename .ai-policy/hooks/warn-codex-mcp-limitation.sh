#!/usr/bin/env bash
# SessionStart hook for Codex CLI.
# Outputs a warning about the MCP tool-blocking limitation.
# Plain text on stdout is added as extra developer context by Codex.

cat <<'EOF'
WARNING — GitHub MCP tool blocking is NOT enforced in Codex.
Codex hooks (PreToolUse) cannot intercept MCP tool calls.
If you have GitHub MCP configured, the following tools are NOT blocked:
  push_files, create_or_update_file, delete_file
The protected-branch bash hook is the primary safeguard for preventing
writes to protected branches. Do not rely on MCP tool blocking in Codex.
EOF
