defmodule Beacon.StoreTest do
  use ExUnit.Case, async: false

  setup do
    # Restart store for each test
    case Process.whereis(Beacon.Store) do
      nil -> {:ok, _} = Beacon.Store.start_link([])
      pid -> Agent.update(pid, fn _ -> %{plans: %{}, tasks: %{}, codex_sessions: %{}} end)
    end

    :ok
  end

  test "put and get" do
    Beacon.Store.put(:plans, "a.md", %{title: "Test Plan", mtime: DateTime.utc_now()})
    result = Beacon.Store.get(:plans, "a.md")
    assert result.title == "Test Plan"
  end

  test "get nonexistent returns nil" do
    assert Beacon.Store.get(:plans, "nonexistent.md") == nil
  end

  test "list returns entries sorted by mtime desc" do
    old = ~U[2024-01-01 00:00:00Z]
    new = ~U[2024-06-01 00:00:00Z]

    Beacon.Store.put(:plans, "old.md", %{title: "Old", mtime: old})
    Beacon.Store.put(:plans, "new.md", %{title: "New", mtime: new})

    list = Beacon.Store.list(:plans)
    assert length(list) == 2
    assert hd(list).title == "New"
  end

  test "delete removes entry" do
    Beacon.Store.put(:plans, "del.md", %{title: "Delete me", mtime: DateTime.utc_now()})
    assert Beacon.Store.get(:plans, "del.md") != nil
    Beacon.Store.delete(:plans, "del.md")
    assert Beacon.Store.get(:plans, "del.md") == nil
  end

  test "all returns full state" do
    Beacon.Store.put(:plans, "x.md", %{title: "X", mtime: DateTime.utc_now()})
    all = Beacon.Store.all()
    assert Map.has_key?(all, :plans)
    assert Map.has_key?(all, :tasks)
    assert Map.has_key?(all, :codex_sessions)
    assert Map.get(all.plans, "x.md").title == "X"
  end
end
