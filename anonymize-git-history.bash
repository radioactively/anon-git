#!/usr/bin/env bash
# anonymize-git-history.sh
#
# Anonymizes ALL commits in the current branch:
#   • Sets author & committer to the same fake name/email
#   • Sets author & committer date to the same fixed date
#
# WARNING: This rewrites ALL commit hashes → force-push will be required!
#          Always create a backup first.

set -euo pipefail

show_help() {
    cat << 'EOF'
Anonymize the entire git history of the current branch.

Usage:
  ./anonymize-git-history.sh [OPTIONS]

Options:
  -h, --help      Show this help message and exit

Environment variables (optional):
  GIT_ANON_DATE           Date to use for ALL commits
                          (default: 2008-10-31 18:15:42 +0000)
  GIT_ANON_USERNAME       Name to use for author & committer
                          (default: Satoshi Nakamoto)
  GIT_ANON_USEREMAIL      Email to use for author & committer
                          (default: satoshi@gmx.com)

Examples:
  ./anonymize-git-history.sh
  GIT_ANON_DATE="2025-01-01 00:00:00 +0000" ./anonymize-git-history.sh

After running:
  1. Review:     git log --pretty=fuller --date=iso
  2. Force push: git push --force-with-lease --all
                 git push --force-with-lease --tags (if needed)

Note: A backup branch is automatically created before rewriting.
EOF
    exit 0
}

# Handle help flag
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

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

printf '\n%s\n\n' "WARNING: This script will REWRITE ALL commit hashes!" >&2
printf '         You will need to force-push afterwards.\n\n' >&2

printf 'Settings that will be used:\n'
printf '  Identity : %s <%s>\n' "${GIT_ANON_USERNAME}" "${GIT_ANON_USEREMAIL}" >&2
printf '  Date     : %s  (same timestamp on EVERY commit)\n' "${GIT_ANON_DATE}" >&2
printf '\n'

read -p "Continue? (y/N) " -n 1 -r
printf '\n'
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Create backup branch
backup_branch="backup-before-anonymize-$(date +%Y%m%d-%H%M%S)"
git branch "${backup_branch}"
printf 'Created backup branch: %s\n\n' "${backup_branch}" >&2

export FILTER_BRANCH_SQUELCH_WARNING=1

printf 'Rewriting all commits with fixed identity and timestamp...\n' >&2

git filter-repo --force --commit-callback '
    import os
    from datetime import datetime

    name  = os.environb.get(b"GIT_ANON_USERNAME", b"Satoshi Nakamoto")
    email = os.environb.get(b"GIT_ANON_USEREMAIL", b"satoshi@gmx.com")

    commit.author_name      = name
    commit.author_email     = email
    commit.committer_name   = name
    commit.committer_email  = email

    date_str = os.environ.get("GIT_ANON_DATE", "2008-10-31 18:15:42 +0000")
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
        ts = int(dt.timestamp())
        offset_min = int(dt.utcoffset().total_seconds() / 60) if dt.utcoffset() else 0
    except:
        ts = 1225481742
        offset_min = 0

    commit.author_date = commit.committer_date = ts
    commit.author_offset = commit.committer_offset = offset_min
'

printf '\nHistory successfully rewritten.\n\n' >&2
printf 'Next steps:\n'
printf '  1. Verify:     git log --pretty=fuller --date=iso\n'
printf '  2. Force push: git push --force-with-lease --all\n'
printf '                 git push --force-with-lease --tags\n'
printf '  3. (Later)     git branch -D %s\n\n' "${backup_branch}" >&2
