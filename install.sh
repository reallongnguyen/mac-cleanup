#!/usr/bin/env bash
# Install the mac-cleanup skill for Claude Code, plus the `mo` (Mole) CLI it uses.
#   - Symlinks skill/ -> ~/.claude/skills/mac-cleanup  (so it stays in sync with the repo)
#   - Installs Mole via Homebrew if missing
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
TARGET="$SKILLS_DIR/mac-cleanup"

command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }

echo "==> Installing Mole (mo) if missing"
if ! command -v mo >/dev/null; then
  brew install tw93/tap/mole
else
  echo "  mo already installed: $(mo --version 2>/dev/null | head -1)"
fi

echo "==> Linking skill -> $TARGET"
mkdir -p "$SKILLS_DIR"
if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  echo "  $TARGET exists and is not a symlink — backing up to $TARGET.bak"
  mv "$TARGET" "$TARGET.bak"
fi
ln -sfn "$REPO_DIR/skill" "$TARGET"
chmod +x "$REPO_DIR/skill/scripts/"*.sh 2>/dev/null || true

cat <<EOF

Done. The mac-cleanup skill is linked at:
  $TARGET -> $REPO_DIR/skill

Try it in Claude Code:
  "my mac is almost out of disk space, help me clean it up"

Or run the read-only scan yourself:
  bash "$REPO_DIR/skill/scripts/scan.sh"
EOF
