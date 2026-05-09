# Skills Starter

Minimal starter repo for keeping all your reusable agent skills in one canonical place on disk, then symlinking them into Claude, Codex, OpenClaw, or any other agent-specific skills folder.

The point of this repo is simple:

- keep your skills in one repo on disk
- treat that repo as the canonical source of truth
- symlink the skills you want into each agent's own skills directory

This starter repo contains one skill:

- **`promote-skill`**: copy a skill from another local project into this repo, validate a few common portability issues, and optionally append an install snippet to `README.md`.

## Repo Layout

```text
skills-starter/
├── README.md
└── promote-skill/
    ├── SKILL.md
    └── scripts/
        └── promote_skill.sh
```

## Prerequisites

- `git`
- `python3`
- `rg` (`ripgrep`)
- a GitHub repo with `origin` set if you want README install snippets to be generated automatically

## Setup

1. Create your own public repo from this one, or clone it and push it to your GitHub account.
2. Install the starter skill:

```sh
npx skills add https://github.com/matthiasroder/skills-starter/tree/main/promote-skill
```

3. When you are ready, create your own public repo from this one or copy the structure into a repo under your account.

4. Keep that repo somewhere stable on disk, and symlink skills from it into the agent folders you use.

## Use

When you build a new skill somewhere else on disk and want to move it into this repo:

```sh
bash promote-skill/scripts/promote_skill.sh /absolute/path/to/source-skill final-skill-name
```

Useful flags:

```sh
bash promote-skill/scripts/promote_skill.sh --dry-run /absolute/path/to/source-skill final-skill-name
bash promote-skill/scripts/promote_skill.sh --force /absolute/path/to/source-skill final-skill-name
bash promote-skill/scripts/promote_skill.sh --skip-readme /absolute/path/to/source-skill final-skill-name
```

The script:

- validates `SKILL.md` frontmatter
- checks referenced local files like `scripts/...` and `assets/...`
- warns about obvious secrets and machine-specific paths
- copies the skill into this repo
- rewrites the promoted skill's `name:` field to match the final folder name

## Notes

- The destination repo is inferred from the script location, so there are no hardcoded absolute paths.
- README install snippets are generated from `git remote origin` when possible.
- You can override the detected repo URL by setting `SKILLS_REPO_URL`.
- The intended workflow is one canonical skills repo plus symlinks, not copying the same skill into multiple agent-specific folders.
