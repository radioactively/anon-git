#!/usr/bin/env bash

SCRIPT_DIR=$(realpath "$(dirname "$0")/..")

# Creates a temp directory to work on
TMP_DIR=$(mktemp -d /tmp/anon_git_test.XXXXXX)
cd "$TMP_DIR" || exit 1

# copy scripts and make them executable
cp $SCRIPT_DIR/*.sh "$TMP_DIR" || exit 1
chmod +x "$TMP_DIR"/*.sh

# init git repo
COMMIT_COUNT=20
git init >/dev/null
git config --local user.name "Test User"
git config --local user.email "test@example.com"
for i in $(seq 1 "$COMMIT_COUNT"); do
  filename="file_${i}.txt"
  echo "This is file $i" >"$filename"
  git add "$filename" >/dev/null
  git commit -m "Add file $filename" >/dev/null
done

# print directory and exit
pwd
exit
