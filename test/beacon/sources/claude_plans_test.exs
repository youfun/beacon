defmodule Beacon.Sources.ClaudePlansTest do
  use ExUnit.Case, async: true

  alias Beacon.Sources.ClaudePlans

  setup do
    dir = System.tmp_dir!() |> Path.join("claude_plans_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, tmp_dir: dir}
  end

  test "match? accepts plans/*.md paths" do
    assert ClaudePlans.match?("/home/user/.claude/plans/my_plan.md")
    assert ClaudePlans.match?("/some/plans/another.md")
  end

  test "match? rejects other paths" do
    refute ClaudePlans.match?("/home/user/.claude/tasks/some.json")
    refute ClaudePlans.match?("/home/user/plans/file.txt")
    refute ClaudePlans.match?("/home/user/plans/file.json")
  end

  test "parse extracts title from # heading", %{tmp_dir: dir} do
    path = Path.join(dir, "test_plan.md")
    File.write!(path, "# My Great Plan\n\n- [ ] Task 1\n- [x] Task 2\n")

    {:ok, {key, data}} = ClaudePlans.parse(path)
    assert key == "test_plan.md"
    assert data.title == "My Great Plan"
  end

  test "parse falls back to filename when no # heading", %{tmp_dir: dir} do
    path = Path.join(dir, "fallback.md")
    File.write!(path, "Some content without heading\n")

    {:ok, {_key, data}} = ClaudePlans.parse(path)
    assert data.title == "fallback"
  end

  test "parse counts checkboxes total and done", %{tmp_dir: dir} do
    path = Path.join(dir, "tasks.md")
    File.write!(path, "# Plan\n\n- [ ] pending 1\n- [ ] pending 2\n- [x] done 1\n")

    {:ok, {_key, data}} = ClaudePlans.parse(path)
    assert data.tasks_total == 3
    assert data.tasks_done == 1
  end

  test "parse calculates percentage", %{tmp_dir: dir} do
    path = Path.join(dir, "pct.md")
    File.write!(path, "# Plan\n\n- [x] done\n- [x] done\n- [ ] pending\n- [ ] pending\n")

    {:ok, {_key, data}} = ClaudePlans.parse(path)
    assert data.pct == 50
  end

  test "parse returns 0% when no checkboxes", %{tmp_dir: dir} do
    path = Path.join(dir, "empty.md")
    File.write!(path, "# Empty Plan\n\nNo tasks here.\n")

    {:ok, {_key, data}} = ClaudePlans.parse(path)
    assert data.pct == 0
    assert data.tasks_total == 0
  end

  test "parse returns rendered HTML via earmark", %{tmp_dir: dir} do
    path = Path.join(dir, "html.md")
    File.write!(path, "# Title\n\nSome **bold** text.\n")

    {:ok, {_key, data}} = ClaudePlans.parse(path)
    assert String.contains?(data.html, "<strong>bold</strong>")
  end

  test "parse returns raw content", %{tmp_dir: dir} do
    content = "# Raw\n\n- [ ] task\n"
    path = Path.join(dir, "raw.md")
    File.write!(path, content)

    {:ok, {_key, data}} = ClaudePlans.parse(path)
    assert data.raw == content
  end

  test "parse returns :skip for nonexistent file" do
    assert :skip == ClaudePlans.parse("/nonexistent/plans/file.md")
  end
end
