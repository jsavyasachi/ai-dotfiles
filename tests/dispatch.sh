#!/usr/bin/env bash
#
# Unit tests for the deterministic dispatch wrappers. The wrappers own the one
# correct agy/codex invocation and turn "did the delegated run actually happen"
# into an exit code, so a language model driving them can neither hallucinate a
# command nor mistake a silent no-op for success. Tests stub the CLI via
# AGY_BIN / CODEX_BIN so no real model call is made.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# agy stub: `models` prints a two-column catalog; `--print ...` emits one JSON
# object shaped by STUB_MODE (ok | empty | crash).
make_agy_stub() {
  cat > "$1" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "models" ]]; then
  printf 'gemini-3.8-flash-low\tGemini 3.8 Flash (Low)\n'
  printf 'gemini-3.1-pro-high\tGemini 3.1 Pro (High)\n'
  exit 0
fi
case "${STUB_MODE:-ok}" in
  ok)
    printf '%s' '{"conversation_id":"11111111-2222-3333-4444-555555555555","status":"SUCCESS","response":"REAL WORK","duration_seconds":1.0,"num_turns":2}'
    ;;
  empty)
    printf 'a tool required the "write_file" permission and it was auto-denied\n' >&2
    printf '%s' '{"conversation_id":"11111111-2222-3333-4444-555555555555","status":"SUCCESS","response":"","duration_seconds":1.0,"num_turns":1}'
    ;;
  crash)
    printf 'boom\n' >&2
    exit 7
    ;;
esac
exit 0
STUB
  chmod +x "$1"
}

# codex stub: emits JSONL matching the real `codex exec --json` shape, shaped by
# STUB_MODE (ok | crash | nothread).
make_codex_stub() {
  cat > "$1" <<'STUB'
#!/usr/bin/env bash
case "${STUB_MODE:-ok}" in
  ok)
    printf '%s\n' '{"type":"thread.started","thread_id":"01a06fd8-2673-7982-b5bf-2ea5664f464c"}'
    printf '%s\n' '{"type":"turn.started"}'
    printf '%s\n' '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"REAL"}}'
    printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
    ;;
  nothread)
    printf '%s\n' '{"type":"turn.started"}'
    printf '%s\n' '{"type":"turn.completed","usage":{}}'
    ;;
  crash)
    printf 'boom\n' >&2
    exit 7
    ;;
esac
exit 0
STUB
  chmod +x "$1"
}

# ── agy-dispatch.sh ──────────────────────────────────────────────────────────

test_agy_ok() {
  local t out rc
  t="$(mktemp -d /tmp/disp-agy-ok-XXXXXX)"
  make_agy_stub "$t/agy"
  printf 'do the thing\n' > "$t/prompt.md"
  out="$(AGY_BIN="$t/agy" STUB_MODE=ok bash "$REPO_ROOT/scripts/agy-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model gemini-3.8-flash-low --out-dir "$t/run")" || rc=$?
  rc=${rc:-0}
  [[ "$rc" -eq 0 ]] || fail "agy_ok: expected exit 0, got $rc"
  grep -Fq '11111111-2222-3333-4444-555555555555' <<<"$out" || fail "agy_ok: conversation_id not in output"
  rm -rf "$t"
}

test_agy_empty_response_fails() {
  local t rc
  t="$(mktemp -d /tmp/disp-agy-empty-XXXXXX)"
  make_agy_stub "$t/agy"
  printf 'do the thing\n' > "$t/prompt.md"
  set +e
  out="$(AGY_BIN="$t/agy" STUB_MODE=empty bash "$REPO_ROOT/scripts/agy-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model gemini-3.8-flash-low --out-dir "$t/run" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "agy_empty: expected non-zero exit on empty response"
  grep -Fqi 'empty response' <<<"$out" || fail "agy_empty: expected 'empty response' in output, got: $out"
  rm -rf "$t"
}

