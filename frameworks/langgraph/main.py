from frameworks._shared.cli import make_cli

from .graph import run_graph

app = make_cli(run_graph, label="LangGraph skeleton")


if __name__ == "__main__":
    app()
