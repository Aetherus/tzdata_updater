defmodule TzdataUpdater.Boot do
  use GenServer, restart: :transient

  @tzdata_wrapper_root "tmp/tzdata_wrapper"

  def start_link(git_repo) do
    GenServer.start_link(__MODULE__, git_repo)
  end

  @impl true
  def init(git_repo) do
    :ok = File.mkdir_p!("tmp")
    if File.exists?(@tzdata_wrapper_root) do
      pull_git_repo!()
    else
      clone_git_repo!(git_repo)
    end
    {:ok, _} = Application.ensure_all_started(:tzdata, :permanent)
    {:ok, [], {:continue, :exit}}
  end

  @impl true
  def handle_continue(:exit, state) do
    {:stop, :normal, state}
  end

  defp pull_git_repo! do
    {_, 0} = System.cmd("git", ~w[pull origin master],
      cd: @tzdata_wrapper_root,
      stderr_to_stdout: true,
      parallelism: false)
  end

  defp clone_git_repo!(git_repo) do
    {_, 0} = System.cmd("git", ["clone", git_repo, @tzdata_wrapper_root],
      stderr_to_stdout: true,
      parallelism: false)
  end
end
