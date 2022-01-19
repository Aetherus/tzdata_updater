defmodule TzdataUpdater.FileSystemMonitor do
  use GenServer, restart: :permanent

  alias TzdataUpdater.FileSystemTaskSupervisor, as: FSTaskSup

  @type opt ::
          {:monitored_dir, String.t()}
          | {:handlers, [module()]}

  @type opts :: [opt()]

  @spec start_link(opts()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def force_update! do
    GenServer.call(__MODULE__, :touch)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, opts, {:continue, :start_monitor}}
  end

  @impl true
  def handle_call(:touch, _from, opts) do
    monitored_dir = opts[:monitored_dir]

    FSTaskSup
    |> Task.Supervisor.async_nolink(fn -> recursive_touch!(monitored_dir) end)
    |> Task.await()

    {:reply, :ok, opts}
  end

  @impl true
  def handle_continue(:start_monitor, opts) do
    monitored_dir = opts[:monitored_dir]

    {:ok, watcher_pid} =
      FileSystem.start_link(dirs: [monitored_dir], backend: :fs_inotify, recursive: true)

    FileSystem.subscribe(watcher_pid)
    {:noreply, [{:watcher_pid, watcher_pid} | opts]}
  end

  @impl true
  def handle_info({:file_event, watcher_pid, {path, events}}, opts) do
    with ^watcher_pid <- opts[:watcher_pid],
         true <- Process.alive?(watcher_pid) do
      handlers = opts[:handlers] || []

      FSTaskSup
      |> Task.Supervisor.async_stream_nolink(
        handlers,
        fn handler ->
          :ok = handler.handle(path, events)
        end,
        ordered: false,
        timeout: 60_000
      )
      |> Stream.run()

      {:noreply, opts}
    else
      _ -> {:stop, :normal, opts}
    end
  end

  def handle_info({:file_event, _watcher_pid, :stop}, opts) do
    {:stop, :normal, Keyword.delete(opts, :watcher_pid)}
  end

  def handle_info(_msg, opts) do
    {:noreply, opts}
  end

  @impl true
  def terminate(_reason, opts) do
    if opts[:watcher_pid], do: Process.exit(opts[:watcher_pid], :normal)
  end

  defp recursive_touch!(path) do
    if File.dir?(path) do
      File.touch!(path)

      path
      |> File.ls!()
      |> Enum.map(&Path.join(path, &1))
      |> Enum.each(&recursive_touch!/1)
    else
      File.write!(path, [], [:append])
    end
  end
end
