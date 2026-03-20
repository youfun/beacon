defmodule Beacon.Sources.ClaudeTasksTest do
  use ExUnit.Case, async: true

  alias Beacon.Sources.ClaudeTasks

  setup do
    dir = System.tmp_dir!() |> Path.join("claude_tasks_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, tmp_dir: dir}
  end

  test "match? accepts tasks/<uuid>/<n>.json" do
    assert ClaudeTasks.match?("/home/user/.claude/tasks/abc-123/1.json")
    assert ClaudeTasks.match?("/tasks/uuid-456/task.json")
  end

  test "match? rejects .lock files" do
    refute ClaudeTasks.match?("/tasks/uuid/file.json.lock")
  end

  test "match? rejects .highwatermark paths" do
    refute ClaudeTasks.match?("/tasks/uuid/.highwatermark")
  end

  test "match? rejects non-json files" do
    refute ClaudeTasks.match?("/tasks/uuid/file.txt")
    refute ClaudeTasks.match?("/plans/uuid/file.json")
  end

  test "parse extracts task fields", %{tmp_dir: dir} do
    uuid = "test-uuid-1234"
    uuid_dir = Path.join(dir, uuid)
    File.mkdir_p!(uuid_dir)
    path = Path.join(uuid_dir, "1.json")

    File.write!(
      path,
      ~s({"id":"task-1","subject":"Do something","status":"pending","description":"Details","blocks":["task-2"],"blockedBy":[]})
    )

    {:ok, {key, task}} = ClaudeTasks.parse(path)
    assert key == uuid
    assert task.id == "task-1"
    assert task.subject == "Do something"
    assert task.status == "pending"
    assert task.description == "Details"
    assert task.blocks == ["task-2"]
    assert task.blocked_by == []
  end

  test "parse groups by uuid directory", %{tmp_dir: dir} do
    uuid = "my-session-uuid"
    uuid_dir = Path.join(dir, uuid)
    File.mkdir_p!(uuid_dir)
    path = Path.join(uuid_dir, "2.json")

    File.write!(
      path,
      ~s({"id":"t2","subject":"Task 2","status":"completed","description":"","blocks":[],"blockedBy":[]})
    )

    {:ok, {key, _task}} = ClaudeTasks.parse(path)
    assert key == uuid
  end

  test "parse returns :skip for invalid JSON", %{tmp_dir: dir} do
    uuid_dir = Path.join([dir, "bad-uuid"])
    File.mkdir_p!(uuid_dir)
    path = Path.join(uuid_dir, "bad.json")
    File.write!(path, "not valid json {{{")

    assert :skip == ClaudeTasks.parse(path)
  end

  test "parse returns :skip for nonexistent file" do
    assert :skip == ClaudeTasks.parse("/tasks/uuid/nonexistent.json")
  end
end
