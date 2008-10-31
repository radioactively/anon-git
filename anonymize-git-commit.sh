#!/usr/bin/env bash

# ──────────────────────────────────────────────
# DEFAULTS

DEFAULT_DATE='2008-10-31 18:15:42 +0000'
DEFAULT_NAME='Satoshi Nakamoto'
DEFAULT_EMAIL='satoshi@gmx.com'
DEFAULT_KEEPUSER='0'
DEFAULT_KEEPDATE='0'

# ──────────────────────────────────────────────────────────────────────
# HELP
show_help() {
    cat << EOF
Anonymize a single git commit's author, committer, and dates.

Usage:
  ./anonymize-git-commit.sh [OPTIONS] [commit]

Options:
  -h, --help                    Show this help message and exit
  --date      ISO Date          Date to use (example: "2025-03-10 13:37:00 +0000")
  --name      "Full Name"       Name to use for author & committer
  --email     email@domain.com  Email to use for author & committer
  --keep-user                     Do not change user name or author
  --keep-date                     Do not change date
  --no-confirm                    Do not prompt for confirmation

Arguments:
  commit                  Commit to anonymize (can be: hash, HEAD~3, branch, tag, ...)
                          If omitted, defaults to HEAD

Priority (highest to lowest):
  1. Command-line flags (--date, --name, --email, --keep-user, --keep-date)
  2. Environment variables (ANON_GIT_DATE, ANON_GIT_NAME, ANON_GIT_EMAIL, ANON_GIT_KEEPUSER, ANON_GIT_KEEPDATE)
  3. Hardcoded defaults (${DEFAULT_NAME} <${DEFAULT_EMAIL}>)

Examples:
  ./anonymize-git-commit.sh
  ./anonymize-git-commit.sh HEAD~2
  ./anonymize-git-commit.sh --date "2024-01-01 00:00:00 +0000" --name "Jane Doe" --email "jane@anon.dev" 8ddf55
EOF
    exit 0
}

# ──────────────────────────────────────────────────────────────────────
# PARSE ARGUMENTS

DATE_ARG=""
NAME_ARG=""
EMAIL_ARG=""
KEEPUSER_ARG=""
KEEPDATE_ARG=""
NOCONFIRM_ARG=""
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
        --keep-user)
            KEEPUSER_ARG='1'
            shift
            ;;
        --keep-date)
            KEEPDATE_ARG='1'
            shift
            ;;
        --no-confirm)
            NOCONFIRM_ARG='1'
            shift
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
# VALIDATE ARGS

if ! git rev-parse --quiet --verify "${TARGET_COMMIT}^{commit}" >/dev/null 2>&1; then
    printf 'Error: Commit "%s" does not exist or is not a commit object.\n' "${TARGET_COMMIT}" >&2
    exit 1
fi

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
# RESOLVE ARGS

ANON_GIT_DATE="${DATE_ARG:-${ANON_GIT_DATE:-${DEFAULT_DATE}}}"
ANON_GIT_NAME="${NAME_ARG:-${ANON_GIT_NAME:-${DEFAULT_NAME}}}"
ANON_GIT_EMAIL="${EMAIL_ARG:-${ANON_GIT_EMAIL:-${DEFAULT_EMAIL}}}"
ANON_GIT_KEEPUSER="${KEEPUSER_ARG:-${ANON_GIT_KEEPUSER:-${DEFAULT_KEEPUSER}}}"
ANON_GIT_KEEPDATE="${KEEPDATE_ARG:-${ANON_GIT_KEEPDATE:-${DEFAULT_KEEPDATE}}}"

# ──────────────────────────────────────────────────────────────────────
# CONFIRM

printf 'Anonymizing commit: %s\n' "$(git rev-parse --short "${TARGET_COMMIT}")" >&2
printf 'Values that will be used:\n' >&2
[[ $ANON_GIT_KEEPUSER == '0' ]] && printf '  Identity : %s <%s>\n' "${ANON_GIT_NAME}" "${ANON_GIT_EMAIL}" >&2
[[ $ANON_GIT_KEEPDATE == '0' ]] && printf '  Date     : %s\n' "${ANON_GIT_DATE}" >&2
printf '\n' >&2

if [[ "$NOCONFIRM_ARG" != '1' ]]; then
    read -p "Continue? (y/N) " -n 1 -r
    printf '\n'
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# ──────────────────────────────────────────────────────────────────────
# REWRITE LOGIC

## Create backup branch
backup_branch="backup-anon-git-$(date +%Y%m%d-%H%M%S)"
git branch "${backup_branch}"
printf 'Created backup branch: %s\n\n' "${backup_branch}" >&2
printf 'Rewriting commit...\n\n' >&2

# Export values for python callback and run it
export TARGET_COMMIT ANON_GIT_DATE ANON_GIT_NAME ANON_GIT_EMAIL ANON_GIT_KEEPUSER ANON_GIT_KEEPDATE
git filter-repo --force --commit-callback '
    from os import environ
    from datetime import datetime

    env = environ
    target = env["TARGET_COMMIT"]

    if commit.original_id == target.encode("utf-8"):
        keepuser = env["ANON_GIT_KEEPUSER"]
        keepdate = env["ANON_GIT_KEEPDATE"]

        if keepuser == "0":
            name  = env["ANON_GIT_NAME"].encode("utf-8")
            email = env["ANON_GIT_EMAIL"].encode("utf-8")
            commit.author_name = commit.committer_name = name
            commit.author_email = commit.committer_email = email

        if keepdate == "0":
            date_str = env["ANON_GIT_DATE"]

            # convert date string to date object, then to bytes
            dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
            ts = int(dt.timestamp())
            offset_min = int(dt.utcoffset().total_seconds() / 60) if dt.utcoffset() else 0
            offset_hours = abs(offset_min) // 60
            offset_mins = abs(offset_min) % 60
            sign = "+" if offset_min >= 0 else "-"
            offset_bytes = ("%s%02d%02d" % (sign, offset_hours, offset_mins)).encode("utf-8")
            date = b"%d %s" % (ts, offset_bytes)

            commit.author_date = commit.committer_date = date
' --refs HEAD >&2

# Refresh index if we rewrote HEAD
if [ "${TARGET_COMMIT}" = "$(git rev-parse HEAD)" ]; then
    git reset --quiet --soft HEAD@{1} 2>/dev/null || true
    git reset --quiet HEAD
fi

printf 'Done. Commit %s has been rewritten.\n' "$(git rev-parse --short "${TARGET_COMMIT}")" >&2
