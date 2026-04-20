---
name: python-scripting
description: User-specific conventions for Python utility and automation scripts. TRIGGER when creating a new `.py` file, editing an existing Python script, or scaffolding any Python entrypoint (argparse, logging, config, credentials, subprocess wrappers). Codifies `logging` over `print`, argparse with custom `HelpFormatter` + `--loglevel`, `ruff` formatting and linting, credentials from config/env (never constants), library-native config APIs (e.g., `snowflake` connector's `connection_name=`), purpose-built libraries over regex (`sqlglot` for SQL, `BeautifulSoup` for HTML), virtualenv development, Justfile recipe integration, and credential export via `.envrc` from a `pass` store. Canonical exemplars: `~/.local/bin/bd-timew` and `snowflake_migrations/scripts/get_snowflake_procs.py`. Canonical convention list: Beads issue J121-91l.
author: Michael Haynes
scope: global
tags: [python, scripting, conventions, tooling]
timestamps:
  - action: created
    at: 2026-04-20T02:26:45-05:00
    actor: Michael Haynes
comments:
  - "Source: patterns codified retroactively from existing scripts (bd-timew bridge, get_snowflake_procs.py, parse-nessus-was.py). Canonical convention list tracked in Beads as J121-91l."
  - "Motivation: without the skill, each new Python script rediscovered the same choices (logging vs print, argparse formatting, credential source, library preference). Codifying them into a skill ensures consistency across the ecosystem and lets new scripts inherit conventions automatically."
  - "Projected use: fires whenever a Python file is created or edited. Particularly load-bearing for scripts that touch credentials (Snowflake, Jira) or subprocess wrappers — the convention insists on pass-backed .envrc patterns and library-native config APIs rather than hand-rolled regex."
---

# Python Scripting Conventions

Apply these to all Python utility and automation scripts unless the user has explicitly overridden them for a project.

## When to invoke this skill autonomously

- Any time you are about to write a new `.py` file.
- When editing an existing Python script's CLI, logging, config, or credential handling.
- When the user asks you to "scaffold", "add a CLI to", or "convert to a proper script" any Python code.
- When reviewing Python code for conformance — the checklist below is the rubric.

## Target

- **Python 3.10+.** Use PEP-604 unions (`int | None`), built-in generics (`list[str]`, `dict`), and `from __future__ import annotations` for forward compat.
- **Shebang:** `#!/usr/bin/env python3`. Never hardcode an interpreter path — mise-managed Python lives under `~/.local/share/mise/` and will not match.

## File shape

- **Module docstring:** one-line summary, blank line, then purpose / algorithm / usage examples. The docstring IS the cold-read documentation. It also becomes the `--help` description when you pass `description=__doc__` (see CLI section).
- **`if __name__ == "__main__":`** guard around a `main()` call. No top-level side effects.
- **Imports:** `from __future__ import annotations` first, blank line, stdlib alphabetized, blank line, third-party alphabetized.
- **`pathlib.Path`** over `os.path` string manipulation.
- **Type hints** on every function signature (args + return). Skip them on trivial locals; use them where the type is non-obvious or crosses a function boundary. Built-in generics (`list[str]`), not `typing.List`.

## CLI: argparse with a custom formatter and `--loglevel`

Every script with CLI args uses a `get_cli_arguments()` function, a combined `HelpFormatter`, and always exposes `--loglevel`. Avoid `click`, `typer`, and other heavy CLI frameworks — argparse is stdlib, zero-install, zero-surprise.

```python
import argparse

class HelpFormatter(
    argparse.RawDescriptionHelpFormatter,
    argparse.ArgumentDefaultsHelpFormatter,
):
    """Preserve whitespace in description/epilog AND show defaults in --help."""


def get_cli_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,           # module docstring becomes --help preamble
        formatter_class=HelpFormatter,
        epilog="...",                  # optional; use when examples aren't in __doc__
    )
    parser.add_argument(
        "--loglevel", "-l",
        default="INFO",
        type=lambda v: v.strip().upper(),
        help="Logging verbosity (DEBUG, INFO, WARNING, ERROR).",
    )
    # ... script-specific args
    return parser.parse_args()
```

**Multi-command scripts:** argparse subcommands with `dest="cmd"`, `required=True`, one `sub.add_parser(...)` per verb with explicit `help=`. Add dry-run variants for state-mutating commands (cheap, valuable for debugging). See `~/.local/bin/bd-timew` for the pattern.

**Mutually exclusive args:** `parser.add_mutually_exclusive_group(required=True)` when two input paths are alternates (e.g., `--connection <profile>` vs. raw `--account/--username/--private-key-file`).

## Logging (not `print` for diagnostics)

- **`logging` module**, not `print`, for progress, warnings, and errors. `print` is reserved for script *output* (data written to stdout for pipes).
- **Use `rich.logging.RichHandler`** instead of `logging.basicConfig`. It gives you colorized levels, readable tracebacks, and proper stderr routing with no format-string boilerplate.
- Module-level `logger = getLogger(__name__)`. Configure once in `main()` via a small `setup_logger()` helper called after argparse:

```python
from logging import getLogger
from rich.logging import RichHandler

logger = getLogger(__name__)


def setup_logger(args: argparse.Namespace) -> None:
    handler = RichHandler(level=args.loglevel)
    logger.addHandler(handler)
    logger.setLevel(args.loglevel)
```

Canonical shape: `snowflake_migrations/scripts/get_snowflake_procs.py` (`setup_logger` at line 842).

- **Never mix streams.** Data → stdout via `print`. Diagnostics → stderr via `logger.info` / `logger.warning` / `logger.error`.

## Credentials

- **Never** hardcode credentials as constants, defaults, or literals.
- Read from environment variables or existing library config files. Prefer library-native paths:
  - `os.environ["FOO_PASSWORD"]`
  - `snowflake.connector.connect(connection_name="J121-dev")` — loads `~/.config/snowflake/config.toml`
  - `boto3.Session()` — reads `~/.aws/credentials`
- **Local dev pattern:** export env vars via `.envrc` (direnv), with values pulled from a `pass` store on each shell entry. Example `.envrc` line: `export SNOWFLAKE_PASSWORD="$(pass show snowflake/j121-dev)"`.
- Never echo credentials to logs. When logging connection info, redact or log only the handle (e.g., connection profile name).

## Config files

- **Library-native APIs first.** Use the library's own config loader (`snowflake.connector.connect(connection_name=...)`, `boto3.Session(profile_name=...)`) before hand-rolling a TOML / INI / YAML parser. Hand-rolled parsers drift from the library's.
- **YAML:** `yaml.safe_load` only. Never `yaml.load` without an explicit `SafeLoader`.
- **JSON:** prefer tool-native JSON output (`bd show --json`, `az ... -o json`) over parsing formatted text — text layouts drift silently.
- **Placement:** config files live alongside the data they describe (e.g., `.beads/bd-timew.yaml` beside the Beads DB), not `~/.config/` by default.

## Machine-specific details

- **Never hardcode** paths, hostnames, usernames, ports.
- Discover via `pathlib.Path.home()`, `platform.node()`, existing config files, CLI args, or env vars.

## Subprocess

- `subprocess.run([...])` with a **list** of args. `shell=True` only when you explicitly need shell expansion *and* have sanitized inputs.
- Always `text=True`. Be explicit about `check=`. Use `capture_output=True` only when you need stdout/stderr.
- When the pattern repeats, extract a thin `run()` wrapper:

```python
def run(cmd: list[str], *, check: bool = True, capture: bool = False):
    return subprocess.run(cmd, check=check, text=True, capture_output=capture)
```

## Text processing: purpose-built libraries over regex

Reach for a grammar-aware library before a regex for any structured format:

| Format | Library |
|---|---|
| SQL | `sqlglot` (parse, transform, generate) |
| HTML | `BeautifulSoup` or `lxml` |
| JSON | stdlib `json` |
| YAML | `PyYAML` (`safe_load`) |
| TOML | stdlib `tomllib` (read) / `tomli_w` (write) |
| XML | `lxml` |
| Dates | `dateutil.parser` for loose input, stdlib `datetime.fromisoformat` for strict |

Regex is fine for genuinely unstructured text or cheap one-off extraction. For anything grammatical, regex is the last resort — it will break on comments, nested quoting, or whitespace variation.

## Virtualenvs

- **Develop in a venv** unless the script is explicitly system-wide (e.g., `~/.local/bin/` utilities that need to run without activating anything).
- **`uv`** is the preferred venv / dependency manager. Invocation shape: `uv run script.py`, `uv add <pkg>`.
- A script that requires `pip install X` but does not declare `X` in a `pyproject.toml`, `requirements.txt`, or inline PEP 723 script metadata is a bug. Declare dependencies explicitly.

## Tooling

- **`ruff`** is the formatter and linter. Run `ruff format` and `ruff check --fix` before committing. Project config in `pyproject.toml`.
- **Justfile integration:** if the project has a `Justfile`, add a recipe for every long-lived invocation (e.g., `just export-procs`, `just report-vehicles`). Justfile recipes are the discoverable CLI surface — they double as documentation.

## Errors and output

- **User-facing failures:** `sys.exit("<progname>: <message>")` — prefix with the program name, lowercase message, no trailing period (POSIX tool convention). Tracebacks are for bugs, not expected errors.
- **Warnings → stderr** via `log.warning`. **Normal output → stdout** via `print` (or leave stdout untouched if the script has no data output).
- **Never swallow exceptions silently.** If you `except`, act on it — log, re-raise, or `sys.exit`.

## Comments

- Default to none; let docstrings and identifiers carry meaning.
- Write a comment only when the WHY is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug). Never narrate WHAT the code does.

