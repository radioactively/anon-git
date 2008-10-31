#!/bin/bash

set -euo pipefail

# Assume anonymize-git-history.sh is in the parent directory
SCRIPT="../anonymize-git-history.bash"

# Create temp dir
TMP_DIR=$(mktemp -d /tmp/git_test_hist.XXXXXX)
cp "$SCRIPT" "$TMP_DIR"
cd "$TMP_DIR" || exit 1

# Init git repo
git init
git config --local user.name "Test User"
git config --local user.email "test@example.com"

# Make dummy commits
for i in $(seq 1 5); do
  filename="file_${i}.txt"
  echo "This is file $i" > "$filename"
  git add "$filename" > /dev/null
  git commit -m "Add file $filename" > /dev/null
done

# run script
yes | bash ./anonymize-git-history.bash 2>/dev/null

# Check new log
NEW_LOG=$(git log --pretty=fuller)

# Verify changes
if [[ $NEW_LOG == *'Satoshi Nakamoto'* ]] && [[ $NEW_LOG == *'satoshi@gmx.com'* ]] && [[ $NEW_LOG == *'2008-10-31'* ]]; then
  echo "Test passed: History anonymized."
else
  echo "Test failed."
fi

# Cleanup
cd -
rm -rf "$TMP_DIR"

echo "Cleanup done."
