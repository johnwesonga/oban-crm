# CRM — AI-Powered Outreach Pipeline

A Phoenix LiveView CRM that automates B2B outreach email drafting with an LLM, then gates sending behind a human review step.

## How it works

1. Add leads (contact name, company, email) via the `/leads` UI.
2. Every 5 minutes, an Oban cron job picks up `:pending` leads and enqueues an LLM drafting job per lead. You can also trigger drafting immediately with the **Draft** button on any pending lead.
3. The LLM generates a personalized email draft — subject + body — stored against the lead.
4. Drafted emails appear in the `/drafts` review queue. You can edit, approve, regenerate, or reject each one.
5. Approving queues a send job; the email is delivered via Swoosh and the lead is marked `:sent`.
6. If drafting or sending fails after all retries, the lead is marked `:failed`. Use the **Retry** button to re-queue it.

## Setup

```bash
# Install deps, create DB, run migrations, seed, build assets
mix setup

# Start the server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

### LLM configuration

By default (in `config/dev.exs`) the app calls a local LM Studio instance at `http://localhost:1234/v1` using the `mistralai/devstral-small-2-2512` model via the OpenAI-compatible API.

To use Anthropic instead, set `ANTHROPIC_API_KEY` in your `.envrc` and update `config/dev.exs`:

```elixir
config :crm,
  ai_model: "anthropic:claude-haiku-4-5-20251001",
  ai_base_url: nil   # not needed for Anthropic
```

## Key URLs

| URL | Purpose |
|---|---|
| `/leads` | Manage leads — search, filter, paginate, draft, retry |
| `/drafts` | Review AI-drafted emails — edit, approve, regenerate, or reject |
| `/dev/mailbox` | Preview sent emails locally (dev only) |
| `/oban` | Oban job dashboard (dev only) |
| `/dev/dashboard` | Phoenix LiveDashboard (dev only) |

## Lead lifecycle

```
pending → drafting → awaiting_review → approved → sent
                   ↘ failed          ↘ failed
awaiting_review → pending  (reject or regenerate)
failed → pending            (retry)
```

## Development

```bash
mix test                  # run all tests
mix test --failed         # re-run only failed tests
mix precommit             # lint + format + test (run before committing)
mix ecto.reset            # drop and recreate the database
```

## Tech stack

- **Phoenix 1.8** + **LiveView 1.1** — real-time UI via PubSub
- **Oban 2.21** — background jobs (scan, draft, send)
- **req_llm** — LLM client (local or Anthropic)
- **Swoosh** — email delivery (local adapter in dev)
- **Ecto / PostgreSQL** — persistence
- **Tailwind CSS v4** + **DaisyUI** — styling
