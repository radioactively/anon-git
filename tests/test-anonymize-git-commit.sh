#!/usr/bin/env bash

# Assume anonymize-git-commit.sh is in the parent directory
SCRIPT_DIR=$(realpath "$(dirname "$0")/..")
SCRIPT_NAME=anonymize-git-commit.sh
SCRIPT=${SCRIPT_DIR}/${SCRIPT_NAME}

# Create temp dir to work on
TMP_DIR=$(mktemp -d /tmp/anon_git_test_hist.XXXXXX)
cd "$TMP_DIR" || exit 1
cp "$SCRIPT" .
chmod +x "./${SCRIPT_NAME}"

# Global variables shared among functions

COMMIT_COUNT=20
CURRENT_TEST_INDEX=0
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_ERRORS=0

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
  CURRENT_TEST_INDEX=$(( CURRENT_TEST_INDEX + 1 ))

  expected_name="${DEFAULT_NAME}"
  expected_email="${DEFAULT_EMAIL}"
  expected_date="${DEFAULT_DATE}"
  keep_user="${DEFAULT_KEEPUSER}"
  keep_date="${DEFAULT_KEEPDATE}"

  args=(--no-confirm)
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

  # Pick random commit
  random_index=$(( $(od -An -N2 -tu2 </dev/urandom) % (COMMIT_COUNT - 1) ))
  commit_hash=$(git rev-parse "HEAD~${random_index}")

  # store old logs (except commit to be modified)
  commit_format='%H %an <%aE> (%ai) %cn <%cE> (%ci)'
  OLD_AUTHOR=$(git show --format='%an <%ae> %cn <%ce>' "$commit_hash")
  OLD_DATE=$(git show --format='%ai %ci' "$commit_hash")
  OLD_COMMITS=$(git log --format="$commit_format" | grep --invert-match "$commit_hash" | sed 's/^[0-9a-f]\+//')

  # Run script
  cmd="./${SCRIPT_NAME} ${args[*]} HEAD~${random_index}"
  printf 'Running %s\n' "$cmd"
  ./${SCRIPT_NAME} "${args[@]}" "$commit_hash" >/dev/null 2>&1

  # store new logs (except modified commit)
  new_commit_hash=$(git rev-parse "HEAD~${random_index}")

  # store new logs for comparison
  NEW_AUTHOR=$(git show --format='%an <%ae> %cn <%ce>' "$new_commit_hash")
  NEW_DATE=$(git show --format='%ai %ci' "$new_commit_hash")
  NEW_COMMITS=$(git log --format="$commit_format" | grep --invert-match "$new_commit_hash" | sed 's/^[0-9a-f]\+//')
  NEW_COMMIT=$(git show --pretty=fuller --no-patch --date=iso "$new_commit_hash")

  # Check results

  ## Real values
  author_matches=$(grep --count "^Author:\s\+${expected_author}" <<<"$NEW_COMMIT")
  commiter_matches=$(grep --count "^Commit:\s\+${expected_author}" <<<"$NEW_COMMIT")
  author_date_matches=$(grep --count "^AuthorDate:\s\+${expected_date}" <<<"$NEW_COMMIT")
  commiter_date_matches=$(grep --count "^CommitDate:\s\+${expected_date}" <<< "$NEW_COMMIT")

  # check for erros
  errors=0

  # author & commiter check
  if [[ "$keep_user" -ne 1 && "$author_matches" -ne 1 ]]; then
    printf 'Error: author name & email not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_user" -ne 1 && "$commiter_matches" -ne 1 ]]; then
    printf 'Error: commiter name & email not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_user" -eq 1 && "$NEW_AUTHOR" != "$OLD_AUTHOR" ]]; then
    printf 'Error: flag --keep-user not respected\n'
    errors=$(( errors + 1 ))
  fi

  # date check
  if [[ "$keep_date" -ne 1 && "$author_date_matches" -ne 1 ]]; then
    printf 'Error: author date not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_date" -ne 1 && "$commiter_date_matches" -ne 1 ]]; then
    printf 'Error: commiter date not overwrriten\n'
    errors=$(( errors + 1 ))
  fi
  if [[ "$keep_date" -eq 1 && "$NEW_DATE" != "$OLD_DATE" ]]; then
    printf 'Error: flag --keep-date not respected\n'
    errors=$(( errors + 1 ))
  fi

  # other commmits check
  if [[ "$OLD_COMMITS" != "$NEW_COMMITS" ]]; then
    printf 'Error: other commits were affected!'
    errors=$(( errors + 1))
  fi

  # feedback
  if [[ "$errors" -eq 0 ]]; then
    TESTS_PASSED=$(( TESTS_PASSED + 1 ))
    printf 'Test %s passed.\n\n' "$CURRENT_TEST_INDEX"
  else
    TESTS_FAILED=$(( TESTS_FAILED + 1 ))
    printf 'Test %s failed with %s errors.\n\n' "$CURRENT_TEST_INDEX" "$errors"
  fi
  TOTAL_ERRORS=$(( TOTAL_ERRORS + errors ))
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
  printf 'Summary:\n%s tests passed\n%s tests failed\n%s total errors\n' "$TESTS_PASSED" "$TESTS_FAILED" "$TOTAL_ERRORS"
  cleanup
}

main
