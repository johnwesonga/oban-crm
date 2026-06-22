# CRM — AI-Powered Outreach Pipeline

A Phoenix LiveView CRM that automates B2B outreach email drafting with an LLM, then gates sending behind a human review step.

## How it works

1. Add leads (contact name, company, email) via the `/leads` UI.
2. Every 5 minutes, an Oban cron job picks up `:pending` leads and enqueues an LLM drafting job per lead.
3. The LLM (Claude Haiku by default) generates a personalized email draft — subject + body — stored against the lead.
4. Drafted emails appear in the `/drafts` review queue. You can edit, approve, or reject each one.
5. Approving queues a send job; the email is delivered via Swoosh and the lead is marked `:sent`.

## Setup

```bash
# Install deps, create DB, run migrations, seed, build assets
mix setup

# Set your Anthropic API key (used for LLM drafting)
export ANTHROPIC_API_KEY="..."

# Start the server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

## Key URLs

| URL | Purpose |
|---|---|
| `/leads` | Manage leads |
| `/drafts` | Review and approve AI-drafted emails |
| `/dev/mailbox` | Preview sent emails locally (dev only) |
| `/oban` | Oban job dashboard (dev only) |
| `/dev/dashboard` | Phoenix LiveDashboard (dev only) |

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
- **req_llm** — LLM client (Anthropic Claude)
- **Swoosh** — email delivery (local adapter in dev)
- **Ecto / PostgreSQL** — persistence
- **Tailwind CSS v4** + **DaisyUI** — styling
