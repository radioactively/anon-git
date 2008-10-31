#!/usr/bin/env bash

# Assume anonymize-git-history.sh is in the parent directory
SCRIPT_DIR=$(realpath "$(dirname "$0")/..")
SCRIPT_NAME=anonymize-git-history.sh
SCRIPT=${SCRIPT_DIR}/${SCRIPT_NAME}

# Create temp dir to work on
TMP_DIR=$(mktemp -d /tmp/anon_git_test_hist.XXXXXX)
cd "$TMP_DIR" || exit 1
cp "$SCRIPT" .
chmod +x "./${SCRIPT_NAME}"

# Global variables shared among functions
COMMIT_COUNT=20
TEST_INDEX=0
DEFAULT_DATE=$(grep '^DEFAULT_DATE=' "$SCRIPT" | sed -e "s/DEFAULT_DATE='//" -e "s/'\$//")
DEFAULT_NAME=$(grep '^DEFAULT_NAME=' "$SCRIPT" | sed -e "s/DEFAULT_NAME='//" -e "s/'\$//")
DEFAULT_EMAIL=$(grep '^DEFAULT_EMAIL=' "$SCRIPT" | sed -e "s/DEFAULT_EMAIL='//" -e "s/'\$//")
DEFAULT_KEEPUSER=$(grep '^DEFAULT_KEEPUSER=' "$SCRIPT" | sed -e "s/DEFAULT_KEEPUSER='//" -e "s/'\$//")
DEFAULT_KEEPDATE=$(grep '^DEFAULT_KEEPDATE=' "$SCRIPT" | sed -e "s/DEFAULT_KEEPDATE='//" -e "s/'\$//")

# ──────────────────────────────────────────────────────────────────────

init_repo() {
  git init >/dev/null
  git config --local user.name "Test User"
  git config --local user.email "test@example.com"
  for i in $(seq 1 "$COMMIT_COUNT"); do
    filename="file_${i}.txt"
    echo "This is file $i" >"$filename"
    git add "$filename" >/dev/null
    git commit -m "Add file $filename" >/dev/null
  done
}

test_script() {
  TEST_INDEX=$(( TEST_INDEX + 1 ))

  expected_name="${DEFAULT_NAME}"
  expected_email="${DEFAULT_EMAIL}"
  expected_date="${DEFAULT_DATE}"
  keep_user="${DEFAULT_KEEPUSER}"
  keep_date="${DEFAULT_KEEPDATE}"

  args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date)
        expected_date="$2"
        args=("${args[@]}" --date "$2")
        shift 2
        ;;
      --name)
        expected_name="$2"
        args=("${args[@]}" --name "$2")
        shift 2
        ;;
      --email)
        expected_email="$2"
        args=("${args[@]}" --email "$2")
        shift 2
        ;;
      --keep-user)
        keep_user='1'
        args=("${args[@]}" --keep-user)
        shift
        ;;
      --keep-date)
        keep_date='1'
        args=("${args[@]}" --keep-date)
        shift
        ;;
      *)
        printf 'Unexpected argument in test_script\n'
        exit 1
        ;;
    esac
  done
  expected_author="${expected_name} <${expected_email}>"

  # store old logs for comparison
  OLDLOG_DATE=$(git log --date=iso --format='%ai %ci')
  OLDLOG_AUTHOR=$(git log --format='%an <%ae> %cn <%ce>')

  # run script
  cmd="./${SCRIPT_NAME} ${args[*]}"
  printf 'Running %s...\n' "$cmd"
  echo y | ./${SCRIPT_NAME} "${args[@]}" >/dev/null 2>&1

  # store new logs for comparison
  NEWLOG=$(git log --pretty=fuller --date=iso)
  NEWLOG_DATE=$(git log --date=iso --format='%ai %ci')
  NEWLOG_AUTHOR=$(git log --format='%an <%ae> %cn <%ce>')

  # expected matches
  author_matches=$(grep --count "^Author:\s\+${expected_author}" <<<"$NEWLOG")
  commiter_matches=$(grep --count "^Commit:\s\+${expected_author}" <<<"$NEWLOG")
  author_date_matches=$(grep --count "^AuthorDate:\s\+${expected_date}" <<<"$NEWLOG")
  commiter_date_matches=$(grep --count "^CommitDate:\s\+${expected_date}" <<< "$NEWLOG")

  # check for errors
  errors=0

  # author & commiter check
  if [[ "$keep_user" != '1' && "$author_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: author name & email not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_user" != 1 && "$commiter_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: commiter name & email not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_user" == '1' && "$OLDLOG_AUTHOR" != "$NEWLOG_AUTHOR" ]]; then
    printf 'Error: flag --keep-user failed\n'
    errors=$(( errors + 1 ))
  fi

  # date check
  if [[ "$keep_date" != 1 && "$author_date_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: author date not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_date" != 1 && "$commiter_date_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: commiter date not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_date" == '1' && "$OLDLOG_DATE" != "$NEWLOG_DATE" ]]; then
    printf 'Error: flag --keep-date failed\n'
    errors=$(( errors +1 ))
  fi

  # feeback
  if [[ "$errors" -eq 0 ]]; then
    printf 'Test %s passed.\n\n' "$TEST_INDEX"
  else
    printf 'Test %s failed with %s errors.\n' "$TEST_INDEX" "$errors"
  fi
}

cleanup() {
  cd - >/dev/null || exit 0
  rm -rf "$TMP_DIR"
}

main() {
  init_repo
  test_script
  test_script --name 'Test 1'
  test_script --name 'Test 2' --email 'test2@example.com'
  test_script --name 'Test 3' --email 'test3@example.com' --date '2020-01-01 00:03:03 +0000'
  test_script --name 'Test 4' --date '2020-01-01 00:04:04 +0000'
  test_script --email 'test5@example.com'
  test_script --email 'test6@example.com' --date '2020-10-31 00:06:06 +0000'
  test_script --date '2020-01-01 00:07:07 +0000'
  test_script --keep-date
  test_script --keep-date --name 'Test 8'
  test_script --keep-date --name 'Test 9' --email 'test9@example.com'
  test_script --keep-user
  test_script --keep-user --date '2020-01-01 00:10:10 +0000'
  cleanup
}

main
