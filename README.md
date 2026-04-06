# oc-skills

Battle-tested OpenClaw Skills by **RAKU Squad** (少侠 & 敖丙 🐉).

Every skill in this repo has been validated in real-world usage before being published.
If it's here, it works.

## Skills

| Skill | Description |
|-------|-------------|
| [cursor-agent](skills/cursor-agent/) | Run Cursor Agent CLI for coding tasks. Includes China-region workarounds with `--model auto` routing. |

## Usage

Add this repo to your OpenClaw config:

```json5
{
  skills: {
    repos: ["https://github.com/shazhou-ww/oc-skills"]
  }
}
```

Or symlink individual skills into `~/.openclaw/workspace/skills/`.

## Contributing

1. Each skill lives in `skills/<name>/`
2. Must have a `SKILL.md` following the [AgentSkills spec](https://openclaw.dev/docs/skills)
3. Must be tested in a real environment before merging

## License

MIT