## Anti-patterns

- Global mutable config singletons. Pass state explicitly.
- Decorators unless they earn their keep.
- "Preparing for the future" flags or hooks with no current caller.
- Heavy CLI frameworks (`click`, `typer`) when argparse suffices.
- Hand-rolled config parsers when the library ships one.
- Regex parsing of structured formats.
- Hardcoded credentials, paths, hostnames, or usernames.
- Mixing data output and diagnostics on stdout.

## Reference exemplars

- **`~/.local/bin/bd-timew`** — Beads ↔ Timewarrior bridge. Demonstrates: argparse subcommands with required `dest`, a `run()` subprocess wrapper, YAML config resolution with `safe_load`, clean `sys.exit("prog: msg")` errors, dry-run variant (`resolve`). Source in Chezmoi: `home/dot_local/bin/executable_bd-timew.tmpl`.
- **`snowflake_migrations/scripts/get_snowflake_procs.py`** — single-command Python script for a J121 task. Demonstrates: `HelpFormatter` inheriting from `RawDescription` + `ArgumentDefaults`, `description=__doc__` so the module docstring becomes the `--help` preamble, library-native Snowflake config via `connection_name=`, `RichHandler` for log output, `sqlglot` for SQL parsing, mutually exclusive connection arg groups.

## Source of truth

The canonical convention list lives in Beads issue **J121-91l** (`bd show J121-91l`). Update that bead when conventions evolve, then resync this skill.
