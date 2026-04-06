---
name: cursor-agent-cn
version: 1.0.0
description: >
  Run Cursor Agent CLI for coding tasks in China region — writing, editing,
  refactoring, reviewing, or planning code. Uses --model auto to work around
  China-region model restrictions. Use when your machine is in mainland China
  and you need Cursor Agent for coding tasks.
metadata:
  requiredBinaries: ["cursor-agent"]
---

# Cursor Agent (China Region)

Cursor Agent CLI runs on the user's Cursor subscription — zero API cost.
**This is the China-region variant** that uses `--model auto` to work around
server-side model availability restrictions.

For non-China regions (where you can specify models directly), use the
`cursor-agent` skill instead.

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
| Check auth status | `cursor-agent status` |

## Helper Script

Use `scripts/run.sh` for standardized invocation:

```bash
bash scripts/run.sh /path/to/repo "Review the auth module" auto ask
bash scripts/run.sh /path/to/repo "Fix the auth bug" auto write
TIMEOUT=300 bash scripts/run.sh /path/to/repo "Refactor utils" auto write
```

Arguments: `<repo_path> <task> [model] [mode]`
- `model`: `auto` (default) — always use `auto` in China region
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

## Context Tips

- Add `@<file>` in your prompt to include specific files in context
- Use `--continue` or `--resume` to continue a previous session
- Check for `.cursor/rules` and `AGENTS.md` in repo root — Cursor loads these automatically
