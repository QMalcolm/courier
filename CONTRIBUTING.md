# Contributing to Courier

## Prerequisites

- Elixir 1.18+
- Erlang/OTP 28+
- Node.js (for CodeMirror assets)
- [Calibre](https://calibre-ebook.com/) — only needed at runtime for recipe delivery and ebook creation; the UI works without it locally

## Setup

```bash
mix setup       # fetch deps, create/migrate DB, build assets
mix phx.server  # start the dev server at http://localhost:4000
```

## Running tests

```bash
mix test
```

Tests spin up a real SQLite test database (created automatically via the `test` alias in `mix.exs`). No external services are required.

For a local coverage report:

```bash
mix coveralls.html   # opens cover/excoveralls.html
```

**Note on coverage:** `Courier.Runner` and `Courier.EbookRunner` are excluded from the 90% threshold because they shell out to Calibre binaries that aren't present in CI or typical dev environments. Their behaviour is exercised manually or in integration environments where Calibre is installed.

## Code style

```bash
mix format        # auto-formats all Elixir/HEEx files
mix format --check-formatted   # what CI would catch
mix compile --warnings-as-errors  # also enforced in CI
```

## Commit conventions

- One concern per commit — bug fixes, refactors, and feature additions are separate commits. Use `git add -p` if needed.
- Commit messages explain *why*, not just what. Include any design choices or alternatives rejected.
- All commits must be GPG-signed (`commit.gpgsign = true`).
- Work on a feature branch and open a PR — never commit directly to `main`.

## Pre-commit hook

The repo ships a CodeScene quality gate in `.githooks/pre-commit`. To enable it:

```bash
git config core.hooksPath .githooks
```

It only runs if the `cs` CLI is installed and `CS_ACCESS_TOKEN` is set, so it's a no-op otherwise.

## Opening a PR

- Target `main`.
- Keep PRs focused — one logical change per PR.
- CI must pass (tests + coverage threshold + no compile warnings).
