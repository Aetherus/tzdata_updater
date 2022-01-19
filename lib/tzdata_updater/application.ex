defmodule TzdataUpdater.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias TzdataUpdater.FileSystemMonitor

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: TzdataUpdater.Worker.start_link(arg)
      # {TzdataUpdater.Worker, arg}
      {TzdataUpdater.Boot, Application.fetch_env!(:tzdata_updater, :git_repo)},
      TzdataUpdater.DetsHolder,
      {Task.Supervisor, name: TzdataUpdater.FileSystemTaskSupervisor},
      {FileSystemMonitor,
       [
         monitored_dir: Application.get_env(:tzdata, :data_dir),
         handlers: [
           TzdataUpdater.FileSystemEventHandlers.STDIO,
           TzdataUpdater.FileSystemEventHandlers.Publish
         ]
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: TzdataUpdater.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
