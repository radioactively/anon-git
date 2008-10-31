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
DEFAULT_ENTIREHISTORY='0'
DEFAULT_COMMIT=$(git rev-parse HEAD)

# ──────────────────────────────────────────────────────────────────────
# HELP
show_help() {
    cat << EOF
Anonymizes git commit metadata.

Usage:
  ./anon-git.sh [OPTIONS] [commits]

Options:
  -h, --help                      Show this help message and exit
  --date        ISO Date          Date to use (example: "2025-03-10 13:37:00 +0000")
  --name        "Full name"       Name to use for author & committer
  --email       "Email address"   Email to use for author & committer
  --keep-user                     Do not change user name or author
  --keep-date                     Do not change date
  --keep-year                     Do not change commit year
  --keep-month                    Do not change commit month (and year)
  --keep-day                      Do not change commit day (and year and month)
  --no-confirm                    Do not prompt for confirmation
  --no-backup                     Do not create backup branch
  --entire-history                Rewrite entire history and not a single commit

Arguments:
  commit(s)               Commit(s) to anonymize (can be: hash, HEAD~3, branch, tag, ...)
                          If omitted, defaults to HEAD
                          If more than one, it should be a commit hash.

Priority (highest to lowest):
  1. Command-line flags (--date, --name, --email, --keep-user, --keep-date)
  2. Environment variables (ANON_GIT_DATE, ANON_GIT_NAME, ANON_GIT_EMAIL, ANON_GIT_KEEPUSER, ANON_GIT_KEEPDATE)
  3. Hardcoded defaults (${DEFAULT_NAME} <${DEFAULT_EMAIL}>)

Examples:
  ./anon-git.sh
  ./anon-git.sh HEAD~2
  ./anon-git.sh --date "2024-01-01 00:00:00 +0000" --name "Jane Doe" --email "jane@anon.dev" 8ddf55
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
ENTIREHISTORY_ARG=""
COMMIT_ARG=""
COMMITS_ARG=()

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
        --entire-history)
            ENTIREHISTORY_ARG='1'
            shift
            ;;
        --commit)
            COMMIT_ARG="$2"
            shift 2
            ;;
        -*)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
        *)
            if ! git rev-parse --quiet --verify "${1}^{commit}" >/dev/null 2>&1; then
                printf 'Error: Commit "%s" does not exist or is not a commit object.\n' "${1}" >&2
                exit 1
            fi
            ref=$(git rev-parse "$1")
            COMMITS_ARG=("${COMMITS_ARG[@]}" "$ref")
            COMMIT_ARG="${COMMITS_ARG[*]}"
            shift
            ;;
    esac
done

# ──────────────────────────────────────────────
# VALIDATE ARGS

flag_errors=0

# validate conflicting flags
check_incompatible() {
    local flag1="$1"
    local flag2="$3"
    local value1="$2"
    local value2="$4"
    if [[ -n "$value1" && -n "$value2" ]]; then
        printf 'Error: flags %s and %s cannot be used together\n' "$flag1" "$flag2" >&2
        flag_errors=1
    fi
}

check_incompatible --keep-user  "$KEEPUSER_ARG"  --name           "$NAME_ARG"
check_incompatible --keep-user  "$KEEPUSER_ARG"  --email          "$EMAIL_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-date      "$KEEPDATE_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-year      "$KEEPYEAR_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-month     "$KEEPMONTH_ARG"
check_incompatible --date       "$DATE_ARG"      --keep-day       "$KEEPDAY_ARG"
check_incompatible --keep-date  "$KEEPDATE_ARG"  --keep-year      "$KEEPYEAR_ARG"
check_incompatible --keep-date  "$KEEPDATE_ARG"  --keep-month     "$KEEPMONTH_ARG"
check_incompatible --keep-date  "$KEEPDATE_ARG"  --keep-day       "$KEEPDAY_ARG"
check_incompatible --keep-year  "$KEEPYEAR_ARG"  --keep-month     "$KEEPMONTH_ARG"
check_incompatible --keep-year  "$KEEPYEAR_ARG"  --keep-day       "$KEEPDAY_ARG"
check_incompatible --keep-month "$KEEPMONTH_ARG" --keep-day       "$KEEPDAY_ARG"
check_incompatible --commit     "$COMMIT_ARG"    --entire-history "$ENTIREHISTORY_ARG"

[[ "$flag_errors" -ne 0 ]] && exit 1

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
ANON_GIT_ENTIREHISTORY="${ENTIREHISTORY_ARG:-${ANON_GIT_ENTIREHISTORY:-${DEFAULT_ENTIREHISTORY}}}"
ANON_GIT_COMMIT="${COMMIT_ARG:-${DEFAULT_COMMIT}}"

# ──────────────────────────────────────────────────────────────────────
# CONFIRMATION

if [[ -z "$ENTIREHISTORY_ARG" ]]; then
    short_commit=$(echo "$ANON_GIT_COMMIT" | xargs -n 1 git rev-parse --short | tr '\n' ' ')
    printf 'Anonymizing commit(s): %s\n' "$short_commit"
