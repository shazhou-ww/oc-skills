#!/usr/bin/env bash
# cursor-agent/scripts/run.sh
#
# Standardized wrapper for Cursor Agent CLI.
# Defaults to --model sonnet-4.6 (non-China regions with full model access).
#
# Usage:
#   run.sh <repo_path> <task> [model] [mode]
#
# Arguments:
#   repo_path  — Path to the git repo to work in
#   task       — The prompt / task description
#   model      — sonnet-4.6 (default) | opus-4.6-thinking | auto | ...
#   mode       — ask (default, read-only) | plan (read-only) | write (applies changes)
#
# Environment:
#   TIMEOUT    — Max seconds to wait (optional, default: no limit)
#   CURSOR_API_KEY — API key for authentication (optional if logged in)
#
# Examples:
#   run.sh ./my-repo "Review the auth module"                              # ask mode, sonnet-4.6
#   run.sh ./my-repo "Fix the login bug" sonnet-4.6 write                  # write mode, sonnet
#   run.sh ./my-repo "Design the API" opus-4.6-thinking plan               # plan mode, opus
#   TIMEOUT=300 run.sh ./my-repo "Refactor utils" sonnet-4.6 write         # with 5-min timeout
#
# Notes:
#   - For China region, use cursor-agent-cn skill (defaults to --model auto).
#   - Default mode is 'ask' (read-only). Only use 'write' after reviewing ask output.
#   - Cursor sandbox blocks git commit. Commit manually after write mode.

set -euo pipefail

REPO="${1:?Error: repo path required. Usage: run.sh <repo> <task> [model] [mode]}"
TASK="${2:?Error: task required. Usage: run.sh <repo> <task> [model] [mode]}"
MODEL="${3:-claude-4.6-sonnet-medium}"
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
    ARGS+=(--force)
    ;;
  plan)
    ARGS+=(--mode=plan)
    ;;
  ask|*)
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
