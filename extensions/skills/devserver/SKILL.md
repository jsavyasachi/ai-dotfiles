---
name: devserver
description: Start, stop, restart, and health-check local development servers (Next.js, Vite, Astro, Bun, Deno, Rails, Django, Flask, Go, Cargo, etc.) without pkill loops. Triggers on "start the dev server", "is the server running", "is localhost up", "restart dev", "kill the server", "the dev server is stuck", "port already in use", "why isn't localhost:NNNN loading", "reload the server", and on EADDRINUSE / "address already in use" errors. Detects the framework from package.json / pyproject.toml / Gemfile / go.mod / Cargo.toml, picks the right start command, checks the port before killing, runs the server in the background, and waits for the URL to return 2xx before reporting ready.
allowed-tools: Bash Read
---

# devserver

Local dev-server lifecycle done right: graceful, observable, and idempotent. No `pkill -9` loops, no "is it up yet" guessing.

## Workflow

1. **Detect intent.** Map the request to one of: `start`, `stop`, `restart`, `status`, `logs`. If ambiguous (e.g. "fix the server"), ask one clarifying question.

2. **Detect the project.** Read repo root for the highest-priority match:

   | Signal | Command (default) |
   |---|---|
   | `package.json` with `scripts.dev` | `npm run dev` (or `pnpm dev` / `bun dev` / `yarn dev` based on lockfile) |
   | `package.json` with `scripts.start` and no `dev` | `npm start` |
   | `bunfig.toml` or `bun.lockb` + entry | `bun --hot <entry>` |
   | `vite.config.*` | `npx vite` |
   | `next.config.*` | `npx next dev` |
   | `astro.config.*` | `npx astro dev` |
   | `pyproject.toml` with `[tool.poetry]` and a `runserver`/`dev` script | `poetry run <script>` |
   | `manage.py` (Django) | `python manage.py runserver` |
   | `app.py` / `wsgi.py` (Flask) | `flask run` |
   | `Gemfile` + `bin/rails` | `bin/rails server` |
   | `go.mod` + `main.go` | `go run .` |
   | `Cargo.toml` + `[[bin]]` | `cargo run` |
   | `Procfile` with a `web:` line | the literal command after `web:` |
   | `mix.exs` | `mix phx.server` |

   If none match, ask the user what command to run. Do not guess.

3. **Detect the port.** In priority order:

   - Explicit user mention ("port 8080").
   - `.env` / `.env.local` PORT variable.
   - Framework default: Next/Vite/Astro = 3000, Bun = 3000, Django = 8000, Flask = 5000, Rails = 3000, Go/Cargo = whatever the code binds (read the source if needed).
   - If still unknown, start the server and parse the URL from its stdout.

4. **Pre-flight the port.** Before starting:

   ```bash
   lsof -nP -iTCP:$PORT -sTCP:LISTEN
   ```

   If occupied:
   - Report PID, command, and start time to the user.
   - If the existing process is *this same project's* dev server (matches the start command), the right move is usually `restart`, not a second instance.
   - **Never SIGKILL on first try.** SIGTERM, wait 3s, re-check, then SIGKILL only if still alive.
   - Ask the user before killing a process that doesn't look like a dev server.

5. **Start in background.** Always use Bash `run_in_background: true` so the dev server doesn't block the agent. Capture the output file path. Example:

   ```bash
   npm run dev
   ```
   with `run_in_background: true`. Note the returned task ID and output path.

6. **Wait for ready.** Poll the URL until it returns 2xx, with a 30s budget:

   ```bash
   for i in $(seq 1 60); do
     curl -sf -o /dev/null -w "%{http_code}" http://localhost:$PORT && echo " ready" && exit 0
     sleep 0.5
   done
   echo "timeout"; exit 1
   ```

   For "tell me when it's ready" requests where the start command itself stays attached, prefer the Monitor tool with an `until grep -q "ready in\|listening on\|Local:" $LOGFILE; do sleep 0.5; done` one-shot - one notification when ready, no polling cost.

7. **Report.** Surface: URL, PID, log path, and one-line "how to stop" hint (`kill $PID` or the task ID for TaskStop).

## Restart

`restart` = `stop` + `start`, with port held until the new process binds. Do not assume the old process released the port - re-run the lsof check before binding.

## Stop

Find the PID via `lsof -nP -iTCP:$PORT -sTCP:LISTEN`. SIGTERM, wait 3s, verify gone, SIGKILL only if needed. Never `pkill -9 node` or `pkill -f dev` - those nuke unrelated processes.

## Status

`lsof -nP -iTCP:$PORT -sTCP:LISTEN` + `curl -sf -o /dev/null -w "%{http_code}" http://localhost:$PORT`. Report both: "listening on PID 12345, responds with 200".

## Logs

Read the background task's output file (returned when the task was started). Use `TaskOutput` for live agents, `Read` for the captured file path.

## Hard rules

- **No `pkill` without a pattern that uniquely matches one process.** Prefer PID from lsof.
- **No `kill -9` as the first move.** SIGTERM first, escalate only after 3s.
- **No silent retries.** If the port is occupied or the health check fails, surface it to the user.
- **No-op gracefully.** If no recognizable dev server config exists, say so and ask - don't invent a command.
- **Do not start a second instance** of the same dev server. If one is running and healthy, report status and stop.
