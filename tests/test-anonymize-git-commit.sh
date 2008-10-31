#!/usr/bin/env bash

# Assume anonymize-git-history.sh is in the parent directory
SCRIPT_DIR=$(realpath "$(dirname "$0")/..")
SCRIPT_NAME=anonymize-git-commit.sh
SCRIPT=${SCRIPT_DIR}/${SCRIPT_NAME}

# Create temp dir
TMP_DIR=$(mktemp -d /tmp/anon_git_test_hist.XXXXXX)
cp "$SCRIPT" "$TMP_DIR"
cd "$TMP_DIR" || exit 1

# Init git repo
git init >/dev/null
git config --local user.name "Test User"
git config --local user.email "test@example.com"

# Make dummy commits
commit_count=20
for i in $(seq 1 "$commit_count"); do
  filename="file_${i}.txt"
  echo "This is file $i" >"$filename"
  git add "$filename" >/dev/null
  git commit -m "Add file $filename" >/dev/null
done

# Pick hand commit index
rand_commit=$(printf '%d\n' "$((1 + $(od -An -N2 -tu2 </dev/urandom) % (commit_count - 1)))")
commit_hash=$(git rev-parse "HEAD~${rand_commit}")

# Run script
echo y | bash ./${SCRIPT_NAME} "$commit_hash" >/dev/null 2>&1

# New commit hash
new_commit_hash=$(git rev-parse "HEAD~${rand_commit}")
LOG=$(git show --pretty=fuller --no-patch --date=iso "$new_commit_hash")

# Check results

## expected values
default_date=$(grep '^DEFAULT_DATE=' "$SCRIPT" | sed -e "s/DEFAULT_DATE='//" -e "s/'\$//")
default_name=$(grep '^DEFAULT_NAME=' "$SCRIPT" | sed -e "s/DEFAULT_NAME='//" -e "s/'\$//")
default_email=$(grep '^DEFAULT_EMAIL=' "$SCRIPT" | sed -e "s/DEFAULT_EMAIL='//" -e "s/'\$//")
expected_author="${default_name} <${default_email}>"
expected_date="${default_date}"

## Real values
author_matches=$(grep --count "^Author:\s\+${expected_author}" <<<"$LOG")
commiter_matches=$(grep --count "^Commit:\s\+${expected_author}" <<<"$LOG")
author_date_matches=$(grep --count "^AuthorDate:\s\+${expected_date}" <<<"$LOG")
commiter_date_matches=$(grep --count "^CommitDate:\s\+${expected_date}" <<< "$LOG")

## Error feedback if any
errors=0
if [[ "$author_matches" -ne 1 ]]; then
  printf 'Error: author name & email not overwrriten\n'
  errors=$(( errors + 1 ))
fi
if [[ "$commiter_matches" -ne 1 ]]; then
  printf 'Error: commiter name & email not overwrriten\n'
  errors=$(( errors + 1 ))
fi
if [[ "$author_date_matches" -ne 1 ]]; then
  printf 'Error: author date not overwrriten\n'
  errors=$(( errors + 1 ))
fi
if [[ "$commiter_date_matches" -ne 1 ]]; then
  printf 'Error: commiter date not overwrriten\n'
  errors=$(( errors + 1 ))
fi


## Show results.
if [[ "$errors" -eq 0 ]]; then
  printf 'Test passed.\n'
else
  printf "Test failed with %s errors.\n" "$errors"
fi

# Cleanup
cd - >/dev/null || exit 0
rm -rf "$TMP_DIR"
exit
