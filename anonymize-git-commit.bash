#!/usr/bin/env bash
# anonymize-git-commit.sh
#
# Anonymizes author/committer name/email and sets both dates to GIT_ANON_DATE
# for a single specified commit (defaults to HEAD).
#
# Usage:
#   ./anonymize-last-commit.sh [OPTIONS] [commit]
#
# Options:
#   -h, --help      Show this help message and exit
#
# Arguments:
#   commit          Commit to anonymize (hash, HEAD~n, branch name, etc.)
#                   If omitted, defaults to HEAD (most recent commit)

set -euo pipefail

show_help() {
    cat << 'EOF'
Anonymize a single git commit's author, committer, and dates.

Usage:
  ./anonymize-last-commit.sh [OPTIONS] [commit]

Options:
  -h, --help      Show this help message and exit

Arguments:
  commit          Commit to anonymize (can be: hash, HEAD~3, branch, tag, ...)
                  If omitted, defaults to HEAD

Environment variables (optional):
  GIT_ANON_DATE           Date to use (default: 2008-10-31 18:15:42 +0000)
  GIT_ANON_USERNAME       Name to use     (default: Satoshi Nakamoto)
  GIT_ANON_USEREMAIL      Email to use    (default: satoshi@gmx.com)

Examples:
  ./anonymize-last-commit.sh
  ./anonymize-last-commit.sh HEAD~2
  ./anonymize-last-commit.sh abc1234def5678
  GIT_ANON_DATE="2024-06-15 12:00:00 +0200" ./anonymize-last-commit.sh

Note: Rewriting commits changes their hashes and all descendant commits.
      You will usually need to force-push afterwards.
EOF
    exit 0
}

# ──────────────────────────────────────────────
#   CONFIGURATION
# ──────────────────────────────────────────────

DEFAULT_GIT_ANON_DATE='2008-10-31 18:15:42 +0000'
DEFAULT_GIT_ANON_USERNAME='Satoshi Nakamoto'
DEFAULT_GIT_ANON_USEREMAIL='satoshi@gmx.com'

GIT_ANON_DATE="${GIT_ANON_DATE:-${DEFAULT_GIT_ANON_DATE}}"
GIT_ANON_USERNAME="${GIT_ANON_USERNAME:-${DEFAULT_GIT_ANON_USERNAME}}"
GIT_ANON_USEREMAIL="${GIT_ANON_USEREMAIL:-${DEFAULT_GIT_ANON_USEREMAIL}}"

# ──────────────────────────────────────────────

# Handle help flag
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

TARGET_COMMIT="${1:-HEAD}"

# Validate that the target commit exists
if ! git rev-parse --quiet --verify "${TARGET_COMMIT}^{commit}" >/dev/null 2>&1; then
    printf 'Error: Commit "%s" does not exist or is not a commit object.\n' "${TARGET_COMMIT}" >&2
    exit 1
fi

printf 'Anonymizing commit: %s\n' "$(git rev-parse --short "${TARGET_COMMIT}")" >&2
printf '  →  %s <%s>\n' "${GIT_ANON_USERNAME}" "${GIT_ANON_USEREMAIL}" >&2
printf '  date = %s\n\n' "${GIT_ANON_DATE}" >&2

# Safety: avoid recursion if already inside a rewriting hook
[[ -n "${INSIDE_GIT_HOOK_REWRITING:-}" ]] && exit 0

export FILTER_BRANCH_SQUELCH_WARNING=1
export INSIDE_GIT_HOOK_REWRITING=1

# Export the target commit hash (full) so the callback can see it
export TARGET_COMMIT="$(git rev-parse "${TARGET_COMMIT}")"

git filter-repo \
  --force \
  --commit-callback '
    import os
    from datetime import datetime

    target = os.environ.get("TARGET_COMMIT", "").strip()

    if commit.original_id.hex() == target:
        name  = os.environb.get(b"GIT_ANON_USERNAME", b"Satoshi Nakamoto")
        email = os.environb.get(b"GIT_ANON_USEREMAIL", b"satoshi@gmx.com")

        commit.author_name      = name
        commit.author_email     = email
        commit.committer_name   = name
        commit.committer_email  = email

        date_str = os.environ.get("GIT_ANON_DATE", "2008-10-31 18:15:42 +0000")
        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
            commit.author_date = commit.committer_date = int(dt.timestamp())
            offset_sec = dt.utcoffset().total_seconds() if dt.utcoffset() else 0
            commit.author_offset = commit.committer_offset = int(offset_sec // 60)
        except Exception:
            commit.author_date = commit.committer_date = 1225481742
            commit.author_offset = commit.committer_offset = 0
  ' \
  --refs "${TARGET_COMMIT}"

# If we just changed HEAD, refresh the index/working tree
if [ "$(git rev-parse "${TARGET_COMMIT}")" = "$(git rev-parse HEAD)" ]; then
    git reset --quiet --soft HEAD@{1} 2>/dev/null || true
    git reset --quiet HEAD
fi

printf 'Done. Commit %s has been rewritten.\n' "$(git rev-parse --short "${TARGET_COMMIT}")" >&2
