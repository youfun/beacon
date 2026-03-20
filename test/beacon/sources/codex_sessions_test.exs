defmodule Beacon.Sources.CodexSessionsTest do
  use ExUnit.Case, async: true

  alias Beacon.Sources.CodexSessions

  setup do
    dir = System.tmp_dir!() |> Path.join("codex_sessions_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, tmp_dir: dir}
  end

  test "match? accepts sessions/**/*.jsonl" do
    assert CodexSessions.match?("/home/user/.codex/sessions/2024/01/15/session.jsonl")
    assert CodexSessions.match?("/sessions/abc.jsonl")
  end

  test "match? rejects non-jsonl files" do
    refute CodexSessions.match?("/sessions/file.json")
    refute CodexSessions.match?("/sessions/file.txt")
    refute CodexSessions.match?("/plans/file.jsonl")
  end

  test "parse extracts session_meta", %{tmp_dir: dir} do
    path = Path.join(dir, "session.jsonl")

    lines = [
      ~s({"type":"session_meta","session_id":"sess-abc","cwd":"/home/user/project","model":"gpt-4","cli_version":"1.2.3"}),
      ~s({"type":"event_msg","role":"user","content":"Hello"})
    ]

    File.write!(path, Enum.join(lines, "\n"))

    {:ok, {key, data}} = CodexSessions.parse(path)
    assert key == "sess-abc"
    assert data.meta.id == "sess-abc"
    assert data.meta.cwd == "/home/user/project"
    assert data.meta.model == "gpt-4"
    assert data.meta.cli_version == "1.2.3"
  end

  test "parse extracts user and agent messages", %{tmp_dir: dir} do
    path = Path.join(dir, "msgs.jsonl")

    lines = [
      ~s({"type":"session_meta","session_id":"s1","cwd":"/","model":"m","cli_version":"1"}),
      ~s({"type":"event_msg","role":"user","content":"What is 2+2?"}),
      ~s({"type":"response_item","item":{"role":"assistant","content":[{"type":"text","text":"It is 4."}]}})
    ]

    File.write!(path, Enum.join(lines, "\n"))

    {:ok, {_key, data}} = CodexSessions.parse(path)
    assert length(data.messages) == 2
    user_msg = Enum.find(data.messages, &(&1.role == "user"))
    assert user_msg.content == "What is 2+2?"
    asst_msg = Enum.find(data.messages, &(&1.role == "assistant"))
    assert asst_msg.content == "It is 4."
  end

  test "parse handles empty/malformed lines gracefully", %{tmp_dir: dir} do
    path = Path.join(dir, "malformed.jsonl")

    lines = [
      ~s({"type":"session_meta","session_id":"s2","cwd":"/","model":"","cli_version":""}),
      "",
      "not valid json {{{",
      ~s({"type":"event_msg","role":"user","content":"ok"})
    ]

    File.write!(path, Enum.join(lines, "\n"))

    {:ok, {_key, data}} = CodexSessions.parse(path)
    assert length(data.messages) == 1
  end

  test "parse returns :skip for nonexistent file" do
    assert :skip == CodexSessions.parse("/sessions/nonexistent.jsonl")
  end

  test "parse falls back to filename when no session_id in meta", %{tmp_dir: dir} do
    path = Path.join(dir, "no-id.jsonl")
    File.write!(path, ~s({"type":"session_meta","cwd":"/","model":"","cli_version":""}))

    {:ok, {key, _data}} = CodexSessions.parse(path)
    assert key == "no-id"
  end
end
