---
name: mac-cleanup
description: >-
  Free up disk space on macOS safely. Use this whenever the user is low on
  storage, asks why their disk is full, wonders why "System Data" / "System" /
  "macOS" is huge in Storage settings, wants to "clean my Mac", "free up space",
  "reclaim disk", mentions the Mole / `mo` tool, or is deciding what's safe to
  delete (caches, node_modules, Docker images, Xcode junk, wallpaper videos).
  Trigger even when the user only describes the symptom ("my disk keeps filling
  up", "only 5GB left", "what's eating my storage") and doesn't name a tool.
  The skill investigates, classifies everything as safe-to-delete vs real data,
  drives the `mo` (Mole) CLI for quick wins, and never deletes irreplaceable
  data (git history, databases, Docker volumes) without explicit confirmation.
---

# mac-cleanup

Reclaim disk space on macOS without losing anything that matters.

The core skill is **judgment**, not deletion. Most "cleaner" advice is reckless
because it treats all large files the same. This skill's job is to sort every
large thing into one of two buckets and act accordingly:

- **Safe** — regenerable at no real cost. Caches, build artifacts, downloaded
  models, package stores, OS re-downloadables. Delete freely.
- **Real data** — exists nowhere else, or is expensive/impossible to recreate.
  Git history (especially unpushed or no-remote), databases, Docker volumes,
  user documents, the one copy of something. **Never delete without explicit
  per-item confirmation**, no matter how much space it would free.

When unsure which bucket something is in, treat it as real data and ask. Freeing
space is reversible (re-download, rebuild); deleting someone's only copy is not.

## Tooling: `mo` (Mole) + manual investigation

[`mo`](https://github.com/tw93/Mole) is installed (`brew install mole`).
It's great for fast, whitelisted, safe cache cleanup — but it's an interactive
TUI for its deeper commands, which an agent can't drive. So use a **hybrid**:

| Use `mo` for | Use manual `du` + judgment for |
|---|---|
| Quick safe cache sweeps (`mo clean`) | Finding *why* the disk is full |
| Previewing (`mo clean --dry-run`) | The macOS "System Data" gotchas below |
| Old build artifacts (`mo purge`) | Docker, git, databases, workspace repos |
| App removal (`mo uninstall <app>`) | Anything needing a safe/real-data call |

**Critical `mo` behavior:** run non-interactively (piped / no TTY), `mo clean`
**proceeds automatically** with user-level cleanup — it is *not* a no-op without
confirmation. Always preview with `mo clean --dry-run` first and show the user
what it would remove. `mo` does protect ~18 core cache patterns via a whitelist
and skips system-level cleanup without a TTY, so it's conservative by design —
but never assume "it'll just ask." Interactive commands (`mo analyze`,
`mo status` menus) error with `could not open a new TTY` under an agent; fall
back to `scripts/scan.sh` instead.

## Workflow

### 1. Assess

```bash
df -h /                          # how bad is it? what's free?
mo --version                     # confirms mo + prints disk free
bash scripts/scan.sh             # read-only report: top consumers + known sinks
```

`scripts/scan.sh` (bundled) prints free space, the biggest dirs in `$HOME` and
`~/Library`, flags the macOS gotchas below, and tallies workspace artifacts —
all without deleting anything. Start here; it replaces a dozen manual `du`
commands and is the same investigation, captured once.

### 2. Explain "System Data" if that's the user's confusion

macOS Storage settings lumps everything it can't classify (caches, containers,
dev toolchains, Docker, VM swap, **and your source code**) into "System Data" /
"System" / "macOS". A large number there is almost never the OS — it's the
buckets below. A clean macOS is ~15–30 GB of System Data; anything much larger
is your own footprint. Tell the user this so they stop blaming macOS.

### 3. Quick safe wins with `mo`

```bash
mo clean --dry-run               # preview — show the user the total it would free
mo clean                         # then run it (user-level caches; whitelisted)
```

### 4. Deep investigation — the macOS space sinks

These are the usual suspects, in rough order of how often they're the culprit.
`scripts/scan.sh` surfaces them; here's what each means and the safe action.

| Sink | Path | Bucket | Action |
|---|---|---|---|
| **Aerial wallpaper videos** (the #1 phantom "System Data") | `~/Library/Application Support/com.apple.wallpaper/aerials/videos` | Safe | `rm -rf .../videos/*` — re-downloads on demand. Often **tens of GB**. |
| Tool caches | `~/.cache/*`, `~/Library/Caches/*` | Safe | Delete subdirs; they regenerate. |
| Docker images/build cache | inside `Docker.raw` | Safe | `docker system prune -a` (NOT `--volumes`). Frees space *inside* the sparse image. |
| Downloaded ML models | `~/.cache/huggingface` | Safe-ish | Deletable but costs bandwidth to refetch — confirm if large. |
| Language toolchains you no longer use | `~/.rustup`, `~/.cargo`, `~/.nvm`, etc. | Safe | Remove only the ones the user confirms they're done with. |
| Xcode | `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/CoreSimulator` | Safe | `rm -rf DerivedData/*`; `xcrun simctl delete unavailable`. |
| VM swap / sleepimage | `/System/Volumes/VM` | **Managed** | Don't touch — macOS owns it. |

### 5. Workspace repos — artifacts vs history

Source trees accumulate huge regenerable cruft. `mo purge` is the preferred
way to clean them, but its default scan paths **don't include custom workspace
folders** (e.g. `~/workspace`). Ask the user where their projects live, then
pass that path explicitly:

```bash
mo purge --paths ~/workspace        # or wherever the user keeps repos
```

If `mo purge` isn't available or the user wants finer control, fall back to
`find` (SAFE — regenerable; note that `du` over-counts pnpm node_modules
because they hardlink into `~/Library/pnpm`, so real freed space may be less):

```bash
find ~/workspace -type d -name node_modules -prune -exec rm -rf {} +
find ~/workspace \( -type d \( -name dist -o -name build -o -name target \
  -o -name .next -o -name .venv -o -name __pycache__ \) \) -prune -exec rm -rf {} +
```

`.git` is **real data** — never `rm` it. To shrink history safely:

```bash
git -C <repo> gc --aggressive --prune=now   # compacts, loses nothing
```

### 6. Before deleting real data — always confirm, per item

Stop and get explicit confirmation for each of these. They are irreversible and
usually worth far more than the space they free:

- **`.git` removal** — check first for unpushed commits, stashes, and uncommitted
  changes, and whether a remote exists. A repo with **no remote** or unpushed
  work loses that history forever. Run this audit and show it before touching
  anything:
  ```bash
  cd <repo> && git log --branches --not --remotes --oneline | wc -l   # unpushed
  git status --porcelain | wc -l                                       # dirty
  git stash list | wc -l                                               # stashes
  git remote                                                           # empty = no backup
  ```
- **Docker volumes** (`docker volume prune --all` / `--volumes`) — these hold
  databases (Postgres, Redis, etc.). The default `docker volume prune` spares
  named volumes for exactly this reason; never force `--all` without naming what
  dies. List them (`docker volume ls`) and confirm each.
- **Databases / `.db` / data dirs** — e.g. a multi-GB SQLite file is application
  data, not cache. Never auto-delete.
- **Large model caches** when refetch is expensive — confirm.

### 7. Report

Always end with a before/after and a breakdown:

```
Disk free: 5.3 GB → 101 GB  (+96 GB)

Freed:
  Aerial wallpaper videos   56 GB   (safe, re-downloadable)
  HuggingFace cache         17 GB   (safe)
  Docker images           16.5 GB   (safe)

Left intact (real data):
  catalog.db                88 GB   (your call — application database)
  .git history (all repos)         (compacted via gc instead)
```

State what was left and *why* — the user should trust that nothing irreplaceable
was touched.

## Uninstalling the skill

If the user asks to uninstall mac-cleanup or remove the skill:

```bash
# 1. Remove the skill symlink
rm -f ~/.claude/skills/mac-cleanup

# 2. Delete the cloned repo
rm -rf ~/mac-cleanup

# 3. Optionally uninstall mo (ask first — user may use it independently)
# brew uninstall mole

# 4. Verify
ls ~/.claude/skills/mac-cleanup 2>/dev/null && echo "still present" || echo "removed"
```

Ask before uninstalling `mo` — the user may have installed it for other purposes. Everything else is safe to remove unconditionally.

## Guardrails (the whole point)

- Never delete git history, databases, Docker volumes, or user documents without
  explicit per-item confirmation.
- Prefer reversible actions: `mo clean --dry-run` before `mo clean`;
  `git gc` before considering `.git` removal; `docker system prune` before
  anything touching `--volumes`.
- `pnpm` hardlinks mean `du` over-reports node_modules size; don't promise space
  you won't actually reclaim — verify with `df` after.
- Report honestly: show real before/after `df` numbers, not estimates.
