defmodule Beacon.Sources.Source do
  @callback source_id() :: atom()
  @callback match?(path :: String.t()) :: boolean()
  @callback parse(path :: String.t()) :: {:ok, {String.t(), map()}} | :skip
end
