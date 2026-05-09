#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_ROOT="$(cd "$SKILL_DIR/.." && pwd)"
FORCE=0
DRY_RUN=0
SKIP_README=0
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage:
  promote_skill.sh [--dry-run] [--force] [--skip-readme] SOURCE_SKILL_DIR FINAL_SKILL_NAME

Examples:
  promote_skill.sh /absolute/path/to/my-skill my-skill
  promote_skill.sh --dry-run /absolute/path/to/my-skill my-skill
  promote_skill.sh --force /absolute/path/to/my-skill my-skill
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --skip-readme)
      SKIP_README=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

SOURCE_DIR="$1"
FINAL_NAME="$2"
TARGET_DIR="$CANONICAL_ROOT/$FINAL_NAME"
SOURCE_SKILL_MD="$SOURCE_DIR/SKILL.md"
TARGET_SKILL_MD="$TARGET_DIR/SKILL.md"
README_PATH="$CANONICAL_ROOT/README.md"
HAD_WARNINGS=0

log() {
  printf '%s\n' "$*"
}

warn() {
  HAD_WARNINGS=1
  printf 'WARN: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

detect_repo_url() {
  local remote repo

  if [[ -n "${SKILLS_REPO_URL:-}" ]]; then
    printf '%s\n' "${SKILLS_REPO_URL%/}"
    return 0
  fi

  remote="$(git -C "$CANONICAL_ROOT" config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$remote" ]] || return 1

  case "$remote" in
    git@github.com:*)
      repo="${remote#git@github.com:}"
      repo="${repo%.git}"
      printf 'https://github.com/%s\n' "$repo"
      ;;
    https://github.com/*)
      printf '%s\n' "${remote%.git}"
      ;;
    *)
      return 1
      ;;
  esac
}

validate_inputs() {
  [[ -d "$SOURCE_DIR" ]] || die "Source directory not found: $SOURCE_DIR"
  [[ -f "$SOURCE_SKILL_MD" ]] || die "Source skill is missing SKILL.md: $SOURCE_SKILL_MD"
  [[ -d "$CANONICAL_ROOT" ]] || die "Skills repo not found: $CANONICAL_ROOT"
  [[ "$FINAL_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Final skill name must match ^[a-z0-9][a-z0-9-]*$"
}

validate_frontmatter() {
  local first_line
  first_line="$(sed -n '1p' "$SOURCE_SKILL_MD")"
  [[ "$first_line" == "---" ]] || die "SKILL.md must begin with YAML frontmatter delimited by ---"

  local description_len
  description_len="$(python3 - "$SOURCE_SKILL_MD" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
parts = text.split('---', 2)
if len(parts) < 3:
    print("FRONTMATTER_MISSING")
    raise SystemExit(0)
frontmatter = parts[1]
if not re.search(r'(?m)^name:\s*\S', frontmatter):
    print("NAME_MISSING")
    raise SystemExit(0)
m = re.search(r'(?m)^description:\s*(.+)$', frontmatter)
if not m:
    print("DESCRIPTION_MISSING")
    raise SystemExit(0)
print(len(m.group(1).strip()))
PY
)"

  case "$description_len" in
    FRONTMATTER_MISSING) die "Could not parse SKILL.md frontmatter" ;;
    NAME_MISSING) die "Frontmatter is missing name:" ;;
    DESCRIPTION_MISSING) die "Frontmatter is missing description:" ;;
  esac

  [[ "$description_len" -le 1024 ]] || die "description exceeds 1024 characters ($description_len)"
}

check_local_references() {
  python3 - "$SOURCE_DIR" "$SOURCE_SKILL_MD" <<'PY'
import re, sys
from pathlib import Path

source_dir = Path(sys.argv[1])
skill_md = Path(sys.argv[2])
text = skill_md.read_text(encoding="utf-8")

patterns = [
    r'(?<![A-Za-z0-9_./-])(scripts/[A-Za-z0-9_][A-Za-z0-9_./-]*)',
    r'(?<![A-Za-z0-9_./-])(assets/[A-Za-z0-9_][A-Za-z0-9_./-]*)',
    r'(?<![A-Za-z0-9_./-])(references/[A-Za-z0-9_][A-Za-z0-9_./-]*)',
    r'`(README\.md)`',
]

seen = set()
missing = []
for pattern in patterns:
    for match in re.findall(pattern, text):
        if match in seen:
            continue
        seen.add(match)
        if not (source_dir / match).exists():
            missing.append(match)

for item in missing:
    print(item)
PY
}

