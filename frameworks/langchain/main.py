from frameworks._shared.cli import make_cli

from .agent import run_agent

app = make_cli(run_agent, label="LangChain skeleton")


if __name__ == "__main__":
    app()
