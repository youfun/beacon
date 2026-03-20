defmodule Beacon.Sources.ClaudePlans do
  @behaviour Beacon.Sources.Source

  @impl true
  def source_id, do: :plans

  @impl true
  def match?(path) do
    String.contains?(path, "/plans/") and String.ends_with?(path, ".md")
  end

  @impl true
  def parse(path) do
    case File.read(path) do
      {:ok, content} ->
        title = extract_title(content, path)
        {total, done} = count_checkboxes(content)
        pct = if total > 0, do: round(done / total * 100), else: 0
        html =
          case Earmark.as_html(content) do
            {:ok, h, _} -> h
            {:error, h, _} -> h
          end
        mtime = file_mtime(path)

        data = %{
          title: title,
          tasks_total: total,
          tasks_done: done,
          pct: pct,
          mtime: mtime,
          raw: content,
          html: html
        }

        {:ok, {Path.basename(path), data}}

      {:error, _} ->
        :skip
    end
  end

  defp extract_title(content, path) do
    content
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      case Regex.run(~r/^#\s+(.+)/, line) do
        [_, title] -> String.trim(title)
        nil -> nil
      end
    end)
    |> case do
      nil -> Path.basename(path, ".md")
      title -> title
    end
  end

  defp count_checkboxes(content) do
    lines = String.split(content, "\n")
    total = Enum.count(lines, &Regex.match?(~r/- \[[ x]\]/, &1))
    done = Enum.count(lines, &Regex.match?(~r/- \[x\]/, &1))
    {total, done}
  end

  defp file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> DateTime.from_unix!(mtime)
      _ -> DateTime.utc_now()
    end
  end
end
