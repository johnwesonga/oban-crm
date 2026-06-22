defmodule Crm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CrmWeb.Telemetry,
      Crm.Repo,
      {DNSCluster, query: Application.get_env(:crm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Crm.PubSub},
      # Start a worker by calling: Crm.Worker.start_link(arg)
      # {Crm.Worker, arg},
      # Start to serve requests, typically the last entry
      {Oban, oban_config()},
      CrmWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CrmWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config do
    Application.fetch_env!(:crm, Oban)
  end
end
