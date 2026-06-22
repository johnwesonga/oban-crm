# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Initial setup (deps, DB, assets)
mix setup

# Start the dev server
mix phx.server
# or with IEx
iex -S mix phx.server

# Run all tests (auto-creates and migrates test DB)
mix test

# Run a single test file
mix test test/crm_web/controllers/page_controller_test.exs

# Run only previously failed tests
mix test --failed

# Pre-commit check (compile with warnings-as-errors, unused deps, format, tests)
mix precommit

# DB operations
mix ecto.setup        # create + migrate + seed
mix ecto.reset        # drop + recreate
mix ecto.migrate      # run pending migrations

# Asset building
mix assets.build      # dev build (tailwind + esbuild)
mix assets.deploy     # minified production build + digest
```

Dev-only dashboards (when `dev_routes: true`):
- `http://localhost:4000/dev/dashboard` — Phoenix LiveDashboard
- `http://localhost:4000/dev/mailbox` — Swoosh local mailbox preview
- `http://localhost:4000/oban` — Oban Web job dashboard

## Environment Variables

`ANTHROPIC_API_KEY` must be set for LLM email drafting to work. In development this is loaded from `.envrc` via `direnv`.

The AI model is configured in `config/config.exs` via:
```elixir
config :crm, ai_model: "anthropic:claude-haiku-4-5-20251001"
```
Override at runtime with the `:ai_model` application env.

## Architecture

This is a Phoenix 1.8 + LiveView CRM that automates outreach email drafting using an LLM, with a human-in-the-loop review step before sending.

### Lead lifecycle (state machine)

```
pending → drafting → awaiting_review → approved → sent
                   ↘ failed          ↘ failed
awaiting_review → pending  (reject)
failed → pending            (retry)
```

State transitions are enforced in `Crm.Pipeline.Lead` via `validate_status_transition/3` — illegal transitions produce a changeset error. Each lifecycle change has a focused changeset function (`status_changeset`, `drafted_changeset`, `sent_changeset`, `error_changeset`) rather than one monolithic changeset.

### Core modules

| Module | Role |
|---|---|
| `Crm.Pipeline` | Context — all public CRUD + lifecycle ops on leads. Broadcasts PubSub on every state change. |
| `Crm.Pipeline.Lead` | Ecto schema on `sales_pipeline` table. Owns the state machine logic. |
| `Crm.LLM` | Calls the LLM via `req_llm`. Reads model from app config. |
| `Crm.Llm.PromptBuilder` | Builds system + user prompts. Edit here to tune email style/format. |
| `Crm.Llm.ResponseParser` | Parses + validates LLM JSON response; strips markdown fences if the model misbehaves. |
| `Crm.Mailer` | Thin Swoosh wrapper. From address configured via `:mailer_from_name` / `:mailer_from_address` app env. |

### Oban background workers

Three queues with concurrency limits set in `config/config.exs`:

| Worker | Queue | Concurrency | Trigger |
|---|---|---|---|
| `ScanPipelineWorker` | `pipeline` | 1 (serial) | Oban cron every 5 min |
| `DraftEmailWorker` | `drafting` | 5 | Enqueued by ScanPipelineWorker per lead |
| `SendEmailWorker` | `sending` | 3 | Enqueued by `Pipeline.approve_lead/1` |

`ScanPipelineWorker` is deduplicated globally (one running at a time). `DraftEmailWorker` is deduplicated per `lead_id`. `SendEmailWorker` handles HTTP 429 from the mail provider by snoozing for 60s.

### PubSub channels

| Topic | Message | Subscribers |
|---|---|---|
| `"leads"` | `{:lead_updated, lead}` | `LeadsLive` |
| `"email_drafts"` | `{:new_draft, lead}` | `DraftsLive` |

Both LiveViews subscribe on `connected?(socket)` and patch in-memory state on receipt — no DB re-query on each update.

### LiveViews

- `CrmWeb.LeadsLive` (`/leads`, `/leads/new`, `/leads/:id/edit`) — CRUD table with inline slide-in form. Edit is only available when a lead is `:pending`.
- `CrmWeb.DraftsLive` (`/drafts`) — review queue for `:awaiting_review` leads. Approve enqueues a send; reject resets to `:pending`.

### Key constraints

- `email_address` has a `unique_index` in the DB — duplicate leads are rejected at the DB level.
- A partial index on `already_emailed = 'pending'` makes `ScanPipelineWorker`'s query fast at scale.
- Leads can only be edited when `:pending` (enforced in the UI; the edit route still works at any status so guard at the context layer if needed).

## Project guidelines (from AGENTS.md)

- Run `mix precommit` before finishing any change.
- Use `:req` / `Req` for HTTP — never `:httpoison`, `:tesla`, or `:httpc`.
- LiveView templates must begin with `<Layouts.app flash={@flash} ...>`.
- Never call `<.flash_group>` outside `layouts.ex`.
- Always use `<.icon name="hero-...">` for icons — never `Heroicons` modules.
- Always use `<.input>` from `core_components.ex` for form inputs.
- Use `Ecto.Changeset.get_field/2` to read changeset fields — never map access syntax on structs.
- Fields set programmatically (e.g. foreign keys) must not appear in `cast` calls.
- Always preload Ecto associations before accessing them in templates.
- Use `Task.async_stream/3` with `timeout: :infinity` for concurrent enumeration.
- Never nest multiple modules in the same file.
