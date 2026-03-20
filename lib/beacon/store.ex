defmodule Beacon.Store do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{plans: %{}, tasks: %{}, codex_sessions: %{}} end, name: __MODULE__)
  end

  def put(source, key, data) do
    Agent.update(__MODULE__, fn state ->
      put_in(state, [source, key], data)
    end)
  end

  def get(source, key) do
    Agent.get(__MODULE__, fn state ->
      get_in(state, [source, key])
    end)
  end

  def delete(source, key) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [source], &Map.delete(&1, key))
    end)
  end

  def list(source) do
    Agent.get(__MODULE__, fn state ->
      state
      |> Map.get(source, %{})
      |> Enum.sort_by(fn {_k, v} -> Map.get(v, :mtime, ~U[1970-01-01 00:00:00Z]) end, {:desc, DateTime})
      |> Enum.map(fn {k, v} -> Map.put(v, :key, k) end)
    end)
  end

  def all do
    Agent.get(__MODULE__, & &1)
  end
end
