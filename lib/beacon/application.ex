defmodule Beacon.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    args = System.argv() |> Beacon.parse_args()

    port = Keyword.get(args, :port, Application.get_env(:beacon, :port, 4000))

    base_dir = Keyword.get(args, :dir)

    configured_sources = Application.get_env(:beacon, :sources, [])

    sources =
      if base_dir do
        expanded = Path.expand(base_dir)

        [
          {Beacon.Sources.ClaudePlans, Path.join(expanded, "plans")},
          {Beacon.Sources.ClaudeTasks, Path.join(expanded, "tasks")}
        ]
      else
        configured_sources
      end

    Logger.info("Starting Agent Dashboard on port #{port}")
    Logger.info("Watching #{length(sources)} source(s)")

    children = [
      Beacon.Store,
      Beacon.ConfigStore,
      {Beacon.FileWatcher, sources: sources},
      {Bandit, plug: Beacon.Router, port: port},
      {Task, fn -> init_skill_sources() end}
    ]

    opts = [strategy: :one_for_one, name: Beacon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp init_skill_sources do
    Process.sleep(100)  # Wait for ConfigStore to initialize
    config = Beacon.ConfigStore.get()
    skill_dirs = Map.get(config, "skill_dirs", [])
    
    Enum.each(skill_dirs, fn dir ->
      if File.dir?(dir) do
        Beacon.FileWatcher.add_source(Beacon.Sources.Skills, dir)
      end
    end)
  end
end
