# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :crm,
  ecto_repos: [Crm.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :crm, CrmWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CrmWeb.ErrorHTML, json: CrmWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Crm.PubSub,
  live_view: [signing_salt: "w0mqIZXY"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :crm, Crm.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  crm: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  crm: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :crm, Oban,
  repo: Crm.Repo,
  plugins: [
    # Periodic cleanup of completed jobs
    # 7 days
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},

    # Catches and rescues orphaned jobs after node crashes
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(5)},

    # The cron scheduler — scans for pending leads every 5 minutes
    {Oban.Plugins.Cron,
     crontab: [
       {"*/5 * * * *", Crm.Workers.ScanPipelineWorker}
     ]}
  ],
  queues: [
    # Serial — only 1 scan at a time
    pipeline: 1,
    # Up to 5 concurrent LLM drafts
    drafting: 5,
    # Up to 3 concurrent email sends
    sending: 3
  ]

config :crm, ai_model: "anthropic:claude-haiku-4-5-20251001"
