---
name: coding-workflow
version: 1.0.0
description: >
  Standard coding workflow for all squads. Enforces: Issue-driven development,
  coordinator never writes code, Cursor Agent as primary coding tool, Git branch
  conventions, build verification, and deployment procedures. Load this skill
  when doing any code development work to ensure consistent practices across
  NEKO / KUMA / RAKU / SORA squads.
metadata:
  requiredBinaries: ["cursor-agent", "gh"]
---

# Coding Workflow

Standard development workflow for all squads. **This is not a suggestion — follow it.**

## Core Principles

1. **Issue first** — Every change has a GitHub Issue
2. **Coordinator never codes** — Spawn subagent or use Cursor Agent
3. **Cursor Agent is the primary coding tool** — Zero API cost
4. **Build before deploy** — `npm run build` must pass
5. **Track everything** — Issue updated with fix info, commit links to Issue

## Flow

```
Need/Bug → Open Issue → Analyze & plan → Spawn subagent or Cursor → 
Verify (build + diff) → Commit (closes #N) → Merge to main → Deploy → 
Update Issue with fix info
```

## Step 1: Open Issue

Before writing any code, ensure there's an Issue.

```bash
gh issue create --title "Bug: description" --body "## Problem\n...\n## Fix\n...\n## Acceptance\n..."
```

If an Issue already exists, add your analysis as a comment:

```bash
gh issue comment <N> --body "## Analysis\n..."
```

## Step 2: Create Branch

```bash
git checkout main && git pull
git checkout -b fix/descriptive-name    # for fixes
git checkout -b feat/descriptive-name   # for features
```

## Step 3: Write Code with Cursor Agent

**Never write code as the coordinator.** Use Cursor Agent CLI.

### Choose model by task difficulty

| Difficulty | Model | When to use |
|------------|-------|-------------|
| 🟢 Simple | `gpt-5.4-mini-medium` | One-line fix, typo, formatting |
| 🟡 Standard | `claude-4.6-sonnet-medium` | Bug fix, feature, refactor, review |
| 🔴 Complex | `claude-4.6-opus-high-thinking` | Architecture, multi-file refactor, design |

> **China region?** Use `--model auto` instead (see `cursor-agent-cn` skill).

### Two-step workflow (recommended)

```bash
# Step A: Review first (read-only, no file changes)
cursor-agent -p "<task description>" \
  --model claude-4.6-sonnet-medium --mode=ask --output-format text --trust

# Step B: Apply changes (after reviewing the plan)
cursor-agent -p "<task description>" \
  --model claude-4.6-sonnet-medium --force --output-format text --trust
```

For straightforward tasks with a clear plan, skip Step A and go directly to `--force`.

### Alternative: Spawn subagent

For tasks that need multiple steps or file reads before coding:

```
sessions_spawn with:
- Clear task description
- Acceptance criteria
- Which files to modify
- What NOT to change
```

## Step 4: Verify

**Every change must pass these checks before commit:**

1. **Build passes:**
   ```bash
   npm run build  # or the project's build command
   ```

2. **Diff is clean:**
   ```bash
   git diff --stat           # check scope
   git diff <file>           # review actual changes
   ```

3. **No unintended changes** — only the files you meant to modify

## Step 5: Commit & Merge

```bash
# Commit (Cursor sandbox blocks git, so always commit manually)
git add -A
git commit -m "fix: description of change (closes #N)"

# Merge to main
git checkout main
git merge <branch> --no-ff -m "fix: description (closes #N)"
git push origin main
```

### Commit message format

```
type: short description (closes #N)
```

Types: `feat:` `fix:` `docs:` `refactor:` `chore:`

## Step 6: Deploy

```bash
# For Cloudflare Workers (Uncaged)
export CLOUDFLARE_API_TOKEN=$(secret get CLOUDFLARE_API_TOKEN | head -1 | tr -d '\n')
npx wrangler deploy --config packages/worker/wrangler.toml
```

Verify the deployment version ID and test in browser/Telegram.

## Step 7: Update Issue

If commit message has `closes #N`, the Issue auto-closes on push.
Add a comment with fix details:

```bash
gh issue comment <N> --body "## Fixed ✅\nCommit: <hash>\nDeploy: <version>\n\n— 署名"
```

## PR Review (Cross-Squad)

When reviewing PRs from other squads:

```bash
# Review and approve
gh pr review <N> --approve --body "LGTM ✅ reason"

# Or request changes
gh pr review <N> --request-changes --body "Need to fix: ..."

# Merge (squash preferred)
gh pr merge <N> --squash --delete-branch -t "type: description (#N)"
```

## Anti-Patterns ❌

| Don't | Do instead |
|-------|------------|
| Coordinator writes code | Spawn subagent or Cursor Agent |
| Skip Issue, just code | Open Issue first, even for small fixes |
| Deploy without build | Always `npm run build` before deploy |
| Huge PR with many changes | One Issue = one branch = one focused change |
| Forget to update Issue | Use `closes #N` in commit, add fix comment |
| Push without verifying | Check diff, build, then push |
