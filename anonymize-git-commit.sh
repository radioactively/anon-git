#!/usr/bin/env bash

# ──────────────────────────────────────────────
# DEFAULTS

DEFAULT_DATE='2008-10-31 00:00:00 +0000'
DEFAULT_NAME='Anon'
DEFAULT_EMAIL='anon@localhost'
DEFAULT_KEEPUSER='0'
DEFAULT_KEEPDATE='0'
DEFAULT_KEEPYEAR='0'
DEFAULT_KEEPMONTH='0'
DEFAULT_KEEPDAY='0'

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
  --no-backup                     Do not create backup branch

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
KEEPYEAR_ARG=""
KEEPMONTH_ARG=""
KEEPDAY_ARG=""
NOCONFIRM_ARG=""
NOBACKUP_ARG=""
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
        --keep-year)
            KEEPYEAR_ARG='1'
            shift
            ;;
        --keep-month)
            KEEPMONTH_ARG='1'
            shift
            ;;
        --keep-day)
            KEEPDAY_ARG='1'
            shift
            ;;
        --no-confirm)
            NOCONFIRM_ARG='1'
            shift
            ;;
        --no-backup)
            NOBACKUP_ARG='1'
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

# validate commit
if ! git rev-parse --quiet --verify "${TARGET_COMMIT}^{commit}" >/dev/null 2>&1; then
    printf 'Error: Commit "%s" does not exist or is not a commit object.\n' "${TARGET_COMMIT}" >&2
    exit 1
fi

# validate conflicting flags

flag_conflicts=0
check_incompatible() {
    local flag1="$1"
    local flag2="$3"
    local value1="$2"
    local value2="$4"
    if [[ -n "$value1" && -n "$value2" ]]; then
        printf 'Error: flags %s and %s cannot be used together\n' "$flag1" "$flag2" >&2
        flag_conflicts=1
    fi
}

check_incompatible --keep-user  "$KEEPUSER_ARG"  --name       "$NAME_ARG"
check_incompatible --keep-user  "$KEEPUSER_ARG"  --email      "$EMAIL_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-date  "$KEEPDATE_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-year  "$KEEPYEAR_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-month "$KEEPMONTH_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-day   "$KEEPDAY_ARG"
check_incompatible --keep-date  "$KEEPDATE_ARG"  --keep-year  "$KEEPYEAR_ARG"
check_incompatible --keep-date  "$KEEPDATE_ARG"  --keep-month "$KEEPMONTH_ARG"
check_incompatible --keep-date  "$KEEPDATE_ARG"  --keep-day   "$KEEPDAY_ARG"
check_incompatible --keep-year  "$KEEPYEAR_ARG"  --keep-month "$KEEPMONTH_ARG"
check_incompatible --keep-year  "$KEEPYEAR_ARG"  --keep-day   "$KEEPDAY_ARG"
check_incompatible --keep-month "$KEEPMONTH_ARG" --keep-day   "$KEEPDAY_ARG"

[[ "$flag_conflicts" -ne 0 ]] && exit 1

# ──────────────────────────────────────────────
# RESOLVE ARGS

ANON_GIT_DATE="${DATE_ARG:-${ANON_GIT_DATE:-${DEFAULT_DATE}}}"
ANON_GIT_NAME="${NAME_ARG:-${ANON_GIT_NAME:-${DEFAULT_NAME}}}"
ANON_GIT_EMAIL="${EMAIL_ARG:-${ANON_GIT_EMAIL:-${DEFAULT_EMAIL}}}"
ANON_GIT_KEEPUSER="${KEEPUSER_ARG:-${ANON_GIT_KEEPUSER:-${DEFAULT_KEEPUSER}}}"
ANON_GIT_KEEPDATE="${KEEPDATE_ARG:-${ANON_GIT_KEEPDATE:-${DEFAULT_KEEPDATE}}}"
ANON_GIT_KEEPYEAR="${KEEPYEAR_ARG:-${ANON_GIT_KEEPYEAR:-${DEFAULT_KEEPYEAR}}}"
ANON_GIT_KEEPMONTH="${KEEPMONTH_ARG:-${ANON_GIT_KEEPMONTH:-${DEFAULT_KEEPMONTH}}}"
ANON_GIT_KEEPDAY="${KEEPDAY_ARG:-${ANON_GIT_KEEPDAY:-${DEFAULT_KEEPDAY}}}"
TARGET_COMMIT=$(git rev-parse "$TARGET_COMMIT")

# ──────────────────────────────────────────────────────────────────────
# CONFIRM

short_commit=$(git rev-parse --short "$TARGET_COMMIT")
printf 'Anonymizing commit: %s\n' "$short_commit"
printf 'Values that will be used:\n'
[[ $ANON_GIT_KEEPUSER == '0' ]] && printf '  Identity : %s <%s>\n' "${ANON_GIT_NAME}" "${ANON_GIT_EMAIL}"
[[ $ANON_GIT_KEEPDATE == '0' ]] && printf '  Date     : %s\n' "${ANON_GIT_DATE}"
printf '\n' >&2

if [[ "$NOCONFIRM_ARG" != '1' ]]; then
    read -p "Continue? (y/N) " -n 1 -r
    printf '\n'
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# ──────────────────────────────────────────────────────────────────────
# BACKUP BRANCH

if [[ "$NOBACKUP_ARG" != "1" ]]; then
    backup_branch="backup-anon-git-$(date +%Y%m%d-%H%M%S)"
    git branch "${backup_branch}"
    printf 'Created backup branch: %s\n\n' "${backup_branch}"
    printf 'Rewriting commit...\n\n'
fi

# ──────────────────────────────────────────────────────────────────────
# REWRITE LOGIC

git filter-repo --force --commit-callback "
    from datetime import datetime

    target = '${TARGET_COMMIT}'
    name  = '${ANON_GIT_NAME}'
    email = '${ANON_GIT_EMAIL}'
    date = '${ANON_GIT_DATE}'

    keepuser = ${ANON_GIT_KEEPUSER}
    keepdate = ${ANON_GIT_KEEPDATE}
    keepyear = ${ANON_GIT_KEEPYEAR}
    keepmonth = ${ANON_GIT_KEEPMONTH}
    keepday = ${ANON_GIT_KEEPDAY}

    if commit.original_id == target.encode():
        if keepuser != 1:
            commit.author_name = commit.committer_name = name.encode()
            commit.author_email = commit.committer_email = email.encode()

        if keepdate != 1:
            # date object
            dt = datetime.strptime(date, '%Y-%m-%d %H:%M:%S %z')
            ts = int(dt.timestamp())

            # timezone as bytes
            offset_seconds = int(dt.utcoffset().total_seconds())
            offset_hours = offset_seconds // 60
            offset_mins = offset_seconds % 60
            sign = '+' if offset_seconds >= 0 else '-'
            offset_bytes = ('%s%02d%02d' % (sign, offset_hours, offset_mins)).encode()

            # date formartted
            date = b'%d %s' % (ts, offset_bytes)
            commit.author_date = commit.committer_date = date
" >&2

# Refresh index if we rewrote HEAD
if [ "${TARGET_COMMIT}" = "$(git rev-parse HEAD)" ]; then
    git reset --quiet --soft HEAD@{1} 2>/dev/null || true
    git reset --quiet HEAD
fi

printf 'Done. Commit %s has been rewritten.\n' "$(git rev-parse --short "${TARGET_COMMIT}")"
