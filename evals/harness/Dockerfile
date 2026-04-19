# Sandbox image for baseline-harness runs with the Claude Code CLI.
# Used only by --agent claude-code. Mock mode runs on the host without Docker.
FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-pip git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/local/bin/python

RUN npm install -g @anthropic-ai/claude-code pytest \
    && pip3 install --break-system-packages pytest

WORKDIR /workspace
CMD ["sleep", "infinity"]
