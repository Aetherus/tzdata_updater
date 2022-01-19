defmodule TzdataUpdater.Version do
  defstruct [:tzdata, :ets, :wrapper]

  @type t :: %__MODULE__{
          tzdata: String.t(),
          ets: String.t(),
          wrapper: String.t()
        }

  def new(tzdata_version, ets_version) do
    tzdata_version = IO.iodata_to_binary(tzdata_version)
    ets_version = IO.iodata_to_binary(ets_version)

    %__MODULE__{
      tzdata: tzdata_version,
      ets: ets_version,
      wrapper: "#{tzdata_version}-#{ets_version}"
    }
  end
end
