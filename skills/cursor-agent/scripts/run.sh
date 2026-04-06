#!/usr/bin/env bash
# cursor-agent/scripts/run.sh
#
# Standardized wrapper for Cursor Agent CLI.
# Defaults to --model auto (China-region safe) and read-only ask mode.
#
# Usage:
#   run.sh <repo_path> <task> [model] [mode]
#
# Arguments:
#   repo_path  — Path to the git repo to work in
#   task       — The prompt / task description
#   model      — auto (default) | sonnet-4.6 | opus-4.6-thinking | ...
#   mode       — ask (default, read-only) | plan (read-only) | write (applies changes)
#
# Environment:
#   TIMEOUT    — Max seconds to wait (optional, default: no limit)
#   CURSOR_API_KEY — API key for authentication (optional if logged in)
#
# Examples:
#   run.sh ./my-repo "Review the auth module"                    # ask mode, auto model
#   run.sh ./my-repo "Fix the login bug" auto write              # write mode, auto model
#   TIMEOUT=300 run.sh ./my-repo "Refactor utils" auto write     # with 5-min timeout
#
# Notes:
#   - In China region, always use 'auto' model (default). Specifying Claude/GPT models
#     will fail with "Model not available" — this is a server-side region restriction,
#     not bypassable with HTTP_PROXY/SOCKS5.
#   - Default mode is 'ask' (read-only). Only use 'write' after reviewing ask output.
#   - Cursor sandbox blocks git commit. Commit manually after write mode.

set -euo pipefail

REPO="${1:?Error: repo path required. Usage: run.sh <repo> <task> [model] [mode]}"
TASK="${2:?Error: task required. Usage: run.sh <repo> <task> [model] [mode]}"
MODEL="${3:-auto}"
MODE="${4:-ask}"

# --- Find the CLI binary ---
CURSOR_BIN=""
if command -v cursor-agent &>/dev/null; then
  CURSOR_BIN="cursor-agent"
elif command -v agent &>/dev/null; then
  CURSOR_BIN="agent"
else
  echo "ERROR: Neither 'cursor-agent' nor 'agent' CLI found in PATH." >&2
  echo "Install from: https://cursor.com/docs/cli/overview" >&2
  exit 1
fi

# --- Enter repo ---
cd "$REPO" || { echo "ERROR: Cannot cd to $REPO" >&2; exit 1; }

# --- Build arguments ---
ARGS=(-p "$TASK" --output-format text --trust)

case "$MODE" in
  write)
    # Destructive — applies changes to files.
    ARGS+=(--force)
    ;;
  plan)
    ARGS+=(--mode=plan)
    ;;
  ask|*)
    # Default: read-only, no file changes.
    ARGS+=(--mode=ask)
    ;;
esac

if [ "$MODEL" != "auto" ]; then
  ARGS+=(--model "$MODEL")
fi
# When model is 'auto', omit --model entirely (Cursor defaults to auto).

# --- Execute (with optional timeout) ---
echo ">>> cursor-agent [$MODE] model=$MODEL repo=$REPO"
echo ">>> task: $TASK"
echo "---"

if [ -n "${TIMEOUT:-}" ]; then
  timeout "$TIMEOUT" "$CURSOR_BIN" "${ARGS[@]}"
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo "ERROR: Timed out after ${TIMEOUT}s" >&2
    exit 124
  fi
  exit $EXIT_CODE
else
  exec "$CURSOR_BIN" "${ARGS[@]}"
fi