check_warnings() {
  local missing_refs
  missing_refs="$(check_local_references)"
  if [[ -n "$missing_refs" ]]; then
    while IFS= read -r ref; do
      [[ -n "$ref" ]] || continue
      warn "Referenced file does not exist: $ref"
    done <<< "$missing_refs"
  fi

  if find "$SOURCE_DIR" \( -name 'credentials.json' -o -name 'token.json' -o -name '.env' -o -name '*.pem' -o -name '*.key' \) | grep -q .; then
    warn "Source skill contains obvious secret-like files; review before committing"
  fi

  if rg -n '/Users/|~/.openclaw|~/.claude|~/.codex|\.openclaw/workspace|\.zshrc|/opt/homebrew' "$SOURCE_SKILL_MD" >/dev/null 2>&1; then
    warn "SKILL.md contains machine-specific or agent-specific paths"
  fi
}

copy_skill() {
  if [[ -e "$TARGET_DIR" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      die "Target already exists: $TARGET_DIR (use --force to replace it)"
    fi
    local backup_path="${TARGET_DIR}.bak.${TIMESTAMP}"
    log "Backing up existing skill: $TARGET_DIR -> $backup_path"
    [[ "$DRY_RUN" -eq 1 ]] || mv "$TARGET_DIR" "$backup_path"
  fi

  log "Copying skill to $TARGET_DIR"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    cp -R "$SOURCE_DIR" "$TARGET_DIR"
  fi
}

rewrite_name_field() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return
  fi
  python3 - "$TARGET_SKILL_MD" "$FINAL_NAME" <<'PY'
import re, sys
from pathlib import Path

path = Path(sys.argv[1])
final_name = sys.argv[2]
text = path.read_text(encoding="utf-8")
new_text, count = re.subn(r'(?m)^name:\s*.+$', f'name: {final_name}', text, count=1)
if count != 1:
    raise SystemExit("Could not rewrite frontmatter name")
path.write_text(new_text, encoding="utf-8")
PY
}

update_readme() {
  [[ "$SKIP_README" -eq 0 ]] || return 0
  [[ -f "$README_PATH" ]] || return 0
  if rg -n "tree/main/${FINAL_NAME}\$" "$README_PATH" >/dev/null 2>&1; then
    log "README already contains ${FINAL_NAME}"
    return 0
  fi

  local description repo_url skill_md_for_metadata
  skill_md_for_metadata="$TARGET_SKILL_MD"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    skill_md_for_metadata="$SOURCE_SKILL_MD"
  fi

  description="$(python3 - "$skill_md_for_metadata" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
frontmatter = text.split('---', 2)[1]
m = re.search(r'(?m)^description:\s*(.+)$', frontmatter)
print(m.group(1).strip())
PY
)"

  repo_url="$(detect_repo_url || true)"
  if [[ -z "$repo_url" ]]; then
    warn "Could not detect a GitHub origin URL; skipping README install snippet"
    return 0
  fi

  log "Appending ${FINAL_NAME} to README.md"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    cat >> "$README_PATH" <<EOF
- **${FINAL_NAME}** — ${description}
  \`\`\`sh
  npx skills add ${repo_url}/tree/main/${FINAL_NAME}
  \`\`\`
EOF
  fi
}

main() {
  require_cmd git
  require_cmd python3
  require_cmd rg
  validate_inputs
  validate_frontmatter
  check_warnings
  copy_skill
  rewrite_name_field
  update_readme

  log ""
  log "Promoted skill: $FINAL_NAME"
  log "Destination path: $TARGET_DIR"
  if [[ "$SKIP_README" -eq 0 ]]; then
    log "README path: $README_PATH"
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry run only: no files were changed"
  fi
  if [[ "$HAD_WARNINGS" -eq 1 ]]; then
    log "Completed with warnings"
  else
    log "Completed without warnings"
  fi
}

main "$@"
