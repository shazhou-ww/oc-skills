---
name: cursor-agent
version: 1.0.0
description: >
  Run Cursor Agent CLI for coding tasks — writing, editing, refactoring, reviewing,
  or planning code — without spending OpenClaw API credits. Tested in China region
  with auto model routing. Use when the user asks to write/fix/refactor/review code,
  a coding task would otherwise be done inline with Sonnet/Haiku, the user says
  "do this in cursor" or "use cursor for this", or any substantial file-editing task
  in a known repo. NOT for: conversational questions about code (answer inline) or
  tiny one-liners that don't warrant a subprocess.
metadata:
  requiredBinaries: ["cursor-agent"]
---

# Cursor Agent

Cursor Agent CLI runs on the user's Cursor subscription — zero API cost.
Always prefer it over inline code generation for any non-trivial coding task.

## Prerequisites

**Required binary: `cursor-agent`** (or the alias `agent`)

Install: <https://cursor.com/docs/cli/overview> — verify with `cursor-agent --version`.

The helper script (`scripts/run.sh`) will exit with an error if neither `cursor-agent`
nor `agent` is found in PATH.

## Authentication

```bash
# Option 1: Environment variable
export CURSOR_API_KEY=crsr_xxxxxxxxxxxxxxxx

# Option 2: Browser login (interactive)
cursor-agent login

# Check status
cursor-agent status
```

## ⚠️ China Region: Model Availability

> **Tested & confirmed in WSL (China mainland, April 2026)**

Specifying a model like `--model claude-sonnet-4.6` or `--model gpt-5.4` will fail:

```
Model not available — This model provider doesn't serve your region
```

**Setting HTTP_PROXY / SOCKS5 does NOT help.** Cursor routes model selection on the
server side based on account region, not client IP.

### Solution: `--model auto`

Let Cursor pick whichever model is available in your region:

```bash
cursor-agent -p "your task" --model auto --trust
```

Or simply omit `--model` — the default is `auto`.

> **Trade-off:** `auto` may route to different models across runs, so output quality
> can vary. Use the two-step workflow below to review before applying changes.

## Recommended Workflow: Ask First, Write Second

Because `auto` mode picks an unpredictable model, always review before applying:

### Step 1 — Read-only review (`ask` mode)

```bash
cursor-agent -p "Review this code for bugs and suggest fixes" \
  --model auto --mode=ask --output-format text --trust
```

Inspect the output. If the suggestions look good, proceed to step 2.

### Step 2 — Apply changes (`write` mode)

```bash
cursor-agent -p "Fix the bugs identified above" \
  --model auto --force --output-format text --trust
```

This is the safest approach, especially when you don't control which model runs behind the scenes.

## Headless Mode (Recommended for Automation)

Pipe mode (`-p`) is more stable than ACP/interactive mode:

```bash
cursor-agent -p "<task>" --model auto --mode=ask --output-format text --trust
```

- Runs non-interactively, returns text output
- Best for subagent integration and scripted pipelines
- Avoids the "Connection stalled" issues seen in ACP/interactive mode

## Command Quick Reference

| Scenario | Command |
|----------|---------|
| Code review | `cursor-agent -p "Review..." --model auto --mode=ask --trust` |
| Write code / fix bug | `cursor-agent -p "Fix..." --model auto --force --trust` |
| Planning / design | `cursor-agent -p "Plan..." --model auto --mode=plan --trust` |
| Check version | `cursor-agent --version` |
| Update CLI | `cursor-agent update` |
| List available models | `cursor-agent --list-models` |
| List past sessions | `cursor-agent ls` |
| Check auth status | `cursor-agent status` |
| Login (browser) | `cursor-agent login` |

## Helper Script

Use `scripts/run.sh` for standardized invocation:

```bash
# Read-only review (default)
bash scripts/run.sh /path/to/repo "Review the auth module" auto ask

# Apply changes (after user confirms)
bash scripts/run.sh /path/to/repo "Fix the auth bug" auto write

# Planning mode
bash scripts/run.sh /path/to/repo "Design the new API layer" auto plan

# With timeout (seconds)
TIMEOUT=300 bash scripts/run.sh /path/to/repo "Refactor utils" auto write
```

Arguments: `<repo_path> <task> [model] [mode]`
- `model`: `auto` (default) — or any specific model if available in your region
- `mode`: `ask` (default, read-only) | `plan` | `write` (applies changes)

## Git Rule

Cursor's sandbox blocks `git commit`. After Cursor edits files, commit manually:

```bash
git add -A && git commit -m "feat: description of changes"
```

Always review the diff before committing.

## Known Issues

| Issue | Details |
|-------|---------|
| Region-locked models | Server-side restriction; proxies don't help. Use `--model auto`. |
| Connection stalled | ACP/interactive mode may hang. Use headless `-p` mode instead. |
| Inconsistent output | `auto` may route to different models each run. Review before applying. |
| Sandbox git block | Cursor sandbox prevents `git commit`. Commit manually after edits. |

## Model Routing (Non-China Regions)

If you're in a region with full model access, you can specify models directly:

| Task type | Model flag | Mode flag |
|-----------|------------|-----------|
| Trivial / exploratory | *(omit — `auto`)* | *(omit)* |
| Bug fix / feature / refactor | `--model sonnet-4.6` | *(omit)* |
| Code review / explain | `--model sonnet-4.6` | `--mode=ask` |
| Architecture / design | `--model opus-4.6-thinking` | `--mode=plan` |

## Context Tips

- Add `@<file>` in your prompt to include specific files in context
- Use `--continue` or `--resume` to continue a previous session
- Check for `.cursor/rules` and `AGENTS.md` in repo root — Cursor loads these automatically