test_agy_unknown_model_fails() {
  local t rc
  t="$(mktemp -d /tmp/disp-agy-model-XXXXXX)"
  make_agy_stub "$t/agy"
  printf 'x\n' > "$t/prompt.md"
  set +e
  out="$(AGY_BIN="$t/agy" bash "$REPO_ROOT/scripts/agy-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model not-a-real-slug --out-dir "$t/run" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "agy_model: expected non-zero exit on unknown model"
  grep -Fqi 'catalog' <<<"$out" || fail "agy_model: expected 'catalog' in output, got: $out"
  rm -rf "$t"
}

test_agy_crash_fails() {
  local t rc
  t="$(mktemp -d /tmp/disp-agy-crash-XXXXXX)"
  make_agy_stub "$t/agy"
  printf 'x\n' > "$t/prompt.md"
  set +e
  out="$(AGY_BIN="$t/agy" STUB_MODE=crash bash "$REPO_ROOT/scripts/agy-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model gemini-3.8-flash-low --out-dir "$t/run" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "agy_crash: expected non-zero exit when agy exits non-zero"
  rm -rf "$t"
}

test_agy_missing_args_fails() {
  local rc
  set +e
  out="$(bash "$REPO_ROOT/scripts/agy-dispatch.sh" --model gemini-3.8-flash-low 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "agy_args: expected non-zero exit when --prompt-file missing"
}

# ── codex-dispatch.sh ────────────────────────────────────────────────────────

test_codex_ok() {
  local t out rc
  t="$(mktemp -d /tmp/disp-codex-ok-XXXXXX)"
  make_codex_stub "$t/codex"
  printf 'do the thing\n' > "$t/prompt.md"
  out="$(CODEX_BIN="$t/codex" STUB_MODE=ok bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model gpt-5.6-terra --out-dir "$t/run")" || rc=$?
  rc=${rc:-0}
  [[ "$rc" -eq 0 ]] || fail "codex_ok: expected exit 0, got $rc"
  grep -Fq '01a06fd8-2673-7982-b5bf-2ea5664f464c' <<<"$out" || fail "codex_ok: thread_id not in output"
  rm -rf "$t"
}

test_codex_no_thread_fails() {
  local t rc
  t="$(mktemp -d /tmp/disp-codex-nothread-XXXXXX)"
  make_codex_stub "$t/codex"
  printf 'x\n' > "$t/prompt.md"
  set +e
  out="$(CODEX_BIN="$t/codex" STUB_MODE=nothread bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model gpt-5.6-terra --out-dir "$t/run" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "codex_nothread: expected non-zero exit when no thread id emitted"
  grep -Fqi 'thread' <<<"$out" || fail "codex_nothread: expected 'thread' in output, got: $out"
  rm -rf "$t"
}

test_codex_crash_fails() {
  local t rc
  t="$(mktemp -d /tmp/disp-codex-crash-XXXXXX)"
  make_codex_stub "$t/codex"
  printf 'x\n' > "$t/prompt.md"
  set +e
  out="$(CODEX_BIN="$t/codex" STUB_MODE=crash bash "$REPO_ROOT/scripts/codex-dispatch.sh" \
    --prompt-file "$t/prompt.md" --model gpt-5.6-terra --out-dir "$t/run" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "codex_crash: expected non-zero exit when codex exits non-zero"
  rm -rf "$t"
}

test_codex_missing_args_fails() {
  local rc
  set +e
  out="$(bash "$REPO_ROOT/scripts/codex-dispatch.sh" --model gpt-5.6-terra 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "codex_args: expected non-zero exit when --prompt-file missing"
}

main() {
  test_agy_ok
  test_agy_empty_response_fails
  test_agy_unknown_model_fails
  test_agy_crash_fails
  test_agy_missing_args_fails
  test_codex_ok
  test_codex_no_thread_fails
  test_codex_crash_fails
  test_codex_missing_args_fails
  printf 'PASS: dispatch.sh\n'
}

main "$@"
