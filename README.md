# ANON GIT

AnonGit is a script to **anonymize** git commit authorship and timestamp.

Useful when you want to contribute to privacy-sensitive, anti-surveillance, or censorship-resistant open-source projects **without linking your real identity** to your contributions through commit metadata.

The script can:

- Anonymize entire git history
- Anonymize single commit
- Anonymize multiple commits
- Anonymize commits filtered by author/commiter, date range, or commit message
- Anonymize metadata using arbitrary values for user name, user email and date
- Anonymize just the timestamps (keep authorship) or the username (keep timestamp)
- Anonymize the timestamps partially: preserve commit year or month or day while anonymizing other information (hour & timezone)

## Why anonymize Git commits?

Many privacy & freedom-oriented projects prefer (or even require) contributors to avoid leaking personal metadata:

- **Internet anonymity**
  - Tor Browser
  - I2P
  - FreeNet
- **Private finace**
  - Monero
  - Bisq
  - Samourai Wallet
  - CoinJoin tools
- **Mobile OS**
  - GrapheneOS
  - CalyxOS
- **Communication protocols**
  - Simplex
  - Matrix
  - Briar
  - XMPP
- **Social network**
  - Nostr
  - Mastodon
  - Scuttlebutt
- **Privacy guides**
  - KYC Not Me (kycnot.me)
  - Digital Defense (digitaldefense.io)

(The list above is not meant to be a compilation of privacy tools, but merely examples of projects whose contributors may wish to stay anonymous).

Even when using Tor and throwaway GitHub accounts, your **commit timestamps** can still deanonymize you over time, especially when combined with contribution patterns, timezone hints, typing cadence in commit messages, etc. The scripts here help reduce that metadata footprint.

## Pre-requisites

Both scripts are based on `git filter-repo` (much faster & safer than `filter-branch`).

**You must have `git-filter-repo` installed:**

```bash
# Debian/Ubuntu
sudo apt install git-filter-repo

# Fedora
sudo dnf install git-filter-repo

# macOS (Homebrew)
brew install git-filter-repo

# or via pip (any platform)
pip install git-filter-repo
```

## Usage

This repository contains a script called `anon-git`, which relies upon `git
filter-repo`. Download it or copy-paste into a file. Execute them from inside
a git respository either directly `./anon-git.sh` or from your `$PATH`.

**For safety, the script creates a backup branch before rewriting history.

Rewrite **one commit** (author, committer, dates).

```bash
./anon-git.sh [OPTIONS] [commits]
```

**Default behavior**: anonymizes `HEAD`

### Options

```
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
```

**Priority order** (highest to lowest):

1. Command-line flags
2. Environment variables (`ANON_GIT_DATE`, `ANON_GIT_NAME`, `ANON_GIT_EMAIL`, `ANON_GIT_KEEPUSER`, `ANON_GIT_KEEPDATE`)
3. Hardcoded defaults

### Examples

```bash
# Anonymize current HEAD with defaults
./anon-git.sh

# Anonymize two commits ago
./anon-git.sh HEAD~2

# Explicit values + specific commit
./anon-git.sh --date "2024-01-01 00:00:00 +0000" \
                          --name "Jane Doe" \
                          --email "jane@anon.dev" \
                          8ddf55a

# Keep real name/email, only change date
./anon-git.sh --keep-user --date "2025-06-15T14:20:00Z"
```

More examples using built-in filters provided by `git` in order to pick a set of
commits matching the filter:

```bash
# Anonymize the last 10 commits using shell expansion (works in bash and zsh)
./anon-git.sh HEAD~{0..9}

# Anonymize commits within a specific date range
git log --format=%H after='2023-01-01' --before='2024-01-01' | xargs ./anon-git

# Anonymize commits where the commit author matches a pattern
git log --format=%H author='Frederic' | xargs ./anon-git

# Anonymize commits where the commit author matches a pattern
git log --format=%H author='Frederic' | xargs ./anon-git

# Anonymize commits where the commit message matches a message
git log --format=%H grep='Some regex to match the commit message' | xargs ./anon-git
```

### Using anonymize-git-commit as a post-commit hook

You can automatically anonymize **every new commit right after** you run `git commit` by installing the script as a **post-commit** hook. This rewrites only the just-created commit (HEAD) without affecting earlier history.

1. Go to your repository:
   ```bash
   cd your-repo
   ```

2. Create or edit the post-commit hook:
   ```bash
   mkdir -p .git/hooks
   nano .git/hooks/post-commit
   ```

3. Paste the following content (adjust paths/flags as needed):
   ```bash
   #!/usr/bin/env bash
   #
   # .git/hooks/post-commit - Automatically anonymize the just-made commit
   #

   # Exit on any error
   set -e

   # Path to your anonymize script (adjust if needed)
   SCRIPT="$PWD/anon-git.sh"

   if [ ! -x "$SCRIPT" ]; then
       echo "Error: anon-git.sh not found or not executable" >&2
       exit 1
   fi

   # Optional: skip anonymization for merge commits, fixup commits, etc.
   # (uncomment and adjust if desired)
   # if git log -1 --pretty=%s | grep -iqE '^(Merge|fixup|squash)'; then
   #     echo "Skipping anonymization for merge/fixup commit"
   #     exit 0
   # fi

   # Run anonymization on HEAD (the commit we just created)
   #
   # IMPORTANT: Customize flags/environment variables here before running it!
   "$SCRIPT" --no-confirm HEAD

   # Optional: show what changed
   echo "Last commit anonymized:"
   git --no-pager log -1 --pretty=fuller

   exit 0
   ```

4. Make it executable:
   ```bash
   chmod +x .git/hooks/post-commit
   ```

Now every `git commit` automatically triggers anonymization of that commit's author name, email, and dates (using your script's defaults, environment variables, or flags you hard-code in the hook).

**Important notes**:

- The hook rewrites the commit, changes its hash. If you already pushed, you'll need `git push --force-with-lease` afterward (dangerous on shared branches!)
- Best used on personal/feature branches you control
- To temporarily disable: `chmod -x .git/hooks/post-commit`
- Consider using environment variables (`export ANON_GIT_NAME="..."` etc.) instead of hard-coding flags in the hook

This gives seamless "anonymous-by-default" committing while still allowing manual overrides via normal `git commit --author=... --date=...` when needed.

## Important notes

- Backup branch is created with original commit history
- You can recover with `git reflog` / `git reset` if something goes wrong even if you use `--no-backup`
- `--keep-user` and `--keep-date` are useful for partial anonymization
- Timestamps must be in a format `git` understands (ISO 8601 with timezone recommended)

## Additional security notes

- AnonGit **remove metadata only** — it does **not** hide IP addresses, contribution timing correlations, writing style, code patterns, etc.
- For higher opsec, use anonymous accounts not tied to personal identity
- Consider squashing commits or using merge requests from anonymous remotes
- Beaware when you publish to public forges (GitHub, GitLab, Codeberg, ...)
