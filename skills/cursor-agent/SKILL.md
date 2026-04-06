---
name: cursor-agent
version: 1.2.0
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

## Model Selection by Task Difficulty

Choose the right model based on task complexity and cost sensitivity.
Model names are Cursor-specific — run `cursor-agent --list-models` for the full list.

### 🟢 Simple Tasks (one-file edits, small fixes, formatting, typos)

| Model | Flag | Notes |
|-------|------|-------|
| GPT-5.4 Mini | `--model gpt-5.4-mini-medium` | Fast, cheap, good for trivial changes |
| Gemini 3 Flash | `--model gemini-3-flash` | Fast alternative |
| Claude Sonnet 4 | `--model claude-4-sonnet` | Reliable baseline |

### 🟡 Standard Tasks (bug fixes, features, refactoring, code review)

| Model | Flag | Notes |
|-------|------|-------|
| **Claude Sonnet 4.6** | `--model claude-4.6-sonnet-medium` | **Default pick** — best balance of quality/speed |
| Claude Sonnet 4.6 Thinking | `--model claude-4.6-sonnet-medium-thinking` | Extended reasoning for trickier bugs |
| GPT-5.4 | `--model gpt-5.4-medium` | Strong alternative, 1M context |

### 🔴 Complex Tasks (architecture, multi-file refactoring, design, large codebases)

| Model | Flag | Notes |
|-------|------|-------|
| Claude Opus 4.6 Thinking | `--model claude-4.6-opus-high-thinking` | Best for architecture/design |
| Claude Opus 4.6 | `--model claude-4.6-opus-high` | When thinking is not needed |
| GPT-5.4 High | `--model gpt-5.4-high` | High compute, 1M context |
| GPT-5.3 Codex High | `--model gpt-5.3-codex-high` | Purpose-built for code |

### Quick Decision Guide

```
Trivial / one-liner → gpt-5.4-mini-medium or gemini-3-flash
Standard bug fix / feature → claude-4.6-sonnet-medium (default)
Needs reasoning → claude-4.6-sonnet-medium-thinking
Architecture / design / complex → claude-4.6-opus-high-thinking
Not sure → claude-4.6-sonnet-medium (safe default)
```

## Recommended Workflow

### Step 1 — Read-only review (`ask` mode)

```bash
cursor-agent -p "Review this code for bugs and suggest fixes" \
  --model claude-4.6-sonnet-medium --mode=ask --output-format text --trust
```

Inspect the output. If the suggestions look good, proceed to step 2.

### Step 2 — Apply changes (`write` mode)

```bash
cursor-agent -p "Fix the bugs identified above" \
  --model claude-4.6-sonnet-medium --force --output-format text --trust
```

For straightforward tasks where you trust the model, skip step 1 and go straight
to write mode.

## Headless Mode (Recommended for Automation)

Pipe mode (`-p`) is more stable than ACP/interactive mode:

```bash
cursor-agent -p "<task>" --model claude-4.6-sonnet-medium --output-format text --trust
```

- Runs non-interactively, returns text output
- Best for subagent integration and scripted pipelines
- Avoids the "Connection stalled" issues seen in ACP/interactive mode

## Command Quick Reference

| Scenario | Command |
|----------|---------|
| Code review | `cursor-agent -p "Review..." --model claude-4.6-sonnet-medium --mode=ask --trust` |
| Write code / fix bug | `cursor-agent -p "Fix..." --model claude-4.6-sonnet-medium --force --trust` |
| Planning / design | `cursor-agent -p "Plan..." --model claude-4.6-opus-high-thinking --mode=plan --trust` |
| Quick / trivial | `cursor-agent -p "Do..." --model gpt-5.4-mini-medium --force --trust` |
| Check version | `cursor-agent --version` |
| Update CLI | `cursor-agent update` |
| List available models | `cursor-agent --list-models` |
| List past sessions | `cursor-agent ls` |
| Check auth status | `cursor-agent status` |

## Helper Script

Use `scripts/run.sh` for standardized invocation:

```bash
# Code review with Sonnet 4.6
bash scripts/run.sh /path/to/repo "Review the auth module" claude-4.6-sonnet-medium ask

# Apply changes
bash scripts/run.sh /path/to/repo "Fix the auth bug" claude-4.6-sonnet-medium write

# Architecture planning with Opus
bash scripts/run.sh /path/to/repo "Design the new API layer" claude-4.6-opus-high-thinking plan

# Quick fix with Mini
bash scripts/run.sh /path/to/repo "Fix the typo" gpt-5.4-mini-medium write

# With timeout (seconds)
TIMEOUT=300 bash scripts/run.sh /path/to/repo "Refactor utils" claude-4.6-sonnet-medium write
```

Arguments: `<repo_path> <task> [model] [mode]`
- `model`: `claude-4.6-sonnet-medium` (default) | any model from `--list-models`
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
| China region | Models blocked server-side. Use `cursor-agent-cn` skill with `--model auto`. |

## Context Tips

- Add `@<file>` in your prompt to include specific files in context
- Use `--continue` or `--resume` to continue a previous session
- Check for `.cursor/rules` and `AGENTS.md` in repo root — Cursor loads these automatically
