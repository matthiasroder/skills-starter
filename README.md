# Skills Starter

Minimal starter repo for people who want a public home for their own agent skills.

This repo contains one skill:

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
2. Install the skill from your repo:

```sh
npx skills add https://github.com/<your-user>/<your-repo>/tree/main/promote-skill
```

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
