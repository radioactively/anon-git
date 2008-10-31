#!/usr/bin/env bash
# anonymize-git-history.sh
#
# Anonymizes ALL commits in the current branch history:
#   • same name/email for author & committer
#   • same date for author & committer date on every commit
#
# WARNING: Rewrites ALL commit hashes -> force-push required afterwards.

set -euo pipefail

show_help() {
    cat << 'EOF'
Anonymize the entire git history of the current branch.

Usage:
  ./anonymize-git-history.sh [OPTIONS]

Options:
  -h, --help              Show this help message and exit
  --date DATE             Date to use for ALL commits (example: "2025-03-10 13:37:00 +0000")
  --name "Full Name"      Name to use for author & committer
  --user email@domain.com Email to use for author & committer

Priority (highest to lowest):
  1. Command-line flags (--date, --name, --user)
  2. Environment variables (GIT_ANON_DATE, GIT_ANON_USERNAME, GIT_ANON_USEREMAIL)
  3. Hardcoded defaults

Examples:
  ./anonymize-git-history.sh
  ./anonymize-git-history.sh --date "2024-06-01 12:00:00 +0000" --name "Anonymous" --user "anon@privacy.dev"
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
        --user)
            EMAIL_ARG="$2"
            shift 2
            ;;
        -*)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
        *)
            printf 'Unexpected argument: %s\n' "$1" >&2
            exit 1
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
#   CONFIRMATION
# ──────────────────────────────────────────────

printf '\n%s\n\n' "WARNING: This will REWRITE ALL commit hashes!" >&2
printf '         You will need to force-push afterwards.\n\n' >&2

printf 'Values that will be used:\n'
printf '  Identity : %s <%s>\n' "${ANON_NAME}" "${ANON_EMAIL}" >&2
printf '  Date     : %s  (same timestamp on EVERY commit)\n' "${ANON_DATE}" >&2
printf '\n'

read -p "Continue? (y/N) " -n 1 -r
printf '\n'
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Create backup branch
backup_branch="backup-anon-$(date +%Y%m%d-%H%M%S)"
git branch "${backup_branch}"
printf 'Created backup branch: %s\n\n' "${backup_branch}" >&2

export FILTER_BRANCH_SQUELCH_WARNING=1

# Export values for python callback
export ANON_DATE ANON_NAME ANON_EMAIL

printf 'Rewriting all commits...\n' >&2

git filter-repo --force --commit-callback '
    import os
    from datetime import datetime

    name  = os.environ["ANON_NAME"].encode("utf-8")
    email = os.environ["ANON_EMAIL"].encode("utf-8")

    commit.author_name = commit.committer_name = name
    commit.author_email = commit.committer_email  = email

    date_str = os.environ["ANON_DATE"]
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
        ts = int(dt.timestamp())
        offset_min = int(dt.utcoffset().total_seconds() / 60) if dt.utcoffset() else 0

        # Format offset as b"+0000" or b"-0700"
        offset_hours = abs(offset_min) // 60
        offset_mins = abs(offset_min) % 60
        sign = "+" if offset_min >= 0 else "-"
        offset_bytes = ("%s%02d%02d" % (sign, offset_hours, offset_mins)).encode("utf-8")

        # Full date as bytes: b"timestamp offset"
        date_bytes = b"%d %s" % (ts, offset_bytes)

    except Exception:
        # Fallback bytes
        date_bytes = b"1225481742 +0000"

    commit.author_date = date_bytes
    commit.committer_date = date_bytes
'

printf '\nHistory rewritten.\n\n' >&2
printf 'Next steps:\n'
printf '  1. Verify:     git log --pretty=fuller --date=iso\n'
printf '  2. Force push: git push --force-with-lease --all\n'
printf '                 git push --force-with-lease --tags\n'
printf '  3. (Later)     git branch -D %s\n\n' "${backup_branch}" >&2
