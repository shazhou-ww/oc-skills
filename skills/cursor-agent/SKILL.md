---
name: cursor-agent
version: 1.1.0
description: >
  Run Cursor Agent CLI for coding tasks — writing, editing, refactoring, reviewing,
  or planning code — without spending OpenClaw API credits. Supports direct model
  selection (non-China regions). Use when the user asks to write/fix/refactor/review
  code, a coding task would otherwise be done inline with Sonnet/Haiku, the user says
  "do this in cursor" or "use cursor for this", or any substantial file-editing task
  in a known repo. NOT for: conversational questions about code (answer inline) or
  tiny one-liners that don't warrant a subprocess.
metadata:
  requiredBinaries: ["cursor-agent"]
---

# Cursor Agent

Cursor Agent CLI runs on the user's Cursor subscription — zero API cost.
Always prefer it over inline code generation for any non-trivial coding task.

> **China region?** Use the `cursor-agent-cn` skill instead (uses `--model auto`
> to work around server-side model restrictions).

## Prerequisites

**Required binary: `cursor-agent`** (or the alias `agent`)

Install: <https://cursor.com/docs/cli/overview> — verify with `cursor-agent --version`.

## Authentication

```bash
# Option 1: Environment variable
export CURSOR_API_KEY=crsr_xxxxxxxxxxxxxxxx

# Option 2: Browser login (interactive)
cursor-agent login

# Check status
cursor-agent status
```

## Model Selection

Choose the right model for the task:

| Task type | Model | Flag |
|-----------|-------|------|
| Bug fix / feature / refactor | Claude Sonnet 4.6 | `--model sonnet-4.6` |
| Code review / explain | Claude Sonnet 4.6 | `--model sonnet-4.6 --mode=ask` |
| Architecture / design | Claude Opus 4.6 | `--model opus-4.6-thinking --mode=plan` |
| Trivial / exploratory | auto | *(omit `--model`)* |

Default (no `--model` flag) is `auto` — Cursor picks the model. Prefer specifying
a model explicitly for predictable, high-quality output.

## Recommended Workflow

### Step 1 — Read-only review (`ask` mode)

```bash
cursor-agent -p "Review this code for bugs and suggest fixes" \
  --model sonnet-4.6 --mode=ask --output-format text --trust
```

Inspect the output. If the suggestions look good, proceed to step 2.

### Step 2 — Apply changes (`write` mode)

```bash
cursor-agent -p "Fix the bugs identified above" \
  --model sonnet-4.6 --force --output-format text --trust
```

For straightforward tasks where you trust the model, skip step 1 and go straight
to write mode.

## Headless Mode (Recommended for Automation)

Pipe mode (`-p`) is more stable than ACP/interactive mode:

```bash
cursor-agent -p "<task>" --model sonnet-4.6 --output-format text --trust
```

- Runs non-interactively, returns text output
- Best for subagent integration and scripted pipelines
- Avoids the "Connection stalled" issues seen in ACP/interactive mode

## Command Quick Reference

| Scenario | Command |
|----------|---------|
| Code review | `cursor-agent -p "Review..." --model sonnet-4.6 --mode=ask --trust` |
| Write code / fix bug | `cursor-agent -p "Fix..." --model sonnet-4.6 --force --trust` |
| Planning / design | `cursor-agent -p "Plan..." --model opus-4.6-thinking --mode=plan --trust` |
| Quick / trivial | `cursor-agent -p "Do..." --force --trust` |
| Check version | `cursor-agent --version` |
| Update CLI | `cursor-agent update` |
| List available models | `cursor-agent --list-models` |
| List past sessions | `cursor-agent ls` |
| Check auth status | `cursor-agent status` |
| Login (browser) | `cursor-agent login` |

## Helper Script

Use `scripts/run.sh` for standardized invocation:

```bash
# Code review with Sonnet
bash scripts/run.sh /path/to/repo "Review the auth module" sonnet-4.6 ask

# Apply changes with Sonnet
bash scripts/run.sh /path/to/repo "Fix the auth bug" sonnet-4.6 write

# Architecture planning with Opus
bash scripts/run.sh /path/to/repo "Design the new API layer" opus-4.6-thinking plan

# With timeout (seconds)
TIMEOUT=300 bash scripts/run.sh /path/to/repo "Refactor utils" sonnet-4.6 write
```

Arguments: `<repo_path> <task> [model] [mode]`
- `model`: `sonnet-4.6` (recommended) | `opus-4.6-thinking` | `auto` | any available model
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
| Connection stalled | ACP/interactive mode may hang. Use headless `-p` mode instead. |
| Sandbox git block | Cursor sandbox prevents `git commit`. Commit manually after edits. |
| China region | Models like Sonnet/Opus/GPT are blocked. Use `cursor-agent-cn` skill with `--model auto`. |

## Context Tips

- Add `@<file>` in your prompt to include specific files in context
- Use `--continue` or `--resume` to continue a previous session
- Check for `.cursor/rules` and `AGENTS.md` in repo root — Cursor loads these automatically
