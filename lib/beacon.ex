defmodule Beacon do
  @moduledoc """
  Agent Dashboard — real-time monitoring of Claude Code and Codex work files.
  """

  def parse_args(args) when is_list(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [port: :integer, dir: :string, source: :keep])

    opts
  end
end
