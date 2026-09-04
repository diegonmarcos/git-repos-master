#!/bin/bash
# Clone every repo in repos.json so a fresh container starts with the fleet
# already checked out.
#
# WHY THIS EXISTS: a remote session gets a NEW container each time, so clones do
# not survive a restart — there is nothing to preserve, only something to
# reproduce. clone.sh already knows the registry, the paths and the layout; this
# just runs it before the session starts instead of after someone notices.
#
# Remote only. On a real machine ~/git is the working checkout and re-cloning
# into it is at best noise.
set -euo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

REPO="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
# Siblings of this repo, which is what the committed symlinks resolve to:
# <group>/<name> -> ../../<name>, relative to the index repo.
export CLOUD_GIT_BASE="${CLOUD_GIT_BASE:-$(dirname "$REPO")}"

# git@ -> https:// is already rewritten by the container's git config, so the
# registry's SSH URLs clone over the proxy without an SSH key.
#
# PUBLIC repos only, by construction: the anonymous lane serves those and
# nothing else. The private half (cloud-vault, cloud-data*, front-galaxy-gaia,
# front-unity, lecole42, dev) needs per-session credentials that a hook cannot
# mint, so clone.sh reports them as failures and this does NOT treat that as
# fatal — a partial fleet beats no fleet, and the dangling links ARE the
# to-clone list, exactly as clone.sh's header describes.
cd "$REPO"
./clone.sh --all || true
./clone.sh --link >/dev/null 2>&1 || true

echo "[session-start] fleet cloned under $CLOUD_GIT_BASE"
