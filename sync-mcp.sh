#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║ sync-mcp.sh — propagate the canonical MCP config to repo roots    ║
# ║                                                                  ║
# ║   ./sync-mcp.sh            copy source -> drifted .mcp.json      ║
# ║   ./sync-mcp.sh --check    report only, write nothing (CI gate)  ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# The canonical project-scoped MCP config is generated into
# cloud-infra/0_apps/src/root/mcp.json. Every other repo that carries a
# .mcp.json at its root is meant to be a byte-for-byte copy of it. Nothing
# used to enforce that: the copy was a manual hop, and it was skipped three
# times, leaving repo roots pointing at stale/renamed MCP servers (17 days,
# 7 stale server names, as of 2026-08-29). This script IS that hop.
#
# --check exists to be wired into CI as the gate that stops this from
# happening a fourth time: it never writes, and it exits non-zero the moment
# any cloned repo's .mcp.json disagrees with the source, so drift fails the
# build instead of sitting unnoticed for weeks.
#
# Repos with NO .mcp.json are deliberately left alone. Whether a given repo
# should have project-scoped MCP servers at all is a decision for that
# repo, made once, by hand -- this script's job is only to keep an existing
# copy in sync with the source, never to hand a new repo an opinion it
# never asked for.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="$SCRIPT_DIR/repos.json"
BASE="${CLOUD_GIT_BASE:-$HOME/git}"
SOURCE="$BASE/cloud-infra/0_apps/src/root/mcp.json"

[ -f "$REGISTRY" ] || { echo "FATAL: $REGISTRY missing" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "FATAL: node required to read $REGISTRY" >&2; exit 1; }

# Registry readers. node, not jq: node is already required by every build.sh
# in the fleet, jq is not guaranteed present. Mirrors clone.sh's helpers.
_names() { node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(r.repos.map(x=>x.name).join(" "))' "$REGISTRY"; }
_path() { node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=r.repos.find(x=>x.name===process.argv[2]);process.stdout.write(e&&e.path?e.path:process.argv[2])' "$REGISTRY" "$1"; }

CHECK=0
case "${1:-}" in
    "") ;;
    --check) CHECK=1 ;;
    -h|--help)
        sed -n '2,8p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    *) echo "unknown option: $1  (see ./sync-mcp.sh --help)" >&2; exit 1 ;;
esac

# Checked AFTER argument parsing, not before: --help must work on a machine
# that has never cloned cloud-infra, and $SOURCE depends on $CLOUD_GIT_BASE.
[ -f "$SOURCE" ] || { echo "FATAL: source MCP config missing: $SOURCE" >&2; exit 1; }

unchanged=0 updated=0 absent=0 not_cloned=0

for n in $(_names); do
    t="$BASE/$(_path "$n")"
    if [ ! -d "$t/.git" ]; then
        not_cloned=$((not_cloned+1))
        continue
    fi
    target="$t/.mcp.json"
    # Never let source and target collide -- cloud-infra's own repo root is
    # a different file from the generated one under 0_apps/src/root/, but
    # guard it explicitly rather than trust that path shape forever.
    [ "$target" -ef "$SOURCE" ] 2>/dev/null && continue
    if [ ! -f "$target" ]; then
        printf "  . %-24s absent (not created)\n" "$n"
        absent=$((absent+1))
        continue
    fi
    if cmp -s "$SOURCE" "$target"; then
        printf "  = %-24s unchanged\n" "$n"
        unchanged=$((unchanged+1))
    else
        if [ "$CHECK" -eq 1 ]; then
            printf "  ! %-24s drifted\n" "$n"
        else
            cp "$SOURCE" "$target"
            printf "  > %-24s updated\n" "$n"
        fi
        updated=$((updated+1))
    fi
done

echo
if [ "$CHECK" -eq 1 ]; then
    printf "unchanged: %d   drifted: %d   absent: %d   not cloned: %d\n" \
        "$unchanged" "$updated" "$absent" "$not_cloned"
    [ "$updated" -eq 0 ] || exit 1
else
    printf "unchanged: %d   updated: %d   absent: %d   not cloned: %d\n" \
        "$unchanged" "$updated" "$absent" "$not_cloned"
fi
