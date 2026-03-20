defmodule Beacon.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    html = Beacon.Views.index(Beacon.Store.all())
    send_resp(conn, 200, html)
  end

  get "/plan/:name" do
    case Beacon.Store.get(:plans, name) do
      nil -> send_resp(conn, 404, Beacon.Views.not_found())
      plan -> send_resp(conn, 200, Beacon.Views.plan_detail(name, plan))
    end
  end

  get "/tasks/:uuid" do
    case Beacon.Store.get(:tasks, uuid) do
      nil -> send_resp(conn, 404, Beacon.Views.not_found())
      tasks -> send_resp(conn, 200, Beacon.Views.tasks_detail(uuid, tasks))
    end
  end

  get "/codex/:session_id" do
    case Beacon.Store.get(:codex_sessions, session_id) do
      nil -> send_resp(conn, 404, Beacon.Views.not_found())
      session -> send_resp(conn, 200, Beacon.Views.codex_detail(session_id, session))
    end
  end

  get "/api/data" do
    data = Beacon.Store.all()

    json =
      data
      |> prepare_for_json()
      |> :json.encode()
      |> IO.iodata_to_binary()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  get "/api/raw/:source/:key" do
    source_atom =
      case source do
        "plans" -> :plans
        "tasks" -> :tasks
        "codex_sessions" -> :codex_sessions
        _ -> nil
      end

    case source_atom && Beacon.Store.get(source_atom, key) do
      nil ->
        send_resp(conn, 404, "not found")

      data ->
        raw = Map.get(data, :raw, inspect(data))

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, raw)
    end
  end

  match _ do
    send_resp(conn, 404, Beacon.Views.not_found())
  end

  defp prepare_for_json(data) do
    data
    |> Enum.into(%{}, fn {k, v} ->
      {Atom.to_string(k),
       Enum.into(v, %{}, fn {k2, v2} ->
         {to_string(k2), stringify_map(v2)}
       end)}
    end)
  end

  defp stringify_map(map) when is_map(map) do
    Enum.into(map, %{}, fn
      {k, %DateTime{} = v} -> {to_string(k), DateTime.to_iso8601(v)}
      {k, v} when is_map(v) -> {to_string(k), stringify_map(v)}
      {k, v} when is_list(v) -> {to_string(k), Enum.map(v, &stringify_value/1)}
      {k, v} when is_atom(v) -> {to_string(k), Atom.to_string(v)}
      {k, v} -> {to_string(k), v}
    end)
  end

  defp stringify_map(other), do: other

  defp stringify_value(v) when is_map(v), do: stringify_map(v)
  defp stringify_value(v) when is_atom(v), do: Atom.to_string(v)
  defp stringify_value(%DateTime{} = v), do: DateTime.to_iso8601(v)
  defp stringify_value(v), do: v
end
