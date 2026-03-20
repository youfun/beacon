# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Beacon** is an Elixir web app ("Agent Dashboard") that watches local filesystem directories for Claude Code and Codex work files, parses them in real-time, and displays them in a browser UI. It serves as a monitoring tool for AI agent activity.

## Commands

```bash
# Install dependencies
mix deps.get

# Run in development (default port 4000, watches ~/.claude/plans, ~/.claude/tasks, ~/.codex/sessions)
mix run --no-halt

# Run with custom port/dir
mix run --no-halt -- --port 8080 --dir ~/.claude

# Build a self-contained binary (includes the Erlang VM)
./build.sh linux        # -> burrito_out/beacon_linux
./build.sh macos_arm    # -> burrito_out/beacon_macos
./build.sh macos_intel  # -> burrito_out/beacon_macos
./build.sh windows      # -> burrito_out/beacon_windows.exe

# Format code
mix format

# Run tests
mix test
```

The production binary is built via [Burrito](https://github.com/burrito-elixir/burrito) (`mix release beacon`). The default port in config is **8000** (prod), **4000** (dev/test).

## Architecture

The supervision tree (started in `Beacon.Application`) has three children:

1. **`Beacon.Store`** — an `Agent` holding in-memory state: `%{plans: %{}, tasks: %{}, codex_sessions: %{}}`. All data is keyed by filename/UUID within each source namespace.

2. **`Beacon.FileWatcher`** — a `GenServer` that uses `file_system` to watch directories. On start it scans all configured dirs; on file events it re-parses the changed file. Dispatches to source modules via the `Beacon.Sources.Source` behaviour.

3. **`Bandit`** — the HTTP server serving `Beacon.Router` (a `Plug.Router`).

### Source Behaviour

Each source module implements `Beacon.Sources.Source`:
- `source_id/0` — returns the atom key used in `Store` (`:plans`, `:tasks`, `:codex_sessions`)
- `match?/1` — returns true if this source handles the given file path
- `parse/1` — reads and parses the file, returns `{:ok, {key, data_map}}` or `:skip`

Current sources:
| Module | Watches | File type | Store key |
|---|---|---|---|
| `ClaudePlans` | `~/.claude/plans/` | `*.md` | `:plans` |
| `ClaudeTasks` | `~/.claude/tasks/` | `*.json` | `:tasks` (grouped by UUID directory) |
| `CodexSessions` | `~/.codex/sessions/` | `*.jsonl` | `:codex_sessions` |

**Tasks are special**: unlike plans and codex sessions, task files are stored under `~/.claude/tasks/<uuid>/*.json` — multiple JSON files per UUID. `FileWatcher` merges them into `Store` as `%{task_id => task_data}` maps under each UUID key.

### Views

`Beacon.Views` generates all HTML as Elixir strings — no template engine. The CSS design system (`assets/app.css`) defines the "CreativeStudio" palette but it's currently unused by the app; all styles are inlined directly in `Views.layout/2`. The UI auto-polls `/api/data` every 10 seconds.

### Routes

| Route | Description |
|---|---|
| `GET /` | Dashboard index with Plans/Tasks/Codex tabs |
| `GET /plan/:name` | Plan detail with rendered markdown |
| `GET /tasks/:uuid` | Task list for a session UUID |
| `GET /codex/:session_id` | Codex conversation view |
| `GET /api/data` | Full store as JSON |
| `GET /api/raw/:source/:key` | Raw file content for clipboard copy |

### Configuration

Sources and port are configured in `config/config.exs`. The `--dir` CLI flag overrides sources to watch `<dir>/plans` and `<dir>/tasks`. No database — all state is in-memory and rebuilt on restart from the filesystem.

## Adding a New Source

1. Create `lib/beacon/sources/my_source.ex` implementing the `Beacon.Sources.Source` behaviour
2. Add a new key to the `Store`'s initial state in `store.ex`
3. Add the source to the `sources` list in `config/config.exs`
4. Add routes and view functions in `router.ex` and `views.ex`
