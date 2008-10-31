#!/usr/bin/env bash

show_help() {
    cat << 'EOF'
Anonymize the entire git history of the current branch.

Usage:
  ./anonymize-git-history.sh [OPTIONS]

Options:
  -h, --help                    Show this help message and exit
  --date      ISO Date          Date to use for ALL commits (example: "2025-03-10 13:37:00 +0000")
  --name      "Full Name"       Name to use for author & committer
  --email     email@domain.com  Email to use for author & committer
  --keep-user                   Do not change user name or author
  --keep-date                   Do not change date

Priority (highest to lowest):
  1. Command-line flags (--date, --name, --email)
  2. Environment variables (ANONGIT_DATE, GIT_ANON_USERNAME, GIT_ANON_USEREMAIL)
  3. Hardcoded defaults

Examples:
  ./anonymize-git-history.sh
  ./anonymize-git-history.sh --date "2024-06-01 12:00:00 +0000" --name "Anonymous" --email "anon@example.com"
EOF
    exit 0
}

# ──────────────────────────────────────────────
#   DEFAULT VALUES
# ──────────────────────────────────────────────

DEFAULT_DATE='2008-10-31 18:15:42 +0000'
DEFAULT_NAME='Satoshi Nakamoto'
DEFAULT_EMAIL='satoshi@gmx.com'
DEFAULT_KEEPUSER='0'
DEFAULT_KEEPDATE='0'

# ──────────────────────────────────────────────
#   PARSE ARGUMENTS
# ──────────────────────────────────────────────

DATE_ARG=""
NAME_ARG=""
EMAIL_ARG=""
KEEPUSER_ARG=""
KEEPDATE_ARG=""

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
        --keep-user)
            KEEPUSER_ARG='1'
            shift
            ;;
        --keep-date)
            KEEPDATE_ARG='1'
            shift
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

ANON_GIT_DATE="${DATE_ARG:-${ANON_GIT_DATE:-${DEFAULT_DATE}}}"
ANON_GIT_NAME="${NAME_ARG:-${ANON_GIT_USERNAME:-${DEFAULT_NAME}}}"
ANON_GIT_EMAIL="${EMAIL_ARG:-${ANON_GIT_USEREMAIL:-${DEFAULT_EMAIL}}}"
ANON_GIT_KEEPUSER="${KEEPUSER_ARG:-${ANON_GIT_KEEPUSER:-${DEFAULT_KEEPUSER}}}"
ANON_GIT_KEEPDATE="${KEEPDATE_ARG:-${ANON_GIT_KEEPDATE:-${DEFAULT_KEEPDATE}}}"

# ──────────────────────────────────────────────
#   Validation
# ──────────────────────────────────────────────

if [[ "$KEEPUSER_ARG" == '1' && "$KEEPDATE_ARG" == '1' ]]; then
    printf 'Error: the flags --keep-user and --keep-date cannot be used together!\n' >&2
    exit 1
fi

if [[ "$KEEPUSER_ARG" == '1' && "$NAME_ARG" != '' ]]; then
    printf 'Error: the flags --keep-user and --name cannot be used together!\n' >&2
    exit 1
fi

if [[ "$KEEPUSER_ARG" == '1' && "$EMAIL_ARG" != '' ]]; then
    printf 'Error: the flags --keep-user and --email cannot be used together!\n' >&2
    exit 1
fi

if [[ "$KEEPDATE_ARG" == '1' && "$DATE_ARG" != '' ]]; then
    printf 'Error: the flags --keep-date and --date cannot be used together!\n' >&2
    exit 1
fi

# ──────────────────────────────────────────────
#   CONFIRMATION
# ──────────────────────────────────────────────

printf '\n%s\n\n' "WARNING: This will REWRITE ALL commit hashes!" >&2
printf '         You will need to force-push afterwards.\n\n' >&2
printf 'Values that will be used:\n' >&2
[[ $ANON_GIT_KEEPUSER == '0' ]] && printf '  Identity : %s <%s>\n' "${ANON_GIT_NAME}" "${ANON_GIT_EMAIL}" >&2
[[ $ANON_GIT_KEEPDATE == '0' ]] && printf '  Date     : %s  (same timestamp on EVERY commit)\n' "${ANON_GIT_DATE}" >&2
printf '\n' >&2
read -p "Continue? (y/N) " -n 1 -r
printf '\n'
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Create backup branch
backup_branch="backup-anon-$(date +%Y%m%d-%H%M%S)"
git branch "${backup_branch}"
printf 'Created backup branch: %s\n\n' "${backup_branch}" >&2

# Export values for python callback
export ANON_GIT_DATE ANON_GIT_NAME ANON_GIT_EMAIL ANON_GIT_KEEPUSER ANON_GIT_KEEPDATE

printf 'Rewriting all commits...\n\n' >&2

git filter-repo --force --commit-callback '
    from os import environ
    from datetime import datetime

    env = environ

    keepuser = env["ANON_GIT_KEEPUSER"]
    keepdate = env["ANON_GIT_KEEPDATE"]

    if keepuser == "0":
        name  = env["ANON_GIT_NAME"].encode("utf-8")
        email = env["ANON_GIT_EMAIL"].encode("utf-8")
        commit.author_name = commit.committer_name = name
        commit.author_email = commit.committer_email = email

    if keepdate == "0":
        date_str = env["ANON_GIT_DATE"]

        # Convert date string to date object, then to bytes
        dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
        ts = int(dt.timestamp())
        offset_min = int(dt.utcoffset().total_seconds() / 60) if dt.utcoffset() else 0
        offset_hours = abs(offset_min) // 60
        offset_mins = abs(offset_min) % 60
        sign = "+" if offset_min >= 0 else "-"
        offset_bytes = ("%s%02d%02d" % (sign, offset_hours, offset_mins)).encode("utf-8")
        date = b"%d %s" % (ts, offset_bytes)

        commit.author_date = commit.committer_date = date
' >&2

printf '\nHistory rewritten.\n\n' >&2
printf 'Next steps:\n' >&2
printf '  1. Verify:     git log --pretty=fuller --date=iso\n' >&2
printf '  2. Force push: git push --force-with-lease --all\n' >&2
printf '                 git push --force-with-lease --tags\n' >&2
printf '  3. (Later)     git branch -D %s\n\n' "${backup_branch}" >&2
