# mac-cleanup

A **Claude Code skill** that frees up disk space on macOS — *safely*. It
investigates what's actually eating your storage, explains the "System Data"
mystery, drives the [`mo` (Mole)](https://github.com/tw93/Mole) CLI for quick
wins, and never deletes anything irreplaceable (git history, databases, Docker
volumes) without asking first.

The core idea: sort every large thing into **safe** (regenerable — caches,
build artifacts, downloaded models) or **real data** (exists nowhere else —
delete only with confirmation). Most "Mac cleaners" skip that distinction. This
one is built around it.

## Install it with your coding agent

Paste this into **Claude Code**:

```text
Set up the mac-cleanup skill from https://github.com/reallongnguyen/mac-cleanup — follow its README.
```

The agent reads the repo and runs `install.sh` — installing `mo` via Homebrew
and linking the skill into `~/.claude/skills/`.

## Prefer to run it yourself?

```sh
git clone https://github.com/reallongnguyen/mac-cleanup.git
cd mac-cleanup
./install.sh
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

## What's in the repo

| Path | Purpose |
|------|---------|
| `skill/SKILL.md` | The skill: methodology, `mo` usage, safe/real-data guardrails. |
| `skill/scripts/scan.sh` | Read-only disk report — top consumers + known macOS space sinks. Deletes nothing. |
| `install.sh` | Installs `mo` and links the skill into `~/.claude/skills/`. |

## Safety

- Never deletes git history, databases, Docker volumes, or documents without
  per-item confirmation.
- Previews before destructive steps (`mo clean --dry-run`, `git gc` before any
  `.git` consideration, `docker system prune` before anything touching volumes).
- Reports real `df` numbers, not estimates.

## Credits

Built around [tw93/Mole](https://github.com/tw93/Mole) (`mo`) for the heavy
lifting on cache cleanup.
