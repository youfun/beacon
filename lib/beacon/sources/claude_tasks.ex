defmodule Beacon.Sources.ClaudeTasks do
  @behaviour Beacon.Sources.Source

  @impl true
  def source_id, do: :tasks

  @impl true
  def match?(path) do
    String.contains?(path, "/tasks/") and
      String.ends_with?(path, ".json") and
      not String.ends_with?(path, ".lock") and
      not String.contains?(path, ".highwatermark")
  end

  @impl true
  def parse(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- safe_json_decode(content) do
      uuid = path |> Path.dirname() |> Path.basename()
      mtime = file_mtime(path)

      task = %{
        id: Map.get(data, "id", Path.basename(path, ".json")),
        subject: Map.get(data, "subject", ""),
        status: Map.get(data, "status", "pending"),
        description: Map.get(data, "description", ""),
        blocks: Map.get(data, "blocks", []),
        blocked_by: Map.get(data, "blockedBy", []),
        mtime: mtime
      }

      {:ok, {uuid, task}}
    else
      _ -> :skip
    end
  end

  defp safe_json_decode(content) do
    try do
      {:ok, :json.decode(content)}
    rescue
      _ -> :error
    end
  end

  defp file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> DateTime.from_unix!(mtime)
      _ -> DateTime.utc_now()
    end
  end
end
