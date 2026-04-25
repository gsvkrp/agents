from frameworks._shared.cli import make_cli

from .agent import run_agent

app = make_cli(run_agent, label="Agents SDK skeleton")


if __name__ == "__main__":
    app()
