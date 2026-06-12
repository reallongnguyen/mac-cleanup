# mac-cleanup

**Free up disk space on your Mac — without deleting anything you can't get back.**

Run out of disk on your Mac? This **Claude Code skill** finds what's *actually*
eating your storage (spoiler: rarely the OS), frees it with the
[`mo` (Mole)](https://github.com/tw93/Mole) CLI, and never deletes anything
irreplaceable — git history, databases, Docker volumes — without asking first.

The core idea: sort every large thing into **safe** (regenerable — caches,
build artifacts, downloaded models) or **real data** (exists nowhere else —
delete only with confirmation). Most "Mac cleaners" skip that distinction. This
one is built around it.

## Install it with your coding agent

Paste this into **Claude Code**:

```text
Set up the mac-cleanup skill from https://github.com/reallongnguyen/mac-cleanup — follow its README.
```

The agent reads this README and follows the setup instructions below — installing `mo` via Homebrew and linking the skill into `~/.claude/skills/`.

### Claude Code: setup instructions

If you are Claude Code reading this README to set up the skill, follow these steps exactly:

1. **Install `mo`** — check if it's already installed first:
   ```sh
   command -v mo && mo --version || brew install mole
   ```
2. **Clone the repo** (skip if already cloned):
   ```sh
   git clone https://github.com/reallongnguyen/mac-cleanup.git ~/mac-cleanup
   ```
3. **Link the skill**:
   ```sh
   mkdir -p ~/.claude/skills
   ln -sfn ~/mac-cleanup/skill ~/.claude/skills/mac-cleanup
   chmod +x ~/mac-cleanup/skill/scripts/*.sh
   ```
4. **Verify**:
   ```sh
   mo --version && ls ~/.claude/skills/mac-cleanup
   ```

That's it — the skill is active. Tell the user they can now say things like _"my disk is almost full, help me clean it up"_ in Claude Code.

## Prefer to run it yourself?

```sh
git clone https://github.com/reallongnguyen/mac-cleanup.git ~/mac-cleanup
command -v mo || brew install mole
mkdir -p ~/.claude/skills
ln -sfn ~/mac-cleanup/skill ~/.claude/skills/mac-cleanup
chmod +x ~/mac-cleanup/skill/scripts/*.sh
```

This installs Mole (if missing) and symlinks `skill/` to
`~/.claude/skills/mac-cleanup`, so the skill stays in sync with the repo.

## Use it

Just describe the problem in Claude Code — the skill triggers on intent, no
command needed:

```text
my disk is almost full, what's eating all my storage?
```
```text
why is "System Data" 180GB on my mac? clean it up
```

Or run the read-only scan yourself anytime (deletes nothing):

```sh
bash skill/scripts/scan.sh
```

## What it does

1. **Assess** — `df`, `mo --version`, and a read-only `scan.sh` report of the
   biggest consumers.
2. **Explain "System Data"** — it's almost never the OS; it's caches, Docker,
   dev toolchains, and your own source code, miscategorized.
3. **Quick safe wins** — `mo clean --dry-run` then `mo clean` (whitelisted
   user-level caches).
4. **Deep dive** — the known macOS space sinks: aerial wallpaper videos (the #1
   phantom-storage bug), Docker images, ML model caches, Xcode junk, unused
   toolchains.
5. **Workspace** — clears regenerable `node_modules` / build dirs, compacts git
   with `git gc` (never deletes `.git`).
6. **Confirm before real data** — git history, Docker volumes, and databases are
   never auto-deleted.
7. **Report** — honest before/after `df` numbers and what was left, and why.

## Uninstall

### With your coding agent

Paste this into **Claude Code**:

```text
Uninstall the mac-cleanup skill — follow its README uninstall instructions.
```

### Claude Code: uninstall instructions

If you are Claude Code reading this README to uninstall the skill, follow these steps exactly:

1. **Remove the skill symlink**:
   ```sh
   rm -f ~/.claude/skills/mac-cleanup
   ```
2. **Delete the cloned repo**:
   ```sh
   rm -rf ~/mac-cleanup
   ```
3. **Optionally uninstall `mo`** (skip if you use it for other things):
   ```sh
   brew uninstall mole
   ```
4. **Verify**:
   ```sh
   ls ~/.claude/skills/mac-cleanup 2>/dev/null && echo "still present" || echo "removed"
   ```

Tell the user the skill has been removed and Claude Code will no longer trigger mac-cleanup behavior.

### Prefer to run it yourself?

```sh
rm -f ~/.claude/skills/mac-cleanup
rm -rf ~/mac-cleanup
# optionally: brew uninstall mole
```

---

## What's in the repo

| Path | Purpose |
|------|---------|
| `skill/SKILL.md` | The skill: methodology, `mo` usage, safe/real-data guardrails. |
| `skill/scripts/scan.sh` | Read-only disk report — top consumers + known macOS space sinks. Deletes nothing. |

## Safety

- Never deletes git history, databases, Docker volumes, or documents without
  per-item confirmation.
- Previews before destructive steps (`mo clean --dry-run`, `git gc` before any
  `.git` consideration, `docker system prune` before anything touching volumes).
- Reports real `df` numbers, not estimates.

## Credits

Built around [tw93/Mole](https://github.com/tw93/Mole) (`mo`) for the heavy
lifting on cache cleanup.
