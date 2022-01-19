defmodule TzdataUpdater.FileSystemEventHandlers.STDIO do
  @behaviour TzdataUpdater.FileSystemEventHandler

  @impl true
  def handle(path, events) do
    IO.puts("Events #{inspect(events)} triggered on path [#{path}].")
  end
end
