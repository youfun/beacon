defmodule Beacon.Sources.CodexSessions do
  @behaviour Beacon.Sources.Source

  @impl true
  def source_id, do: :codex_sessions

  @impl true
  def match?(path) do
    String.contains?(path, "/sessions/") and String.ends_with?(path, ".jsonl")
  end

  @impl true
  def parse(path) do
    case File.read(path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&safe_json_decode/1)
          |> Enum.reject(&is_nil/1)

        meta = Enum.find(lines, %{}, &(Map.get(&1, "type") == "session_meta"))

        messages =
          lines
          |> Enum.filter(fn item ->
            Map.get(item, "type") in ["response_item", "event_msg", "message"]
          end)
          |> Enum.map(&extract_message/1)
          |> Enum.reject(&is_nil/1)

        session_id =
          Map.get(meta, "session_id") ||
            Map.get(meta, "id") ||
            Path.basename(path, ".jsonl")

        mtime = file_mtime(path)

        data = %{
          meta: %{
            id: session_id,
            cwd: Map.get(meta, "cwd", ""),
            model: Map.get(meta, "model", ""),
            cli_version: Map.get(meta, "cli_version", "")
          },
          messages: messages,
          mtime: mtime
        }

        {:ok, {session_id, data}}

      {:error, _} ->
        :skip
    end
  end

  defp extract_message(%{"type" => "response_item"} = item) do
    inner = Map.get(item, "item", %{})

    %{
      role: Map.get(inner, "role", "assistant"),
      content: extract_content(inner),
      type: "response_item"
    }
  end

  defp extract_message(%{"type" => "event_msg"} = item) do
    %{
      role: Map.get(item, "role", "user"),
      content: Map.get(item, "content", ""),
      type: "event_msg"
    }
  end

  defp extract_message(%{"type" => "message"} = item) do
    %{
      role: Map.get(item, "role", "user"),
      content: Map.get(item, "content", ""),
      type: "message"
    }
  end

  defp extract_message(_), do: nil

  defp extract_content(%{"content" => content}) when is_list(content) do
    content
    |> Enum.map(fn
      %{"type" => "text", "text" => text} -> text
      %{"text" => text} -> text
      _ -> ""
    end)
    |> Enum.join("\n")
  end

  defp extract_content(%{"content" => content}) when is_binary(content), do: content
  defp extract_content(_), do: ""

  defp safe_json_decode(line) do
    try do
      :json.decode(line)
    rescue
      _ -> nil
    end
  end

  defp file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> DateTime.from_unix!(mtime)
      _ -> DateTime.utc_now()
    end
  end
end
