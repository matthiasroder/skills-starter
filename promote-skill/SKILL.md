---
name: promote-skill
description: Promote a project-local skill into this skills repo. Validates SKILL.md frontmatter, description length, file references, obvious secrets, and portability risks before copying the skill and optionally updating README.md.
---

# Promote Skill

Use this when a skill was prototyped in a project folder or another local location and should be moved into this shared skills repo.

## Goal

Promote the skill cleanly so it becomes:

- part of this repo
- safe to share and reuse
- validated for basic loader compatibility

## Workflow

1. Identify the source skill directory.
   - It must contain `SKILL.md`.
   - If the final name differs from the source folder name, decide the final canonical skill name up front.

2. Run the helper script from this skill:

```bash
bash scripts/promote_skill.sh /absolute/path/to/source-skill final-skill-name
```

Useful flags:

```bash
bash scripts/promote_skill.sh --dry-run /absolute/path/to/source-skill final-skill-name
bash scripts/promote_skill.sh --force /absolute/path/to/source-skill final-skill-name
bash scripts/promote_skill.sh --skip-readme /absolute/path/to/source-skill final-skill-name
```

3. Read the script output carefully.
   - `ERROR:` means the promotion must stop until fixed.
   - `WARN:` means the skill was copied, but there is follow-up work.

4. If the skill is accepted, tell the user:
   - destination path inside this repo
   - whether README was updated
   - whether any warnings need cleanup before commit

## What the helper checks

- `SKILL.md` exists
- YAML frontmatter starts at the top of the file
- frontmatter includes `name` and `description`
- `description` length is <= 1024
- referenced local files like `scripts/...`, `assets/...`, the repo README file, and `references/...` exist
- obvious secret files are flagged
- obvious absolute-path and agent-specific references are flagged

## Rules

- Prefer copying from the source into `<this-repo>/<final-name>`.
- Do not silently overwrite an existing skill unless explicitly told to do so.
- Do not commit or push automatically unless the user asks.
- Treat `WARN:` output as something to summarize to the user, not ignore.
