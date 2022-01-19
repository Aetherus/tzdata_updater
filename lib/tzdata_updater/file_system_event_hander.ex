defmodule TzdataUpdater.FileSystemEventHandler do
  @callback handle(String.t(), term()) :: :ok | {:error, term()}
end
