#!/usr/bin/env bash

set -euo pipefail

# Assume anonymize-git-history.sh is in the parent directory
SCRIPT_DIR=$(realpath "$(dirname $0)/..")
SCRIPT_NAME=anonymize-git-history.sh
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
for i in $(seq 1 5); do
  filename="file_${i}.txt"
  echo "This is file $i" >"$filename"
  git add "$filename" >/dev/null
  git commit -m "Add file $filename" >/dev/null
done

# run script
echo y | bash ./${SCRIPT_NAME} >/dev/null 2>&1

# Check new log
NEW_LOG=$(git log --pretty=fuller --date=iso)

# Verify changes
if [[ $NEW_LOG == *'Satoshi Nakamoto'* ]] && [[ $NEW_LOG == *'satoshi@gmx.com'* ]] && [[ $NEW_LOG == *'2008-10-31'* ]]; then
  echo "Test passed: history anonymized."
else
  echo "Test failed."
fi

# Cleanup
cd -
rm -rf "$TMP_DIR"
