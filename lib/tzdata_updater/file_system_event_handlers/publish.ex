defmodule TzdataUpdater.FileSystemEventHandlers.Publish do
  @behaviour TzdataUpdater.FileSystemEventHandler

  require Logger
  require EEx
  alias TzdataUpdater.DetsHolder

  @tzdata_wrapper_root "tmp/tzdata_wrapper"
  @tzdata_dest_data_dir Path.join(@tzdata_wrapper_root, "/priv/tzdata")
  @tzdata_wrapper_mix_exs_path Path.join(@tzdata_wrapper_root, "mix.exs")
  @tzdata_wrapper_mix_exs_template_path "priv/template/mix.exs.eex"

  @impl true
  def handle(path, [:modified, :closed]) do
    with dir <- Path.expand(Application.get_env(:tzdata, :data_dir)),
         ^dir <- Path.dirname(path),
         "latest_remote_poll.txt" <- Path.basename(path) do
      publish(dir)
    else
      _ -> :ok
    end
  end

  def handle(_, _), do: :ok

  defp publish(dir) do
    with version <- get_version(),
         prev_ets_version <- DetsHolder.get_tzdata_ets_version(),
         true <- version.ets != prev_ets_version,
         :ok <- copy_ets_dir(dir),
         :ok <- update_wrapper_mix_exs(version: version),
         :ok <- push_to_git_repo(version),
         :ok <- update_dets(version) do
      :ok
    else
      false -> :ok
      error -> error
    end
  end

  defp get_version do
    {:ok, tzdata_version} = :application.get_key(:tzdata, :vsn)
    ets_version = Tzdata.tzdata_version()
    TzdataUpdater.Version.new(tzdata_version, ets_version)
  end

  defp copy_ets_dir(ets_dir) do
    Logger.info("Copying ETS directory ...")

    with {:ok, _} <- File.cp_r(ets_dir, @tzdata_dest_data_dir) do
      Logger.info("Done Copying ETS directory.")
      :ok
    end
  end

  EEx.function_from_file(
    :defp,
    :render_string_wrapper_mix_exs,
    @tzdata_wrapper_mix_exs_template_path,
    [:assigns]
  )

  defp update_wrapper_mix_exs(assigns) do
    Logger.info("Writing mix.exs ...")
    content = render_string_wrapper_mix_exs(assigns)

    File.write!(@tzdata_wrapper_mix_exs_path, content)
    |> tap(fn result -> Logger.info("Writing mix.exs returns #{inspect(result)}") end)
  end

  defp push_to_git_repo(version) do
    Logger.info("Pushing version #{version.wrapper} to git repo ...")

    with {_, 0} <-
           System.cmd("git", ~w[add --all .], cd: @tzdata_wrapper_root, stderr_to_stdout: true),
         {_, 0} <-
           System.cmd("git", ["commit", "-m", "v#{version.wrapper}"],
             cd: @tzdata_wrapper_root,
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ["tag", version.wrapper],
             cd: @tzdata_wrapper_root,
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ~w[push origin master],
             cd: @tzdata_wrapper_root,
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ~w[push --tags origin],
             cd: @tzdata_wrapper_root,
             stderr_to_stdout: true
           ) do
      Logger.info("Done pushing version #{version.wrapper} to git repo.")
      :ok
    else
      {err_msg, exit_code} ->
        if err_msg =~ ~r/nothing to commit, working tree clean/i do
          Logger.info(err_msg)
          :ok
        else
          Logger.error("Failed to push to git repo. Exit code: #{exit_code}.")
          Logger.error(err_msg)
          {:error, "Failed to push to git repo."}
        end
    end
  end

  defp update_dets(version) do
    DetsHolder.update_tzdata_ets_version(version.ets)
  end
end
