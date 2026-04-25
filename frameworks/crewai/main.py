from frameworks._shared.cli import make_cli

from .crew import run_crew

app = make_cli(run_crew, label="CrewAI skeleton")


if __name__ == "__main__":
    app()
