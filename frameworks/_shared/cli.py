"""Typer CLI factory shared by every framework's `main.py`."""
from __future__ import annotations

from typing import Callable

import typer
from rich import print as rprint


def make_cli(run_fn: Callable[[str], str], label: str) -> typer.Typer:
    """Build a Typer app with one command: single-prompt or REPL mode."""
    app = typer.Typer(add_completion=False, no_args_is_help=False)

    @app.command()
    def run(prompt: str | None = typer.Option(None, help="Single prompt to run")) -> None:
        if prompt:
            rprint(run_fn(prompt))
            raise SystemExit(0)

        rprint(f"[bold green]{label} REPL. Type 'exit' to quit.[/bold green]")
        while True:
            try:
                text = input("You> ").strip()
            except (EOFError, KeyboardInterrupt):
                rprint()
                break
            if text.lower() in {"exit", "quit"}:
                break
            rprint(run_fn(text))

    return app
