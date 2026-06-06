#!/usr/bin/env bash
# scan.sh — read-only disk usage report for macOS cleanup.
#
# Prints: free space, the biggest consumers in $HOME and ~/Library, and flags
# the well-known macOS space sinks that get miscategorized as "System Data"
# (aerial wallpaper videos, VM swap, Docker.raw, dev caches).
#
# Deletes NOTHING. Safe to run anytime. Pipe-friendly (no TTY needed).
set -uo pipefail

human() { du -shx "$@" 2>/dev/null | sort -rh; }
hr() { printf '\n\033[1;35m== %s ==\033[0m\n' "$1"; }

hr "Disk free"
df -h / | sed -n '1p;2p'

hr "Top of \$HOME (dirs + dotdirs)"
du -shx "$HOME"/* "$HOME"/.[!.]* 2>/dev/null | sort -rh | head -20

hr "~/Library breakdown"
human "$HOME/Library/"* | head -12

hr "Known macOS space sinks (often shown as 'System Data')"
# Aerial / dynamic wallpaper video cache — the #1 phantom-storage culprit.
wp="$HOME/Library/Application Support/com.apple.wallpaper/aerials/videos"
[ -d "$wp" ] && printf 'aerial wallpapers : %s  (%s files) — SAFE to delete, re-downloads\n' \
  "$(du -shx "$wp" 2>/dev/null | cut -f1)" "$(ls -1 "$wp" 2>/dev/null | wc -l | tr -d ' ')"
# VM swap / sleepimage.
[ -d /System/Volumes/VM ] && printf 'VM swap/sleepimage: %s — managed by macOS, do not delete\n' \
  "$(du -shx /System/Volumes/VM 2>/dev/null | cut -f1)"
# Docker disk image (sparse: apparent vs actual differ).
for draw in "$HOME"/Library/Containers/com.docker.docker/Data/vms/*/data/Docker.raw; do
  [ -f "$draw" ] && printf 'Docker.raw        : %s actual (%s apparent) — prune images, never delete file\n' \
    "$(du -shx "$draw" 2>/dev/null | cut -f1)" "$(ls -lh "$draw" 2>/dev/null | awk '{print $5}')"
done
# Tool caches.
for c in "$HOME/.cache" "$HOME/Library/Caches"; do
  [ -d "$c" ] && printf 'cache %-13s: %s — SAFE to delete, regenerates\n' \
    "$(basename "$c")" "$(du -shx "$c" 2>/dev/null | cut -f1)"
done

hr "Workspace artifacts (regenerable)"
for root in "$HOME/workspace" "$HOME/dev" "$HOME/Projects" "$HOME/Code"; do
  [ -d "$root" ] || continue
  nm=$(find "$root" -type d -name node_modules -prune 2>/dev/null | xargs -I{} du -sx {} 2>/dev/null \
        | awk '{s+=$1} END {printf "%.1fGB across %d dirs", s/1024/1024, NR}')
  bd=$(find "$root" \( -type d \( -name dist -o -name build -o -name target -o -name .next -o -name .venv -o -name __pycache__ \) \) -prune 2>/dev/null \
        | xargs -I{} du -sx {} 2>/dev/null | awk '{s+=$1} END {printf "%.1fGB across %d dirs", s/1024/1024, NR}')
  gt=$(find "$root" -type d -name .git -prune 2>/dev/null | xargs -I{} du -sx {} 2>/dev/null \
        | awk '{s+=$1} END {printf "%.1fGB across %d repos", s/1024/1024, NR}')
  printf '%s:\n  node_modules : %s  (SAFE — re-run install; note pnpm hardlinks inflate du)\n' "$root" "${nm:-none}"
  printf '  build dirs   : %s  (SAFE — rebuilds)\n' "${bd:-none}"
  printf '  .git         : %s  (NEVER delete — run git gc to compact)\n' "${gt:-none}"
done

hr "Done — nothing was deleted"
echo "Next: see SKILL.md. Use 'mo clean --dry-run' for quick wins; classify"
echo "anything large as SAFE (regenerable) vs REAL DATA (confirm before deleting)."
