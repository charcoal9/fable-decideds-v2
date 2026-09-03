#!/usr/bin/env bash
# Manual installer (macOS / Linux / Git Bash) for users who prefer standalone
# skills over the plugin. Plugin install (recommended): inside Claude Code run
#   /plugin marketplace add charcoal9/fable-decideds-v2
#   /plugin install fable-decideds@fable-decideds-v2
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
dst="$HOME/.claude/skills"

mkdir -p "$dst"
cp -r "$src/skills/fable-method"   "$dst/"
cp -r "$src/skills/fable-loop"     "$dst/"
cp -r "$src/skills/fable-judge"    "$dst/"
cp -r "$src/skills/fable-decideds" "$dst/"

cat <<DONE
Installed: fable-method, fable-loop, fable-judge, fable-decideds -> $dst
Try it: open Claude Code and type /fable-judge after any agent claims work is done.
For the entry point that pins implementers, type /fable-decideds.
DONE
