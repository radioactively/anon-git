# ANON GIT

AnonGit is a small set of shell scripts to help contributors **anonymize** their Git commit authorship and timestamps.

Useful when you want to contribute to privacy-sensitive, anti-surveillance, or censorship-resistant open-source projects **without linking your real identity** to your contributions through commit metadata.

## Why anonymize Git commits?

Many privacy & freedom-oriented projects prefer (or even require) contributors to avoid leaking personal metadata:

- **Network anonymity & censorship resistance**
  - Tor Browser
  - I2P
  - Lokinet
  - Briar
  - Cwtch Network
- **Private & untraceable finance / markets**
  - Monero
  - Bisq
  - Haveno
  - Samourai Wallet
  - Wasabi Wallet
  - JoinMarket
  - Robosats
- **Mobile & device privacy**
  - GrapheneOS
  - CalyxOS
  - /e/OS
  - DivestOS
- **Self-sovereignty, self-hosting & anti-surveillance tools**
  - Matrix & XMPP implementations
  - Nextcloud & ownCloud
  - Mullvad Browser & LibreWolf
  - Nym mixnet tools
  - Secure Scuttlebutt
  - F-Droid repositories
  - Privacy Guides translations & tooling

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

This repository two scripts to anonymize timestamps and author & commiter identity: `anonymize-git-commit.sh` and `anonymize-git-history`.

Download them or copy-paste into a file. Execute them from inside a git respository either directly `./anonymize-git-commit.sh` or from your `$PATH`.

**For safety, both scripts create a backup branch before rewriting history :-)**.

### 1. `anonymize-git-commit.sh`

Rewrite **one commit** (author, committer, dates).

```bash
./anonymize-git-commit.sh [OPTIONS] [commit]
```

**Default behavior**: anonymizes `HEAD`

**Options**

```
-h, --help                 Show help message and exit
--date        "ISO date"   Set author & committer date (example: "2025-03-10 13:37:00 +0000")
--name        "Full name"  Set author & committer name
--email       "Email"      Set author & committer email
--keep-user                Do not change name/email
--keep-date                Do not change dates
--no-confir
```

**Priority order** (highest to lowest):

1. Command-line flags
2. Environment variables (`ANON_GIT_DATE`, `ANON_GIT_NAME`, `ANON_GIT_EMAIL`, `ANON_GIT_KEEPUSER`, `ANON_GIT_KEEPDATE`)
3. Hardcoded defaults

**Examples**

```bash
# Anonymize current HEAD with defaults
./anonymize-git-commit.sh

# Anonymize two commits ago
./anonymize-git-commit.sh HEAD~2

# Explicit values + specific commit
./anonymize-git-commit.sh --date "2024-01-01 00:00:00 +0000" \
                          --name "Jane Doe" \
                          --email "jane@anon.dev" \
                          8ddf55a

# Keep real name/email, only change date
./anonymize-git-commit.sh --keep-user --date "2025-06-15T14:20:00Z"
```

### 2. `anonymize-git-history.sh`

**Rewrite the entire history** of the current branch.

**Warning**: rewrites history; force-push will be required (`git push --force-with-lease`)

```bash
./anonymize-git-history.sh [OPTIONS]
```

**Options**: same as `anonymize-git-commit.sh`

**Priority order**: same as `anonymize-git-commit.sh`

**Examples**

```bash
# Anonymize whole branch with defaults
./anonymize-git-history.sh

# Set uniform identity & date for all commits
./anonymize-git-history.sh --date "2024-06-01 12:00:00 +0000" \
                           --name "Anonymous" \
                           --email "anon@example.com"

# Keep original dates, only anonymize identity
./anonymize-git-history.sh --keep-date --name "John Smith" --email "js@anon.local"
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
   SCRIPT="$PWD/anonymize-git-commit.sh"

   if [ ! -x "$SCRIPT" ]; then
       echo "Error: anonymize-git-commit.sh not found or not executable" >&2
       exit 1
   fi

   # Optional: skip anonymization for merge commits, fixup commits, etc.
   # (uncomment and adjust if desired)
   # if git log -1 --pretty=%s | grep -iqE '^(Merge|fixup|squash)'; then
   #     echo "Skipping anonymization for merge/fixup commit"
   #     exit 0
   # fi

   # Run anonymization on HEAD (the commit we just created)
   # Customize flags/environment variables here:
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

- Both scripts create backup reflogs. You can recover with `git reflog` / `git reset` if something goes wrong
- `anonymize-git-history.sh` rewrites **all** commits reachable from current HEAD
- `--keep-user` and `--keep-date` are useful for partial anonymization
- Timestamps must be in a format `git` understands (ISO 8601 with timezone recommended)

## Security & Threat model notes

- These scripts **remove metadata only** — they do **not** hide IP addresses, contribution timing correlations, writing style, code patterns, etc.
- Use **Tor + fresh identity** when pushing to public forges (GitHub, GitLab, Codeberg, …)
- Consider squashing commits or using merge requests from anonymous remotes
- For highest opsec: use dedicated anonymous VM/container + Tor + throwaway forge account + these scripts
- **Never** commit private keys, passwords, personal emails, real names, or identifying strings — even with anonymized metadata

## ROADMAP

- [x] Add commit anonymization script
- [x] Add history anonymization script
- [x] Add option `--date` to set user date
- [x] Add option `--email` to set user email
- [x] Add option `--name` to set user name
- [x] Add option `--keep-user` to keep user name & email
- [x] Add option `--keep-date` to keep timestamps
- [ ] Add option `--preserve-year` to keep year in commit timestamp
- [ ] Add option `--preserve-month` to keep month in commit timestamp
- [ ] Add option `--preserve-day` to keep day in commit timestamp

**Note**: options `--keep-user`, `--kep-date`, `--preserve-year`, `--preserve-month` and `--preserve-day` may be useful for contribution statistics but provide less privacy.
