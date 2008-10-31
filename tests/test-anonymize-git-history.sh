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
DEFAULT_DATE=$(grep '^DEFAULT_DATE=' "$SCRIPT" | sed -e "s/DEFAULT_DATE='//" -e "s/'\$//")
DEFAULT_NAME=$(grep '^DEFAULT_NAME=' "$SCRIPT" | sed -e "s/DEFAULT_NAME='//" -e "s/'\$//")
DEFAULT_EMAIL=$(grep '^DEFAULT_EMAIL=' "$SCRIPT" | sed -e "s/DEFAULT_EMAIL='//" -e "s/'\$//")
COMMIT_COUNT=20
TEST_INDEX=0

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
      esac
  done
  expected_author="${expected_name} <${expected_email}>"

  cmd="./${SCRIPT_NAME} ${args[*]}"
  printf 'Running %s...\n' "$cmd"
  echo y | ./${SCRIPT_NAME} "${args[@]}" >/dev/null 2>&1
  LOG=$(git log --pretty=fuller --date=iso)

  author_matches=$(grep --count "^Author:\s\+${expected_author}" <<<"$LOG")
  commiter_matches=$(grep --count "^Commit:\s\+${expected_author}" <<<"$LOG")
  author_date_matches=$(grep --count "^AuthorDate:\s\+${expected_date}" <<<"$LOG")
  commiter_date_matches=$(grep --count "^CommitDate:\s\+${expected_date}" <<< "$LOG")

  errors=0
  if [[ "$author_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: author name & email not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$commiter_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: commiter name & email not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$author_date_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: author date not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$commiter_date_matches" -ne "$COMMIT_COUNT" ]]; then
    printf 'Error: commiter date not overwrriten\n'
    errors=$(( errors + 1 ))
  fi

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
  test_script --name 'John Doe'
  test_script --name 'John Doe' --email 'john@example.com'
  test_script --name 'John Doe' --email 'john@example.com' --date '2020-10-31 12:00:00 +0000'
  test_script --name 'John Doe' --date '2020-10-31 12:00:00 +0000'
  test_script --email 'john@example.com'
  test_script --email 'john@example.com' --date '2020-10-31 12:00:00 +0000'
  test_script --date '2020-10-31 12:00:00 +0000'
  cleanup
}

main
