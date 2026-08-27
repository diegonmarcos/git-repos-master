#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║ clone.sh — pick which repos to have locally                      ║
# ║                                                                  ║
# ║   ./clone.sh                list what exists and what does not   ║
# ║   ./clone.sh <name>...      clone those, then link them          ║
# ║   ./clone.sh --all          clone everything in repos.json       ║
# ║   ./clone.sh --group <g>    clone one group                      ║
# ║   ./clone.sh --link         relink whatever is already cloned    ║
# ║   ./clone.sh --relink       rewrite every link from the registry ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# This repo is an INDEX, not a container. Clones live outside it (in
# $CLOUD_GIT_BASE, default ~/git) and appear here as symlinks:
#
#     repo-master/a_cloud/cloud-infra-desktop ->  ~/git/cloud-infra-desktop
#     repo-master/d_lecole/back-Algo ->  ~/git/lecole-42/back-Algo   (`path`)
#
# Every repo in the registry has a link, committed, whether or not you have
# cloned it. A link to a repo you do not have dangles — that is the index
# working, not a fault: `ls` is the project, and the broken entries are your
# to-clone list.
#
# Why not submodules: a submodule pins a commit and wants --recursive, which
# here meant cloud-master containing cloud containing cloud-master (an
# unterminating recursive clone), private repos breaking init for anyone
# without those credentials, and every repository dragged along to read one
# file. An index of working clones is a different thing from a pinned build
# input, and this is the former.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="$SCRIPT_DIR/repos.json"
BASE="${CLOUD_GIT_BASE:-$HOME/git}"

[ -f "$REGISTRY" ] || { echo "FATAL: $REGISTRY missing" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "FATAL: node required to read $REGISTRY" >&2; exit 1; }

# Registry readers. node, not jq: node is already required by every build.sh
# in the fleet, jq is not guaranteed present.
_names() { node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(r.repos.map(x=>x.name).join(" "))' "$REGISTRY"; }
_field() { node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=r.repos.find(x=>x.name===process.argv[2]);process.stdout.write(e?String(e[process.argv[3]]??""):"")' "$REGISTRY" "$1" "$2"; }
# A repo with no group lives at the root and its group name is the empty
# string, which word-splitting would drop from the loop entirely — so it is
# emitted as the sentinel "." and translated back at the point of use.
_groups() { node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write([...new Set(r.repos.map(x=>x.group||"."))].sort().join(" "))' "$REGISTRY"; }
# Where the clone actually lives under $BASE. Defaults to the repo name; the
# d_lecole entries override it because those clones sit in ~/git/lecole-42/.
# Without this the only way to index them would be to move them, which is a
# separate decision from indexing them.
_path() { node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=r.repos.find(x=>x.name===process.argv[2]);process.stdout.write(e&&e.path?e.path:process.argv[2])' "$REGISTRY" "$1"; }

# An entry with no `group` links at the ROOT of this repo; one with a group
# links inside that directory. Depth follows: ../ from the root, ../../ from a
# group. Getting that wrong does not fail loudly — it produces a link that
# resolves somewhere plausible and wrong.
_linkpath() { [ -n "$2" ] && printf '%s/%s/%s' "$SCRIPT_DIR" "$2" "$1" || printf '%s/%s' "$SCRIPT_DIR" "$1"; }
# $1 is the PATH under $BASE, not the name — they differ whenever an entry sets
# `path`, and using the name there yields a link that dangles silently.
_linktarget() { [ -n "$2" ] && printf '../../%s' "$1" || printf '../%s' "$1"; }

# The links are RELATIVE and COMMITTED.
#
# Absolute would not survive the trip. Git stores a symlink's target verbatim,
# so a committed /home/diego/git/cloud-infra-desktop resolves on exactly one machine and
# dangles everywhere else — the same failure .mcp.json had as a link to
# /home/diego/.mcp.json. Relative has no such dependency: clone the repos as
# siblings anywhere ($CLOUD_GIT_BASE, ~/git, /srv, a container) and every link
# resolves.
link_one() {
    _n="$1"; _g=$(_field "$_n" group); _pp=$(_path "$_n")
    _p=$(_linkpath "$_n" "$_g")
    mkdir -p "$(dirname "$_p")"
    # Not cloned here -> no link. A group dir may legitimately be empty on a
    # given machine (galaxy indexes d_lecole but does not carry the coursework),
    # and a dangling link is worse than an absent one: it looks like breakage.
    if [ ! -d "$BASE/$_pp" ]; then rm -f "$_p"; return 0; fi
    # -n so relinking an existing link replaces it instead of nesting inside it.
    ln -sfn "$(_linktarget "$_pp" "$_g")" "$_p"
    return 0
}

clone_one() {
    _n="$1"; _u=$(_field "$_n" url); _t="$BASE/$(_path "$_n")"
    if [ -d "$_t/.git" ]; then
        printf "  = %-24s already cloned at %s\n" "$_n" "$_t"
    else
        printf "  + %-24s cloning -> %s\n" "$_n" "$_t"
        mkdir -p "$BASE"
        if ! git clone "$_u" "$_t"; then
            printf "  ! %-24s CLONE FAILED" "$_n"
            [ "$(_field "$_n" private)" = "true" ] && printf " (private — check your credentials)"
            printf "\n"
            return 1
        fi
    fi
    link_one "$_n" && printf "  > %-24s linked\n" "$_n"
}

do_list() {
    printf "base: %s   (override with \$CLOUD_GIT_BASE)\n\n" "$BASE"
    for g in $(_groups); do
        [ "$g" = "." ] && g=""
        [ -n "$g" ] && printf "%s/\n" "$g" || printf "./  (repo root)\n"
        for n in $(_names); do
            [ "$(_field "$n" group)" = "$g" ] || continue
            if [ -d "$BASE/$(_path "$n")/.git" ]; then
                [ -L "$(_linkpath "$n" "$g")" ] && s="cloned + linked" || s="cloned, NOT linked (run --link)"
            else
                s="not cloned"
                [ "$(_field "$n" private)" = "true" ] && s="$s (private)"
            fi
            printf "  %-24s %s\n" "$n" "$s"
        done
        printf "\n"
    done
    printf "clone with:  ./clone.sh <name>...  |  --group <g>  |  --all\n"
}

case "${1:-}" in
    ""|-l|--list) do_list ;;
    --link)
        for n in $(_names); do link_one "$n" && printf "  > %-24s linked\n" "$n"; done
        ;;
    --relink)
        # Rewrite every link from the registry. Use after adding, renaming or
        # regrouping a repo in repos.json; the result is committed like any
        # other change.
        for n in $(_names); do
            g=$(_field "$n" group)
            link_one "$n" && printf "  > %-24s %s -> %s\n" "$n" "${g:+$g/}$n" "$(_linktarget "$(_path "$n")" "$g")"
        done
        ;;
    --all)
        fail=0
        for n in $(_names); do clone_one "$n" || fail=$((fail+1)); done
        [ "$fail" -eq 0 ] || { echo; echo "$fail repo(s) failed — see above."; exit 1; }
        ;;
    --group)
        g="${2:?usage: clone.sh --group <group>}"
        for n in $(_names); do [ "$(_field "$n" group)" = "$g" ] && clone_one "$n" || true; done
        ;;
    -h|--help)
        sed -n '2,13p' "$0" | sed 's/^# \?//'
        ;;
    *)
        for n in "$@"; do
            case " $(_names) " in
                *" $n "*) clone_one "$n" || true ;;
                *) echo "unknown repo: $n  (see ./clone.sh --list)" >&2; exit 1 ;;
            esac
        done
        ;;
esac
