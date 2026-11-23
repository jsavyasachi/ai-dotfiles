#!/usr/bin/env bash
#
# Fan config/mcp-servers.json out to every agent, in each agent's own format.
#
#   sync-mcp.sh merge <opencode|cursor> <manifest>   JSON filter, stdin -> stdout
#   sync-mcp.sh register <manifest>                  Claude, Codex, agy, Pi CLIs
#
# Manifest shape: { "<name>": { "url": "<streamable HTTP URL>" } }. Remote
# servers only; OAuth is done per agent on first use (see AI.md).
#
# File-managed agents (OpenCode, Cursor) get the manifest merged into the
# config setup.sh already renders. CLI-managed agents keep MCP state in files
# this repo does not own (~/.claude.json, ~/.codex/config.toml, agy's
# mcp_config.json, ~/.pi/agent/mcp.json), so each agent's own `mcp add` is the
# writer. Claude and Codex are skipped when the server already exists, so their
# OAuth state and config.toml are not touched on re-runs; agy and Pi `add` are
# add-or-update. Additive only: removing a manifest entry does not deregister it.

set -euo pipefail

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CODEX_BIN="${CODEX_BIN:-codex}"
AGY_BIN="${AGY_BIN:-agy}"
PI_BIN="${PI_BIN:-pi}"

die() { printf 'sync-mcp: %s\n' "$*" >&2; exit 1; }

validate() {
  local manifest="$1"
  [[ -f "$manifest" ]] || die "manifest not found: $manifest"
  jq -e 'type == "object" and all(.[]; (.url | type) == "string" and (.url | test("^https?://")))' \
    "$manifest" >/dev/null || die "invalid manifest (every entry needs an http(s) url): $manifest"
}

merge() {
  local target="$1" manifest="$2"
  validate "$manifest"
  case "$target" in
    opencode)
      # Flat mcp.<name>: OpenCode 1.18 rejects the V2 mcp.servers shape.
      jq --slurpfile m "$manifest" \
        '.mcp = ((.mcp // {}) + ($m[0] | with_entries(.value = {type: "remote", url: .value.url})))'
      ;;
    cursor)
      jq --slurpfile m "$manifest" \
        '.mcpServers = ((.mcpServers // {}) + ($m[0] | with_entries(.value = {url: .value.url})))'
      ;;
    *) die "unknown merge target: $target (expected opencode|cursor)" ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

register() {
  local manifest="$1" name url
  validate "$manifest"
  while IFS=$'\t' read -r name url; do
    if have "$CLAUDE_BIN"; then
      if "$CLAUDE_BIN" mcp get "$name" >/dev/null 2>&1; then
        echo "present claude $name"
      else
        "$CLAUDE_BIN" mcp add --scope user --transport http "$name" "$url" >/dev/null
        echo "added claude $name"
      fi
    else
      echo "skip claude $name (not installed)"
    fi

    if have "$CODEX_BIN"; then
      if "$CODEX_BIN" mcp get "$name" >/dev/null 2>&1; then
        echo "present codex $name"
      else
        "$CODEX_BIN" mcp add "$name" --url "$url" >/dev/null
        echo "added codex $name"
      fi
    else
      echo "skip codex $name (not installed)"
    fi

    if have "$AGY_BIN"; then
      "$AGY_BIN" mcp add --type http "$name" "$url" >/dev/null
      echo "synced agy $name"
    else
      echo "skip agy $name (not installed)"
    fi

    if have "$PI_BIN"; then
      "$PI_BIN" mcp add "$name" --url "$url" >/dev/null
      echo "synced pi $name"
    else
      echo "skip pi $name (not installed)"
    fi
  done < <(jq -r 'to_entries[] | [.key, .value.url] | @tsv' "$manifest")
}

case "${1:-}" in
  merge)    [[ $# -eq 3 ]] || die "usage: sync-mcp.sh merge <opencode|cursor> <manifest>"; merge "$2" "$3" ;;
  register) [[ $# -eq 2 ]] || die "usage: sync-mcp.sh register <manifest>"; register "$2" ;;
  *)        die "usage: sync-mcp.sh <merge|register> ..." ;;
esac
