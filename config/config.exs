import Config

import_config "#{config_env()}.exs"

config :beacon,
  port: 8000,
  sources: [
    {Beacon.Sources.ClaudePlans, Path.expand("~/.claude/plans")},
    {Beacon.Sources.ClaudeTasks, Path.expand("~/.claude/tasks")},
    {Beacon.Sources.CodexSessions, Path.expand("~/.codex/sessions")}
  ]
