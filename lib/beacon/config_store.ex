defmodule Beacon.ConfigStore do
  @moduledoc """
  GenServer for managing ~/.beacon/config.json
  Handles reading/writing skill directory configurations
  """
  use GenServer
  require Logger

  @config_dir Path.expand("~/.beacon")
  @config_file Path.join(@config_dir, "config.json")
  @default_skill_dir Path.expand("~/.claude/skills")

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def add_skill_dir(path) do
    GenServer.call(__MODULE__, {:add_skill_dir, path})
  end

  def remove_skill_dir(path) do
    GenServer.call(__MODULE__, {:remove_skill_dir, path})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    File.mkdir_p!(@config_dir)
    config = load_config()
    {:ok, config}
  end

  @impl true
  def handle_call(:get, _from, config) do
    {:reply, config, config}
  end

  @impl true
  def handle_call({:add_skill_dir, path}, _from, config) do
    expanded_path = Path.expand(path)
    skill_dirs = config["skill_dirs"] || []

    if expanded_path in skill_dirs do
      {:reply, {:ok, config}, config}
    else
      new_dirs = skill_dirs ++ [expanded_path]
      new_config = Map.put(config, "skill_dirs", new_dirs)
      
      case save_config(new_config) do
        :ok ->
          notify_file_watcher(:add, expanded_path)
          {:reply, {:ok, new_config}, new_config}
        {:error, reason} ->
          {:reply, {:error, reason}, config}
      end
    end
  end

  @impl true
  def handle_call({:remove_skill_dir, path}, _from, config) do
    expanded_path = Path.expand(path)
    skill_dirs = config["skill_dirs"] || []
    new_dirs = List.delete(skill_dirs, expanded_path)
    new_config = Map.put(config, "skill_dirs", new_dirs)

    case save_config(new_config) do
      :ok ->
        notify_file_watcher(:remove, expanded_path)
        {:reply, {:ok, new_config}, new_config}
      {:error, reason} ->
        {:reply, {:error, reason}, config}
    end
  end

  # Private Functions

  defp load_config do
    if File.exists?(@config_file) do
      case File.read(@config_file) do
        {:ok, content} ->
          Jason.decode!(content)
        {:error, reason} ->
          Logger.warning("Failed to read config: #{inspect(reason)}, using defaults")
          default_config()
      end
    else
      config = default_config()
      save_config(config)
      config
    end
  end

  defp default_config do
    skill_dirs = if File.dir?(@default_skill_dir), do: [@default_skill_dir], else: []
    %{"skill_dirs" => skill_dirs}
  end

  defp save_config(config) do
    content = Jason.encode!(config, pretty: true)
    File.write(@config_file, content)
  end

  defp notify_file_watcher(:add, path) do
    if Process.whereis(Beacon.FileWatcher) do
      Beacon.FileWatcher.add_source(Beacon.Sources.Skills, path)
    end
  end

  defp notify_file_watcher(:remove, path) do
    if Process.whereis(Beacon.FileWatcher) do
      Beacon.FileWatcher.remove_source(Beacon.Sources.Skills, path)
    end
  end
end