fi
if [[ -n "$ENTIREHISTORY_ARG" ]]; then
    printf 'Anonymizing entire history!\n'
fi
if [[ -n "$KEEPUSER_ARG" ]]; then
    printf 'Using identity: %s <%s>\n' "${ANON_GIT_NAME}" "${ANON_GIT_EMAIL}"
fi
if [[ -n "$KEEPDATE_ARG" ]]; then
    printf 'Using date: %s\n' "${ANON_GIT_DATE}"
fi
if [[ -n "$KEEPYEAR_ARG" ]]; then
    printf 'Using commit date year (anonymizing only month, day, time and tz).\n'
fi
if [[ -n "$KEEPMONTH_ARG" ]]; then
    printf 'Using commit date year and month (anonymizing only day, time and tz).\n'
fi
if [[ -n "$KEEPDAY_ARG" ]]; then
    printf 'Using commit date year, month and day (anonymizing only time and tz).\n'
fi
printf '\n'

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
# CLEAN CACHE

# git-filter-repo stores metadata in .git/filter-repo/ after the first run (to
# speed up certain operations and support things like incremental/incremental
# filtering). When you run it again, it tries to reuse that metadata, but under
# some conditions (particularly if the previous filtering pruned certain
# refs/objects or if the repo state changed in subtle ways), the assumption in the
# code breaks and it hits this assertion.
#
# This a known bug in git-filter-repo that can occur when you run the tool multiple
# times on the same repository (especially if you ran it once successfully, then
# tried again or with slightly different options).
#
# To avoid this bug, we remove cached metadata, which may cause trouble while
# anonymizing the git history, for example, when using the script as git hook.
if [[ -d "$PWD/.git/filter-repo" ]]; then
    rm -rf "$PWD/.git/filter-repo"
fi

# ──────────────────────────────────────────────────────────────────────
# REWRITE LOGIC

export TZ=UTC
git filter-repo --force --commit-callback "
    from datetime import datetime, timedelta, timezone

    name  = '${ANON_GIT_NAME}'
    email = '${ANON_GIT_EMAIL}'
    date = '${ANON_GIT_DATE}'
    target_commits = [c.encode() for c in '${ANON_GIT_COMMIT}'.split()]

    #f = open('/dev/stderr', 'w')
    #print(commit.original_id in target_commits, file=f)
    #print(target_commits, file=f)
    #f.close()

    keepuser = ${ANON_GIT_KEEPUSER}
    keepdate = ${ANON_GIT_KEEPDATE}
    keepyear = ${ANON_GIT_KEEPYEAR}
    keepmonth = ${ANON_GIT_KEEPMONTH}
    keepday = ${ANON_GIT_KEEPDAY}

    if ${ANON_GIT_ENTIREHISTORY} or commit.original_id in target_commits:
        if keepuser != 1:
            commit.author_name = commit.committer_name = name.encode()
            commit.author_email = commit.committer_email = email.encode()

        if keepdate != 1:
            if keepyear or keepmonth or keepday:
                unix_ts, offset = commit.author_date.decode().split()

                # handle timezone offset
                sign = 1 if offset.startswith('+') else -1
                offset = offset.replace('+', '').replace('-', '')
                if len(offset) == 4:
                    hours   = int(offset[:2])
                    minutes = int(offset[2:])
                    seconds = 0
                elif len(offset) == 6:
                    hours   = int(offset[:2])
                    minutes = int(offset[2:4])
                    seconds = int(offset[4:])
                else:
                    raise ValueError('unsupported timezone format')
                tz_offset = timedelta(hours=hours, minutes=minutes, seconds=seconds)
                tz = timezone(sign * tz_offset)

                # create date object
                ts = float(unix_ts)
                dt = datetime.fromtimestamp(ts, tz=tz)
                dt = datetime.strptime('%d-%d-%d' % (dt.year, dt.month, dt.day), '%Y-%m-%d')

                # anonymize date object
                dt =  dt.replace(hour=0, minute=0, second=0)
                if keepyear or keepmonth:
                    dt = dt.replace(day=1)
                if keepyear:
                    dt = dt.replace(month=1)

                # timestamp and offset of anonymized object
                ts = dt.timestamp()
                offset = '+0000'
            else:
                dt = datetime.strptime(date, '%Y-%m-%d %H:%M:%S %z')
                ts = int(dt.timestamp())

                # handle timezone
                if dt.utcoffset():
                    offset_seconds = int(dt.utcoffset().total_seconds())
                    offset_hours = offset_seconds // 60
                    offset_mins = offset_seconds % 60
                    offset_sign = '+' if offset_seconds >= 0 else '-'
                    offset = '%s%02d%02d' % (offset_sign, offset_hours, offset_mins)
                else:
                    offset = '+0000'

            # date formartted
            date_as_bytes = b'%d %s' % (ts, offset.encode())
            commit.author_date = commit.committer_date = date_as_bytes
" --refs HEAD >&2

printf 'Done. History has been rewritten.\n'
