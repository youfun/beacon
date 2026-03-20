defmodule Beacon.FileWatcher do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    sources = Keyword.get(opts, :sources, Application.get_env(:beacon, :sources, []))

    dirs =
      sources
      |> Enum.map(fn {_mod, dir} -> dir end)
      |> Enum.uniq()
      |> Enum.filter(&File.dir?/1)

    watcher_pid =
      case dirs do
        [] ->
          Logger.warning("No directories to watch")
          nil

        dirs ->
          {:ok, pid} = FileSystem.start_link(dirs: dirs)
          FileSystem.subscribe(pid)
          pid
      end

    # Initial scan
    for {mod, dir} <- sources, File.dir?(dir) do
      scan_dir(mod, dir)
    end

    {:ok, %{sources: sources, watcher_pid: watcher_pid}}
  end

  @impl true
  def handle_info({:file_event, _pid, {path, _events}}, state) do
    handle_file_change(path, state.sources)
    {:noreply, state}
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    Logger.warning("File watcher stopped")
    {:noreply, state}
  end

  defp scan_dir(mod, dir) do
    dir
    |> recursive_ls()
    |> Enum.each(fn path ->
      if mod.match?(path) do
        parse_and_store(mod, path)
      end
    end)
  end

  defp recursive_ls(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.flat_map(fn entry ->
          full = Path.join(dir, entry)

          if File.dir?(full) do
            recursive_ls(full)
          else
            [full]
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp handle_file_change(path, sources) do
    Enum.each(sources, fn {mod, dir} ->
      if String.starts_with?(path, dir) and mod.match?(path) do
        parse_and_store(mod, path)
      end
    end)
  end

  defp parse_and_store(mod, path) do
    case mod.parse(path) do
      {:ok, {key, data}} ->
        source_id = mod.source_id()
        # For tasks, accumulate into a list per uuid
        if source_id == :tasks do
          existing = Beacon.Store.get(:tasks, key)

          if is_map(existing) and not Map.has_key?(existing, :id) do
            # It's a map of tasks, merge
            Beacon.Store.put(:tasks, key, Map.put(existing, data.id, data))
          else
            Beacon.Store.put(:tasks, key, %{data.id => data})
          end
        else
          Beacon.Store.put(source_id, key, data)
        end

      :skip ->
        :ok
    end
  rescue
    e ->
      Logger.warning("Failed to parse #{path}: #{inspect(e)}")
  end
end
