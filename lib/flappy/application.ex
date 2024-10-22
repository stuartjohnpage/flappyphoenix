defmodule Flappy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlappyWeb.Telemetry,
      Flappy.Repo,
      {DNSCluster, query: Application.get_env(:flappy, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Flappy.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Flappy.Finch},
      # Start a worker by calling: Flappy.Worker.start_link(arg)
      # {Flappy.Worker, arg},
      # Start to serve requests, typically the last entry
      FlappyWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Flappy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlappyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
