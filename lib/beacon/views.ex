defmodule Beacon.Views do
  def index(data) do
    plans = data |> Map.get(:plans, %{}) |> Enum.sort_by(fn {_, v} -> v.mtime end, {:desc, DateTime})
    tasks = data |> Map.get(:tasks, %{}) |> Enum.sort_by(fn {k, _} -> k end)
    sessions = data |> Map.get(:codex_sessions, %{}) |> Enum.sort_by(fn {_, v} -> v.mtime end, {:desc, DateTime})

    layout("Agent Dashboard", """
    <div class="tabs">
      <button class="tab active" onclick="showTab('plans')">Plans (#{length(plans)})</button>
      <button class="tab" onclick="showTab('tasks')">Tasks (#{length(tasks)})</button>
      <button class="tab" onclick="showTab('codex')">Codex (#{length(sessions)})</button>
    </div>

    <div id="tab-plans" class="tab-content active">
      #{render_plans_table(plans)}
    </div>
    <div id="tab-tasks" class="tab-content">
      #{render_tasks_list(tasks)}
    </div>
    <div id="tab-codex" class="tab-content">
      #{render_codex_list(sessions)}
    </div>
    """)
  end

  def plan_detail(name, plan) do
    layout(plan.title, """
    <div class="detail-header">
      <a href="/" class="back">&larr; Back</a>
      <h1>#{escape(plan.title)}</h1>
      <div class="actions">
        <span class="badge">#{plan.tasks_done}/#{plan.tasks_total} (#{plan.pct}%)</span>
        <button onclick="copyRaw('plans', '#{escape(name)}')" class="btn-copy">📋 Copy</button>
      </div>
    </div>
    <div class="markdown-body">
      #{plan.html}
    </div>
    """)
  end

  def tasks_detail(uuid, tasks) do
    task_list =
      tasks
      |> Map.values()
      |> Enum.sort_by(& &1.subject)
      |> Enum.map(&render_task_item/1)
      |> Enum.join("\n")

    layout("Tasks: #{uuid}", """
    <div class="detail-header">
      <a href="/" class="back">&larr; Back</a>
      <h1>Tasks</h1>
      <code class="uuid">#{escape(uuid)}</code>
    </div>
    <div class="task-list">
      #{task_list}
    </div>
    """)
  end

  def codex_detail(session_id, session) do
    meta = session.meta
    messages = session.messages || []

    bubbles =
      messages
      |> Enum.map(&render_message_bubble/1)
      |> Enum.join("\n")

    layout("Codex: #{session_id}", """
    <div class="detail-header">
      <a href="/" class="back">&larr; Back</a>
      <h1>Codex Session</h1>
      <div class="meta-grid">
        <span>ID: <code>#{escape(session_id)}</code></span>
        <span>Model: <code>#{escape(meta.model)}</code></span>
        <span>CWD: <code>#{escape(meta.cwd)}</code></span>
        <span>CLI: <code>#{escape(meta.cli_version)}</code></span>
      </div>
    </div>
    <div class="messages">
      #{bubbles}
    </div>
    """)
  end

  def not_found do
    layout("404 Not Found", "<div class='error'><h1>404 Not Found</h1><a href='/'>← Back</a></div>")
  end

  # ── Private helpers ──────────────────────────────────────────────

  defp render_plans_table([]) do
    "<p class='empty'>No plans found in ~/.claude/plans/</p>"
  end

  defp render_plans_table(plans) do
    rows =
      plans
      |> Enum.map(fn {name, plan} ->
        pct = plan.pct
        bar_color = if pct == 100, do: "var(--green)", else: "var(--accent)"

        """
        <tr>
          <td><a href="/plan/#{url_encode(name)}">#{escape(name)}</a></td>
          <td>#{escape(plan.title)}</td>
          <td>
            <div class="progress-wrap">
              <div class="progress-bar" style="width:#{pct}%;background:#{bar_color}"></div>
            </div>
            <small>#{plan.tasks_done}/#{plan.tasks_total} (#{pct}%)</small>
          </td>
          <td class="mtime">#{format_time(plan.mtime)}</td>
          <td><button onclick="copyRaw('plans', '#{escape(name)}')" class="btn-icon">📋</button></td>
        </tr>
        """
      end)
      |> Enum.join("\n")

    """
    <table class="data-table">
      <thead>
        <tr><th>File</th><th>Title</th><th>Progress</th><th>Modified</th><th></th></tr>
      </thead>
      <tbody>#{rows}</tbody>
    </table>
    """
  end

  defp render_tasks_list([]) do
    "<p class='empty'>No task sessions found in ~/.claude/tasks/</p>"
  end

  defp render_tasks_list(tasks) do
    tasks
    |> Enum.map(fn {uuid, task_map} ->
      task_items =
        task_map
        |> Map.values()
        |> Enum.sort_by(& &1.subject)
        |> Enum.map(&render_task_item/1)
        |> Enum.join("\n")

      """
      <div class="session-group">
        <h3><a href="/tasks/#{url_encode(uuid)}">#{escape(uuid)}</a></h3>
        <div class="task-list">#{task_items}</div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_task_item(task) do
    status_class =
      case task.status do
        "completed" -> "badge-green"
        "in_progress" -> "badge-blue"
        _ -> "badge-gray"
      end

    blockers =
      if task.blocked_by != [] do
        "<small class='blockers'>blocked by: #{Enum.join(task.blocked_by, ", ")}</small>"
      else
        ""
      end

    """
    <div class="task-item">
      <span class="badge #{status_class}">#{escape(task.status)}</span>
      <span class="task-subject">#{escape(task.subject)}</span>
      #{blockers}
    </div>
    """
  end

  defp render_codex_list([]) do
    "<p class='empty'>No Codex sessions found in ~/.codex/sessions/</p>"
  end

  defp render_codex_list(sessions) do
    sessions
    |> Enum.map(fn {id, session} ->
      meta = session.meta
      msg_count = length(session.messages || [])

      """
      <div class="session-row">
        <a href="/codex/#{url_encode(id)}" class="session-id">#{escape(id)}</a>
        <span class="model">#{escape(meta.model)}</span>
        <span class="cwd">#{escape(meta.cwd)}</span>
        <span class="mtime">#{format_time(session.mtime)}</span>
        <span class="msg-count">#{msg_count} msgs</span>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_message_bubble(msg) do
    role = Map.get(msg, :role, "assistant")
    content = Map.get(msg, :content, "")
    bubble_class = if role == "user", do: "bubble-user", else: "bubble-assistant"

    """
    <div class="bubble #{bubble_class}">
      <div class="bubble-role">#{escape(role)}</div>
      <pre class="bubble-content">#{escape(content)}</pre>
    </div>
    """
  end

  defp format_time(nil), do: ""
  defp format_time(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end

  defp escape(nil), do: ""
  defp escape(s) when is_binary(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
  defp escape(other), do: escape(to_string(other))

  defp url_encode(s), do: URI.encode(to_string(s))

  defp layout(title, body) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{escape(title)}</title>
      <style>
        /* ── Design tokens (CreativeStudio light palette) ── */
        :root {
          --bg:          oklch(0.97 0.01 92);
          --surface:     oklch(0.995 0.003 95);
          --surface-2:   oklch(0.982 0.006 90);
          --border:      oklch(0.88 0.01 88);
          --border-mid:  oklch(0.78 0.012 75);
          --text:        oklch(0.24 0.02 58);
          --text-soft:   oklch(0.48 0.015 62);
          --accent:      oklch(0.61 0.16 34);
          --success:     oklch(0.54 0.15 155);
          --danger:      oklch(0.52 0.18 24);
          --warning:     oklch(0.55 0.13 85);
          --info:        oklch(0.5 0.14 242);
          --shadow:      0 8px 32px oklch(0.4 0.01 80 / 0.1);
          --font-mono:   "SFMono-Regular", "JetBrains Mono", "Menlo", "Monaco", monospace;
          --r-sm:        0.5rem;
          --r-md:        0.85rem;
          --r-lg:        1.2rem;
          --transition:  160ms ease;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
          background:
            radial-gradient(circle at top left, oklch(0.985 0.018 80), transparent 28%),
            linear-gradient(180deg, oklch(0.985 0.008 85), var(--bg));
          color: var(--text);
          font-family: var(--font-mono);
          font-size: 13.5px;
          line-height: 1.6;
          padding: 1.25rem 2rem;
          min-height: 100vh;
        }

        h1 {
          font-size: 1.3rem;
          font-weight: 700;
          color: var(--text);
          margin-bottom: .4rem;
          letter-spacing: -.01em;
        }
        h3 {
          font-size: 0.72rem;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: .1em;
          color: var(--text-soft);
          margin: 1rem 0 .5rem;
        }
        a { color: var(--accent); text-decoration: none; transition: opacity var(--transition); }
        a:hover { opacity: 0.8; text-decoration: underline; }
        code {
          background: var(--surface-2);
          padding: .1em .4em;
          border-radius: var(--r-sm);
          font-size: .82em;
          border: 1px solid var(--border);
        }

        /* ── Tabs (studio-nav style adapted) ── */
        .tabs {
          display: flex;
          gap: .35rem;
          margin: 1rem 0;
          border-bottom: 1.5px solid var(--border);
          padding-bottom: .6rem;
        }
        .tab {
          background: none;
          border: 1px solid transparent;
          color: var(--text-soft);
          padding: .4rem .95rem;
          cursor: pointer;
          border-radius: var(--r-md);
          font-family: var(--font-mono);
          font-size: .82rem;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: .06em;
          transition: background var(--transition), color var(--transition), transform var(--transition);
        }
        .tab:hover { background: var(--surface-2); color: var(--text); transform: translateY(-1px); }
        .tab.active {
          background: var(--surface);
          border-color: var(--border-mid);
          color: var(--text);
          box-shadow: 0 1px 4px var(--shadow);
        }
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* ── Tables ── */
        .data-table { width: 100%; border-collapse: collapse; }
        .data-table th {
          font-size: .7rem;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: .1em;
          color: var(--text-soft);
          padding: .5rem .7rem;
          border-bottom: 1.5px solid var(--border-mid);
          text-align: left;
        }
        .data-table td { padding: .5rem .7rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
        .data-table tr:hover td { background: var(--surface-2); }

        /* ── Progress (studio-stat style) ── */
        .progress-wrap {
          background: var(--border);
          border-radius: 999px;
          height: 5px;
          width: 90px;
          display: inline-block;
          vertical-align: middle;
          margin-right: .5rem;
          overflow: hidden;
        }
        .progress-bar { height: 5px; border-radius: 999px; transition: width .4s ease; }

        /* ── Badges (studio-chip style) ── */
        .badge {
          display: inline-flex;
          align-items: center;
          gap: .3rem;
          padding: .2rem .6rem;
          border-radius: 999px;
          font-size: .72rem;
          font-weight: 700;
          letter-spacing: .04em;
          border: 1px solid var(--border-mid);
        }
        .badge-green { background: oklch(0.64 0.15 155 / 0.15); color: var(--success); border-color: oklch(0.64 0.15 155 / 0.25); }
        .badge-blue  { background: oklch(0.65 0.14 242 / 0.15); color: var(--info);    border-color: oklch(0.65 0.14 242 / 0.25); }
        .badge-gray  { background: var(--surface-2);              color: var(--text-soft); }

        /* ── Buttons ── */
        .btn-icon {
          background: none; border: none; cursor: pointer;
          font-size: .95rem; opacity: .6;
          transition: opacity var(--transition), transform var(--transition);
        }
        .btn-icon:hover { opacity: 1; transform: translateY(-1px); }
        .btn-copy {
          display: inline-flex; align-items: center; gap: .4rem;
          background: var(--surface);
          border: 1px solid var(--border-mid);
          color: var(--text);
          padding: .32rem .75rem;
          border-radius: var(--r-md);
          cursor: pointer;
          font-family: var(--font-mono);
          font-size: .78rem;
          font-weight: 600;
          transition: transform var(--transition), background var(--transition), border-color var(--transition);
        }
        .btn-copy:hover { transform: translateY(-1px); background: var(--surface-2); border-color: var(--accent); }

        /* ── Detail header ── */
        .detail-header { margin-bottom: 1.5rem; }
        .back {
          color: var(--text-soft); font-size: .78rem;
          display: inline-flex; align-items: center; gap: .3rem;
          margin-bottom: .6rem;
          transition: color var(--transition);
        }
        .back:hover { color: var(--text); text-decoration: none; opacity: 1; }
        .actions { display: flex; gap: .5rem; align-items: center; margin-top: .6rem; flex-wrap: wrap; }

        /* ── Meta grid (studio-chip row) ── */
        .meta-grid {
          display: flex; flex-wrap: wrap; gap: .5rem;
          margin-top: .75rem;
        }
        .meta-grid span {
          display: inline-flex; align-items: center; gap: .35rem;
          padding: .3rem .65rem;
          border: 1px solid var(--border);
          border-radius: 999px;
          background: var(--surface);
          color: var(--text-soft);
          font-size: .78rem;
        }
        .meta-grid code { background: none; border: none; padding: 0; }

        /* ── Markdown body ── */
        .markdown-body { max-width: 800px; }
        .markdown-body h1, .markdown-body h2, .markdown-body h3 {
          color: var(--text);
          margin: 1.5rem 0 .5rem;
          font-weight: 700;
        }
        .markdown-body h1 { font-size: 1.2rem; }
        .markdown-body h2 { font-size: 1rem; color: var(--text-soft); }
        .markdown-body h3 {
          font-size: .72rem; text-transform: uppercase;
          letter-spacing: .1em; color: var(--text-soft);
        }
        .markdown-body ul, .markdown-body ol { margin-left: 1.5rem; }
        .markdown-body li { margin: .25rem 0; }
        .markdown-body li input[type=checkbox] { margin-right: .4rem; accent-color: var(--accent); }
        .markdown-body pre {
          background: var(--surface);
          border: 1px solid var(--border);
          padding: 1rem;
          border-radius: var(--r-sm);
          overflow-x: auto;
          margin: .75rem 0;
        }
        .markdown-body p { margin: .5rem 0; }
        .markdown-body table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
        .markdown-body th, .markdown-body td {
          border: 1px solid var(--border-mid);
          padding: .4rem .8rem;
        }
        .markdown-body blockquote {
          border-left: 3px solid var(--border-mid);
          margin-left: 0; padding-left: 1rem;
          color: var(--text-soft);
        }

        /* ── Session panel (studio-panel style) ── */
        .session-group {
          margin-bottom: 1rem;
          border: 1px solid var(--border);
          border-radius: var(--r-lg);
          padding: 1rem 1.1rem;
          background: linear-gradient(180deg, var(--surface), var(--surface-2));
          box-shadow: var(--shadow);
          transition: border-color var(--transition);
        }
        .session-group:hover { border-color: var(--border-mid); }
        .task-item {
          display: flex; align-items: center; gap: .5rem;
          padding: .35rem 0;
          border-bottom: 1px solid var(--border);
        }
        .task-item:last-child { border-bottom: none; }
        .task-subject { flex: 1; }
        .blockers { color: var(--danger); font-size: .78rem; }

        /* ── Codex session list ── */
        .session-row {
          display: flex; gap: .8rem; align-items: center;
          padding: .55rem .4rem;
          border-bottom: 1px solid var(--border);
          flex-wrap: wrap;
          transition: background var(--transition);
          border-radius: var(--r-sm);
        }
        .session-row:hover { background: var(--surface-2); }
        .session-id { flex: 0 0 auto; max-width: 280px; overflow: hidden; text-overflow: ellipsis; }
        .model { color: var(--text-soft); font-size: .78rem; }
        .cwd { color: var(--text-soft); font-size: .76rem; flex: 1; overflow: hidden; text-overflow: ellipsis; }
        .msg-count { color: var(--text-soft); font-size: .76rem; }
        .mtime { color: var(--text-soft); font-size: .75rem; }

        /* ── Conversation bubbles ── */
        .messages { max-width: 900px; display: flex; flex-direction: column; gap: .65rem; }
        .bubble {
          padding: .8rem 1rem;
          border-radius: var(--r-md);
          border: 1px solid var(--border);
        }
        .bubble-user {
          background: linear-gradient(135deg, oklch(0.65 0.14 242 / 0.12), oklch(0.65 0.14 242 / 0.06));
          border-left: 2.5px solid var(--info);
          border-color: oklch(0.65 0.14 242 / 0.2);
        }
        .bubble-assistant {
          background: var(--surface);
          border-left: 2.5px solid var(--accent);
          border-color: var(--border);
        }
        .bubble-role {
          font-size: .68rem; color: var(--text-soft); margin-bottom: .3rem;
          text-transform: uppercase; letter-spacing: .1em; font-weight: 700;
        }
        .bubble-content { white-space: pre-wrap; word-break: break-word; font-size: .84rem; line-height: 1.65; }

        /* ── Empty state (studio-empty style) ── */
        .empty {
          padding: 2.5rem 1rem;
          border: 1.5px dashed var(--border-mid);
          border-radius: var(--r-lg);
          text-align: center;
          color: var(--text-soft);
          background: var(--surface);
        }

        .uuid { color: var(--text-soft); font-size: .82rem; }
        .error { color: var(--danger); padding: 2rem; }
      </style>
    </head>
    <body>
      <header style="display:flex;align-items:center;justify-content:space-between;border-bottom:1.5px solid var(--border);padding-bottom:.85rem;margin-bottom:1.25rem;">
        <a href="/" style="color:var(--text);font-size:1rem;font-weight:700;letter-spacing:-.01em;display:flex;align-items:center;gap:.5rem;text-decoration:none;opacity:1;">
          <span style="display:inline-grid;place-items:center;width:1.7rem;height:1.7rem;border-radius:.55rem;background:linear-gradient(135deg,var(--accent),oklch(0.53 0.16 34));color:#fff;font-size:.8rem;">⚡</span>
          Agent Dashboard
        </a>
        <span id="last-updated" style="color:var(--text-soft);font-size:.72rem;text-transform:uppercase;letter-spacing:.08em;"></span>
      </header>
      #{body}
      <script>
        function showTab(name) {
          document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
          document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
          document.getElementById('tab-' + name).classList.add('active');
          event.target.classList.add('active');
        }

        async function copyRaw(source, key) {
          const btn = event.target;
          try {
            const r = await fetch('/api/raw/' + source + '/' + encodeURIComponent(key));
            const text = await r.text();
            if (navigator.clipboard?.writeText) {
              await navigator.clipboard.writeText(text);
            } else {
              const ta = document.createElement('textarea');
              ta.value = text;
              ta.style.cssText = 'position:fixed;opacity:0';
              document.body.appendChild(ta);
              ta.select();
              document.execCommand('copy');
              document.body.removeChild(ta);
            }
            const orig = btn.textContent;
            btn.textContent = '✓ Copied';
            setTimeout(() => { btn.textContent = orig; }, 2000);
          } catch(e) {
            alert('Copy failed: ' + e.message);
          }
        }

        // 10s polling
        function pollData() {
          fetch('/api/data').then(r => r.json()).then(data => {
            document.getElementById('last-updated').textContent =
              'Updated: ' + new Date().toLocaleTimeString();
          }).catch(() => {});
        }
        setInterval(pollData, 10000);
        pollData();
      </script>
    </body>
    </html>
    """
  end
end
