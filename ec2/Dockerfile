FROM mcr.microsoft.com/devcontainers/python:3.12

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install uv (matches the devcontainer feature)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx

# Pre-install useful VS Code extensions so candidates don't wait
RUN code-server \
    --install-extension ms-python.python \
    --install-extension ms-python.vscode-pylance \
    --install-extension charliermarsh.ruff

# Workspace lives at /workspace (cloned at build time, see Makefile)
WORKDIR /workspace

# Hide .git/ before code-server starts; restore on container stop
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
