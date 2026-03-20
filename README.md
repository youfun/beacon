# Beacon

A lightweight agent dashboard that watches your local Claude Code and Codex work files in real-time and displays them in a browser UI.

## What it monitors

- **Plans** — markdown plan files from `~/.claude/plans/`, with checkbox progress tracking
- **Tasks** — task JSON files from `~/.claude/tasks/`, grouped by session UUID
- **Codex sessions** — conversation logs from `~/.codex/sessions/`

## Usage

Download the binary for your platform from [Releases](https://github.com/youfun/beacon/releases) and run it:

```bash
# Default: watches ~/.claude and ~/.codex, serves on port 8000
./beacon_linux

# Custom port and directory
./beacon_linux --port 8080 --dir ~/.claude
```

Then open http://localhost:8000 in your browser.

## Build from source

Requires Elixir 1.17+ and OTP 27+.

```bash
mix deps.get
mix run --no-halt
```

To build a self-contained binary (no Elixir/Erlang needed on target machine):

```bash
./build.sh linux        # beacon_linux
./build.sh macos_arm    # beacon_macos
./build.sh windows      # beacon_windows.exe
```
