defmodule Beacon.Sources.Skills do
  @moduledoc """
  Source implementation for SKILL.md files
  """
  @behaviour Beacon.Sources.Source

  @impl true
  def source_id, do: :skills

  @impl true
  def match?(path), do: String.ends_with?(path, "/SKILL.md")

  @impl true
  def parse(path) do
    with {:ok, content} <- File.read(path),
         {:ok, stat} <- File.stat(path, time: :posix) do
      {name, description, body} = parse_frontmatter(content)
      skill_name = Path.basename(Path.dirname(path))
      dir = Path.dirname(Path.dirname(path))
      
      data = %{
        name: name || skill_name,
        description: description || "",
        content: body,
        raw: content,
        dir: dir,
        mtime: DateTime.from_unix!(stat.mtime)
      }

      # Use dir_label::skill_name as key for uniqueness
      dir_label = get_dir_label(dir)
      key = "#{dir_label}::#{skill_name}"
      
      {:ok, {key, data}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Functions

  defp parse_frontmatter(content) do
    case String.split(content, "---", parts: 3) do
      ["", frontmatter, body] ->
        {name, description} = extract_frontmatter_fields(frontmatter)
        {name, description, String.trim(body)}
      
      _ ->
        {nil, nil, content}
    end
  end

  defp extract_frontmatter_fields(frontmatter) do
    lines = String.split(frontmatter, "\n")
    
    name = Enum.find_value(lines, fn line ->
      case Regex.run(~r/^name:\s*(.+)$/i, String.trim(line)) do
        [_, value] -> String.trim(value)
        _ -> nil
      end
    end)

    description = Enum.find_value(lines, fn line ->
      case Regex.run(~r/^description:\s*(.+)$/i, String.trim(line)) do
        [_, value] -> String.trim(value)
        _ -> nil
      end
    end)

    {name, description}
  end

  defp get_dir_label(dir) do
    dir
    |> Path.split()
    |> Enum.take(-2)
    |> Enum.join("/")
  end
end
