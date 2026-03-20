defmodule Beacon.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test

  setup do
    case Process.whereis(Beacon.Store) do
      nil -> {:ok, _} = Beacon.Store.start_link([])
      pid -> Agent.update(pid, fn _ -> %{plans: %{}, tasks: %{}, codex_sessions: %{}} end)
    end

    :ok
  end

  test "GET / returns 200 with HTML" do
    conn = conn(:get, "/") |> Beacon.Router.call([])
    assert conn.status == 200
    assert String.contains?(conn.resp_body, "Agent Dashboard")
  end

  test "GET /plan/:name returns rendered markdown" do
    Beacon.Store.put(:plans, "myplan.md", %{
      title: "My Plan",
      tasks_total: 2,
      tasks_done: 1,
      pct: 50,
      mtime: DateTime.utc_now(),
      raw: "# My Plan\n\n- [x] done\n- [ ] pending\n",
      html: "<h1>My Plan</h1><ul><li>done</li></ul>"
    })

    conn = conn(:get, "/plan/myplan.md") |> Beacon.Router.call([])
    assert conn.status == 200
    assert String.contains?(conn.resp_body, "My Plan")
  end

  test "GET /plan/:name returns 404 for unknown plan" do
    conn = conn(:get, "/plan/unknown.md") |> Beacon.Router.call([])
    assert conn.status == 404
  end

  test "GET /tasks/:uuid returns task list HTML" do
    Beacon.Store.put(:tasks, "uuid-123", %{
      "task-1" => %{
        id: "task-1",
        subject: "Do something",
        status: "pending",
        description: "",
        blocks: [],
        blocked_by: [],
        mtime: DateTime.utc_now()
      }
    })

    conn = conn(:get, "/tasks/uuid-123") |> Beacon.Router.call([])
    assert conn.status == 200
    assert String.contains?(conn.resp_body, "Do something")
  end

  test "GET /tasks/:uuid returns 404 for unknown uuid" do
    conn = conn(:get, "/tasks/nonexistent") |> Beacon.Router.call([])
    assert conn.status == 404
  end

  test "GET /codex/:id returns session HTML" do
    Beacon.Store.put(:codex_sessions, "sess-xyz", %{
      meta: %{id: "sess-xyz", cwd: "/home/user", model: "gpt-4", cli_version: "1.0"},
      messages: [%{role: "user", content: "Hello", type: "event_msg"}],
      mtime: DateTime.utc_now()
    })

    conn = conn(:get, "/codex/sess-xyz") |> Beacon.Router.call([])
    assert conn.status == 200
    assert String.contains?(conn.resp_body, "sess-xyz")
  end

  test "GET /codex/:id returns 404 for unknown session" do
    conn = conn(:get, "/codex/nonexistent") |> Beacon.Router.call([])
    assert conn.status == 404
  end

  test "GET /api/data returns JSON with all sources" do
    Beacon.Store.put(:plans, "p.md", %{title: "P", tasks_total: 0, tasks_done: 0, pct: 0, mtime: DateTime.utc_now(), raw: "", html: ""})

    conn = conn(:get, "/api/data") |> Beacon.Router.call([])
    assert conn.status == 200
    assert conn.resp_headers |> Enum.any?(fn {k, v} -> k == "content-type" and String.contains?(v, "application/json") end)
    body = :json.decode(conn.resp_body)
    assert Map.has_key?(body, "plans")
  end

  test "GET /api/raw/plans/:name returns raw content" do
    Beacon.Store.put(:plans, "rawplan.md", %{
      title: "Raw",
      tasks_total: 0,
      tasks_done: 0,
      pct: 0,
      mtime: DateTime.utc_now(),
      raw: "# Raw content here",
      html: ""
    })

    conn = conn(:get, "/api/raw/plans/rawplan.md") |> Beacon.Router.call([])
    assert conn.status == 200
    assert conn.resp_body == "# Raw content here"
  end

  test "GET /unknown returns 404" do
    conn = conn(:get, "/totally/unknown/path") |> Beacon.Router.call([])
    assert conn.status == 404
  end
end
