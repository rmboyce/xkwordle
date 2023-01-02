defmodule Kwordle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Kwordle.Repo,
      # Start the Telemetry supervisor
      KwordleWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Kwordle.PubSub},
      # Start the Endpoint (http/https)
      KwordleWeb.Endpoint,
      # Start a worker by calling: Kwordle.Worker.start_link(arg)
      # {Kwordle.Worker, arg}
      {Registry, name: Kwordle.RoomRegistry, keys: :unique},
      {DynamicSupervisor, name: Kwordle.RoomSupervisor, strategy: :one_for_one}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kwordle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KwordleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
