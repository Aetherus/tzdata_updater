defmodule TzdataUpdater.DetsHolder do
  use GenServer, restart: :permanent

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def update_tzdata_ets_version(version) do
    GenServer.call(__MODULE__, {:update_tzdata_ets_version, version})
  end

  def get_tzdata_ets_version do
    GenServer.call(__MODULE__, :get_tzdata_ets_version)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    :dets.open_file(
      :tzdata_ets_version,
      file: 'priv/tzdata_ets_version.dets',
      type: :set,
      access: :read_write,
      ram_file: true
    )
  end

  @impl true
  def handle_call({:update_tzdata_ets_version, version}, _from, dets_table) do
    {:reply, :dets.insert(dets_table, {:tzdata_ets_version, version}), dets_table}
  end

  def handle_call(:get_tzdata_ets_version, _from, dets_table) do
    case :dets.lookup(dets_table, :tzdata_ets_version) do
      [] -> {:reply, nil, dets_table}
      [{:tzdata_ets_version, version}] -> {:reply, version, dets_table}
    end
  end

  @impl true
  def terminate(_reason, dets_table) do
    :dets.sync(dets_table)
  end
end
