#!/usr/bin/env bash

set -euo pipefail

show_help() {
    cat << 'EOF'
Anonymize a single git commit's author, committer, and dates.

Usage:
  ./anonymize-git-commit.sh [OPTIONS] [commit]

Options:
  -h, --help                    Show this help message and exit
  --date      ISO Date          Date to use (example: "2025-03-10 13:37:00 +0000")
  --name      "Full Name"       Name to use for author & committer
  --email     email@domain.com  Email to use for author & committer

Arguments:
  commit                  Commit to anonymize (can be: hash, HEAD~3, branch, tag, ...)
                          If omitted, defaults to HEAD

Priority (highest to lowest):
  1. Command-line flags (--date, --name, --email)
  2. Environment variables (GIT_ANON_DATE, GIT_ANON_USERNAME, GIT_ANON_USEREMAIL)
  3. Hardcoded defaults

Examples:
  ./anonymize-git-commit.sh
  ./anonymize-git-commit.sh HEAD~2
  ./anonymize-git-commit.sh --date "2024-01-01 00:00:00 +0000" --name "Jane Doe" --email "jane@anon.dev" 8ddf55
EOF
    exit 0
}

# ──────────────────────────────────────────────
#   DEFAULT VALUES
# ──────────────────────────────────────────────

DEFAULT_DATE='2008-10-31 18:15:42 +0000'
DEFAULT_NAME='Satoshi Nakamoto'
DEFAULT_EMAIL='satoshi@gmx.com'

# ──────────────────────────────────────────────
#   PARSE ARGUMENTS
# ──────────────────────────────────────────────

DATE_ARG=""
NAME_ARG=""
EMAIL_ARG=""
TARGET_COMMIT="HEAD"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --date)
            DATE_ARG="$2"
            shift 2
            ;;
        --name)
            NAME_ARG="$2"
            shift 2
            ;;
        --email)
            EMAIL_ARG="$2"
            shift 2
            ;;
        -*)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
        *)
            TARGET_COMMIT="$1"
            shift
            ;;
    esac
done

# ──────────────────────────────────────────────
#   Resolve final values (flags > env > default)
# ──────────────────────────────────────────────

ANON_DATE="${DATE_ARG:-${GIT_ANON_DATE:-${DEFAULT_DATE}}}"
ANON_NAME="${NAME_ARG:-${GIT_ANON_USERNAME:-${DEFAULT_NAME}}}"
ANON_EMAIL="${EMAIL_ARG:-${GIT_ANON_USEREMAIL:-${DEFAULT_EMAIL}}}"

# ──────────────────────────────────────────────
#   VALIDATION
# ──────────────────────────────────────────────

if ! git rev-parse --quiet --verify "${TARGET_COMMIT}^{commit}" >/dev/null 2>&1; then
    printf 'Error: Commit "%s" does not exist or is not a commit object.\n' "${TARGET_COMMIT}" >&2
    exit 1
fi

printf 'Anonymizing commit: %s\n' "$(git rev-parse --short "${TARGET_COMMIT}")" >&2
printf '  ->  %s <%s>\n' "${ANON_NAME}" "${ANON_EMAIL}" >&2
printf '  date = %s\n\n' "${ANON_DATE}" >&2

# Safety: avoid recursion
[[ -n "${INSIDE_GIT_HOOK_REWRITING:-}" ]] && exit 0

export FILTER_BRANCH_SQUELCH_WARNING=1
export INSIDE_GIT_HOOK_REWRITING=1

# Export values for python callback
export ANON_DATE ANON_NAME ANON_EMAIL
export TARGET_COMMIT_HASH="$(git rev-parse "${TARGET_COMMIT}")"

git filter-repo \
  --force \
  --commit-callback '
    import os
    from datetime import datetime

    target = os.environ["TARGET_COMMIT_HASH"]

    if commit.original_id.hex() == target:
        name  = os.environ["ANON_NAME"].encode()
        email = os.environ["ANON_EMAIL"].encode()
        date_str = os.environ["ANON_DATE"]

        commit.author_name      = name
        commit.author_email     = email
        commit.committer_name   = name
        commit.committer_email  = email

        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
            commit.author_date = commit.committer_date = int(dt.timestamp())
            offset_sec = dt.utcoffset().total_seconds() if dt.utcoffset() else 0
            commit.author_offset = commit.committer_offset = int(offset_sec // 60)
        except Exception:
            commit.author_date = commit.committer_date = 1225481742
            commit.author_offset = commit.committer_offset = 0
  ' \
  --refs "${TARGET_COMMIT}" >&2

# Refresh index if we rewrote HEAD
if [ "${TARGET_COMMIT_HASH}" = "$(git rev-parse HEAD)" ]; then
    git reset --quiet --soft HEAD@{1} 2>/dev/null || true
    git reset --quiet HEAD
fi

printf 'Done. Commit %s has been rewritten.\n' "$(git rev-parse --short "${TARGET_COMMIT}")" >&2
