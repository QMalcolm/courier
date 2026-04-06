defmodule Courier.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CourierWeb.Telemetry,
      Courier.Repo,
      {Ecto.Migrator,
        repos: Application.fetch_env!(:courier, :ecto_repos),
        skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:courier, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Courier.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Courier.Finch},
      # Supervised task pool for async recipe deliveries
      {Task.Supervisor, name: Courier.TaskSupervisor},
      # Quantum scheduler for delivering recipes on schedule
      Courier.Scheduler,
      # Start to serve requests, typically the last entry
      CourierWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Courier.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CourierWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?(), do: false
end
