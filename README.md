# wt - Git Worktree Manager

A command-line tool for managing git worktrees with optional Laravel Herd integration. Work on multiple branches simultaneously without stashing or switching.

**Framework-agnostic by design** - The core `wt` tool handles git worktree operations only. All framework-specific setup (Laravel, Node.js, etc.) is handled via customisable lifecycle hooks. Install the example hooks for Laravel projects, or create your own for any framework.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/dannyharding10/wt-worktree-manager.git ~/Projects/wt-worktree-manager

# Run the installer
cd ~/Projects/wt-worktree-manager && ./install.sh

# Start a new terminal, then verify
wt --version
wt doctor
```

## Table of Contents

- [What are Git Worktrees?](#what-are-git-worktrees)
- [The Golden Rule](#️-the-golden-rule-one-branch-per-worktree)
- [Installation](#installation)
- [Configuration](#configuration)
- [Getting Started](#getting-started)
- [Commands Reference](#commands-reference)
- [Worktree Templates](#worktree-templates)
- [Repository Structure](#repository-structure)
- [Testing](#testing)
- [Developer Guide](#developer-guide)
- [Security](#security)
- [Common Workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)
- [Using with Claude Code](#using-wt-with-claude-code)

---

## What are Git Worktrees?

Normally, you have one working directory per repository. If you're working on a feature and need to fix a bug on another branch, you have to stash your changes, switch branches, fix the bug, switch back, and unstash.

**With worktrees**, you can have multiple branches checked out at the same time, each in its own directory:

```bash
~/Herd/
├── myapp.git/              # Bare repo (stores all git data)
├── myapp--staging/         # Worktree for staging branch
├── myapp--feature-login/   # Worktree for feature/login branch
└── myapp--bugfix-123/      # Worktree for bugfix/123 branch
```

Each worktree is a fully functional working directory with its own `.env`, `vendor/`, `node_modules/`, etc. You can have them all running simultaneously with different URLs in Laravel Herd.

## ⚠️ The Golden Rule: One Branch Per Worktree

**Each worktree is the permanent home for ONE specific branch.** The directory name tells you which branch belongs there.

This is the most important thing to understand about worktrees. If you break this rule, things get confusing fast.

### ❌ DON'T: Switch branches inside a worktree

```bash
# You're in scooda--feature-login worktree
cd ~/Herd/scooda--feature-login

# DON'T DO THIS:
git checkout staging                    # ❌ Wrong!
git checkout feature/other-thing        # ❌ Wrong!
git switch main                         # ❌ Wrong!
```

**Also avoid switching branches via GUI tools** (GitKraken, SourceTree, VS Code Git panel, etc.) when you have a worktree open. The GUI doesn't know about the worktree naming convention.

**Why this breaks things:**
- The directory `scooda--feature-login` now contains the `staging` branch
- The directory name is now misleading
- `wt` commands may behave unexpectedly
- You might accidentally commit to the wrong branch
- `wt status` will show a mismatch warning

### ✅ DO: Use wt commands to work on different branches

```bash
# Want to work on a different branch? Create/switch to its worktree:
cd "$(wt switch scooda)"                # Pick with fzf
cd "$(wt switch scooda staging)"        # Go to staging worktree
cd "$(wt cd scooda feature/payments)"   # Navigate to specific worktree

# Need a worktree for a new branch? Create one:
wt add scooda feature/new-thing

# Done with a branch? Remove its worktree:
wt rm scooda feature/old-thing
```

### ✅ DO: Use git commands that don't change the checked-out branch

These are all safe inside any worktree:

```bash
# Safe git operations (don't change which branch is checked out):
git status                              # ✅ Check status
git add / git commit                    # ✅ Make commits
git push / git pull                     # ✅ Sync with remote
git stash / git stash pop               # ✅ Stash changes
git log / git diff                      # ✅ View history
git rebase origin/staging               # ✅ Rebase (or use: wt sync)
git merge --no-ff feature/x             # ✅ Merge another branch in
git cherry-pick abc123                  # ✅ Cherry-pick commits
git show other-branch:file.php         # ✅ View file from another branch
git diff staging..HEAD                  # ✅ Compare branches
```

### What about the staging worktree?

The staging worktree (`scooda--staging`) should **always** have the `staging` branch checked out. The same rules apply:

```bash
# In the staging worktree, you can:
git pull                                # ✅ Get latest staging
git merge --no-ff feature/done          # ✅ Merge a feature in
git push                                # ✅ Push to remote

# But don't:
git checkout feature/something          # ❌ Don't switch branches here either
```

If you need to look at or work on a feature, switch to that feature's worktree (or create one).

### Quick mental model

Think of each worktree directory as a **dedicated workspace** for one branch:

| Directory | Branch | Purpose |
|-----------|--------|---------|
| `scooda--staging` | `staging` | Integration testing, merges |
| `scooda--feature-login` | `feature/login` | Login feature development |
| `scooda--bugfix-cart` | `bugfix/cart` | Cart bug fix |

You don't "switch branches" - you **switch worktrees**. Each branch has its own directory, its own editor window, its own browser tab, its own database.

### If you accidentally switched branches

If you've already run `git checkout` inside a worktree, `wt status` and `wt ls` will warn you:

```text
⚠ Branch/Directory Mismatches Detected:
  scooda--feature-login
    Current branch:  staging
    Expected dir:    scooda--staging
    Fix: Checkout correct branch or recreate worktree
```

**To fix it:**

```bash
# Option 1: Checkout the correct branch back
cd ~/Herd/scooda--feature-login
git checkout feature/login              # Put the right branch back

# Option 2: If you've made commits on the wrong branch,
#           you may need to cherry-pick or reset
```

## Installation

### Using the Installer (Recommended)

```bash
# Clone the repository
git clone https://github.com/dannyharding10/wt-worktree-manager.git ~/Projects/wt-worktree-manager

# Run the installer
cd ~/Projects/wt-worktree-manager
./install.sh
```

The installer will:
1. Check requirements (git, zsh, and optional tools)
2. Create symlink at `/usr/local/bin/wt`
3. Install zsh completions to Homebrew's site-functions
4. Create `~/.wtrc` config file (if it doesn't exist)
5. Create `~/.wt/hooks/` directory structure for lifecycle hooks
6. Install example hooks (interactive choice for existing installs)

Open a **new terminal** after installation for changes to take effect.

### Installer Options

The installer is **idempotent** - you can run it again to update or install new example hooks.

```bash
# Interactive mode (default) - prompts when hooks already exist
./install.sh

# Merge mode - add new example hooks, keep your existing ones
./install.sh --merge

# Overwrite mode - replace all hooks with examples (backs up existing)
./install.sh --overwrite

# Skip hooks - don't install or modify any hooks
./install.sh --skip-hooks

# Quiet mode - minimal output
./install.sh --quiet

# Show help
./install.sh --help
```

**Hook installation modes:**

| Mode | Behaviour |
|------|-----------|
| Interactive | Fresh install: installs all examples. Existing hooks: prompts for choice |
| `--merge` | Only copies new example hooks, preserves your existing hooks |
| `--overwrite` | Backs up existing hooks to `~/.wt/hooks.backup.<timestamp>/`, then installs all examples |
| `--skip-hooks` | Doesn't touch hooks at all |

### What Gets Installed

| Location | Purpose |
|----------|---------|
| `/usr/local/bin/wt` | Main executable (symlink to repo) |
| `/opt/homebrew/share/zsh/site-functions/_wt` | Tab completions (symlink to repo) |
| `~/.wtrc` | Your configuration file |
| `~/.wt/hooks/` | Lifecycle hooks directory |

Because the installed files are symlinks, pulling updates to the repo automatically updates the tool.

### Manual Installation

If you prefer not to use the installer:

```bash
# Clone the repo
git clone https://github.com/dannyharding10/wt-worktree-manager.git ~/Projects/wt-worktree-manager

# Symlink the script
sudo ln -sf ~/Projects/wt-worktree-manager/wt /usr/local/bin/wt

# Symlink completions (Apple Silicon Mac)
ln -sf ~/Projects/wt-worktree-manager/_wt /opt/homebrew/share/zsh/site-functions/_wt

# Create config
cp ~/Projects/wt-worktree-manager/.wtrc.example ~/.wtrc

# Create hooks directory
mkdir -p ~/.wt/hooks/post-add.d
```

### Install fzf (Recommended)

fzf enables interactive branch selection with fuzzy search:

```bash
brew install fzf
```

### Uninstalling

```bash
cd ~/Projects/wt-worktree-manager
./uninstall.sh
```

This removes symlinks but preserves your config (`~/.wtrc`), hooks (`~/.wt/`), repositories, and worktrees.

### Tab Completion

After installation, tab completion works automatically:

```bash
wt pu<Tab>             # completes to 'pull' or 'pull-all'
wt pull sc<Tab>        # completes to 'scooda'
wt pull scooda f<Tab>  # completes to available branches
```

## Configuration

### Config file

Create `~/.wtrc` with your preferences:

```bash
# Where your Herd sites live
HERD_ROOT=/Users/yourname/Herd

# Default base branch for new worktrees
DEFAULT_BASE=origin/staging

# Editor to open with 'wt code' (cursor, code, zed, etc.)
DEFAULT_EDITOR=cursor

# Database connection (for auto-creating databases)
DB_HOST=127.0.0.1
DB_USER=root
DB_PASSWORD=
DB_CREATE=true  # Set to 'false' to disable auto-creation

# Database backup on removal
DB_BACKUP=true  # Set to 'false' to disable backups
DB_BACKUP_DIR="$HOME/Code/Project Support/Worktree/Database/Backup"

# Protected branches (require -f to remove)
PROTECTED_BRANCHES="staging main master"
```

You can also create `$HERD_ROOT/.wtconfig` for project-specific settings.

### Environment variables

These can be set in your shell or config file:

| Variable | Default | Description |
|----------|---------|-------------|
| `HERD_ROOT` | `$HOME/Herd` | Directory containing your sites |
| `WT_BASE_DEFAULT` | `origin/staging` | Default branch for new worktrees |
| `WT_EDITOR` | `cursor` | Editor for `wt code` command |
| `WT_CONFIG` | `~/.wtrc` | Path to config file |
| `WT_DB_HOST` | `127.0.0.1` | MySQL host for database operations |
| `WT_DB_USER` | `root` | MySQL user for database operations |
| `WT_DB_PASSWORD` | (empty) | MySQL password for database operations |
| `WT_DB_CREATE` | `true` | Auto-create database on `wt add` |
| `WT_DB_BACKUP` | `true` | Backup database on `wt rm` |
| `WT_DB_BACKUP_DIR` | `~/Code/Project Support/Worktree/Database/Backup` | Backup directory |
| `WT_PROTECTED_BRANCHES` | `staging main master` | Space-separated list of protected branches |
| `WT_HOOKS_DIR` | `~/.wt/hooks` | Directory for hook scripts |
| `WT_URL_SUBDOMAIN` | (empty) | Optional subdomain prefix (e.g., `api` → `api.feature.test`) |

### Hooks

Hooks allow you to run custom scripts at various points in the worktree lifecycle. Create executable scripts in `~/.wt/hooks/`:

| Hook | When it runs | Can abort? |
|------|--------------|------------|
| `pre-add` | Before worktree creation | Yes |
| `post-add` | After worktree creation | No |
| `pre-rm` | Before worktree removal | Yes |
| `post-rm` | After worktree removal | No |
| `post-pull` | After `wt pull` succeeds | No |
| `post-sync` | After `wt sync` succeeds | No |

**Available environment variables in hooks:**

| Variable | Description |
|----------|-------------|
| `WT_REPO` | Repository name |
| `WT_BRANCH` | Branch name |
| `WT_PATH` | Worktree directory path |
| `WT_URL` | Application URL |
| `WT_DB_NAME` | Database name |

**Example: post-add hook**

```bash
#!/bin/bash
# ~/.wt/hooks/post-add

echo "Setting up $WT_BRANCH..."
cd "$WT_PATH"
npm ci
npm run build
php artisan migrate
```

**Example: pre-rm hook (with abort)**

```bash
#!/bin/bash
# ~/.wt/hooks/pre-rm

# Prevent removal if there are uncommitted changes
cd "$WT_PATH"
if ! git diff --quiet; then
    echo "ERROR: Uncommitted changes in $WT_BRANCH"
    exit 1  # Non-zero exit aborts the removal
fi
```

**Multiple hooks:** Create a `.d` directory (e.g., `~/.wt/hooks/post-add.d/`) with numbered scripts:

```text
~/.wt/hooks/post-add.d/
├── 01-npm-install.sh
├── 02-build-assets.sh
└── 03-run-migrations.sh
```

**Repo-specific hooks:** Create subdirectories matching repo names for hooks that only run for specific repositories:

```text
~/.wt/hooks/post-add.d/
├── 01-npm-install.sh       # Global - runs for ALL repos
├── 02-build-assets.sh      # Global
├── scooda/                 # Only runs for 'scooda' repo
│   └── 01-import-ai.sh
└── myapp/                  # Only runs for 'myapp' repo
    └── 01-seed-database.sh
```

Execution order: global hooks run first (alphabetically), then repo-specific hooks.

**Security:** Hooks are verified before execution - they must be owned by the current user and not be world-writable.

## Getting Started

### Setting up a new project

1. **Clone as a bare repository:**

   ```bash
   wt clone git@github.com:your-org/your-app.git
   ```

   This creates `~/Herd/your-app.git/` (a bare repo that stores all git data).

2. **Create your first worktree:**

   ```bash
   wt add your-app staging
   ```

   This creates `~/Herd/your-app--staging/` with:
   - The staging branch checked out
   - `.env` created from `.env.example`
   - `APP_URL` set to `https://your-app--staging.test`
   - `composer install` run automatically

3. **Open in browser:**

   ```bash
   wt open your-app staging
   # Opens https://your-app--staging.test
   ```

### Working on a feature

```bash
# Create a new worktree for your feature
wt add myapp feature/login

# Open in your editor
wt code myapp feature/login

# Or navigate to it
cd "$(wt cd myapp feature/login)"
```

### Quick access with fzf

If you have fzf installed, omit the branch to get an interactive picker:

```bash
wt code myapp      # Pick from list of worktrees
wt pull myapp      # Pick which one to pull
wt rm myapp        # Pick which one to remove
```

## Quick Reference

```bash
# Setup
wt clone <git-url>              # Clone as bare repo (auto-creates staging)
wt clone <git-url> <name> <branch>  # Clone and create specific worktree
wt add <repo> <branch>          # Create worktree
wt add -i                       # Interactive worktree creation wizard
wt repos                        # List all repositories
wt doctor                       # Check system requirements

# Daily use
wt switch <repo>                # cd + code + browser in one (fzf picker)
wt code <repo>                  # Open in editor (fzf picker)
wt open <repo>                  # Open in browser (fzf picker)
cd "$(wt cd <repo> <branch>)"   # Navigate to worktree

# Stay updated
wt pull-all <repo>              # Pull all worktrees (parallel)
wt sync <repo> <branch>         # Rebase onto staging
wt status <repo>                # Dashboard view
wt log <repo> <branch>          # Show recent commits

# Laravel shortcuts
wt fresh <repo> <branch>        # migrate:fresh + npm ci + build
wt migrate <repo> <branch>      # Run migrations
wt tinker <repo> <branch>       # Open tinker

# Parallel operations (v4.0.0)
wt build-all <repo>             # npm run build on all worktrees
wt exec-all <repo> <cmd>        # Run command on all worktrees

# Cleanup
wt rm <repo> <branch>           # Remove worktree (backs up DB)
wt rm --drop-db <repo> <branch> # Remove and drop database
wt rm --no-backup <repo> <branch> # Remove without backup
wt prune -f <repo>              # Delete merged branches

# Maintenance
wt health <repo>                # Check repository health
wt report <repo>                # Generate markdown status report
wt repair [repo]                # Fix orphaned worktrees, stale locks
wt cleanup-herd                 # Remove orphaned Herd nginx configs
wt unlock <repo>                # Remove stale git lock files
```

## Commands Reference

### Core Commands

| Command | Description |
|---------|-------------|
| `wt add <repo> <branch> [base]` | Create a new worktree |
| `wt add -i` / `--interactive` | Interactive worktree creation wizard |
| `wt add ... --template=<name>` | Create worktree using a template |
| `wt add ... --dry-run` | Preview worktree creation without executing |
| `wt rm <repo> [branch]` | Remove a worktree |
| `wt ls <repo>` | List all worktrees with status |
| `wt status <repo>` | Dashboard view with age, sync, merged status |
| `wt repos` | List all repositories in HERD_ROOT |
| `wt templates [name]` | List templates or show template details |
| `wt clone <url> [name] [branch]` | Clone as bare repo (create specific worktree) |

#### The `repos` command

Lists all bare repositories in your HERD_ROOT directory.

```bash
wt repos
```

Output:
```text
📦 Repositories in /Users/you/Herd

  myapp (3 worktrees)
  otherapp (1 worktrees)
```

JSON output:
```bash
wt repos --json
```

#### The `doctor` command

Checks your system configuration and available tools.

```bash
wt doctor
```

Output:
```text
🩺 wt doctor

Configuration
✔ HERD_ROOT: /Users/you/Herd
  DB_BACKUP_DIR does not exist (will be created on first backup)

Required Tools
✔ git: git version 2.43.0
✔ composer: Composer version 2.7.1

Optional Tools
✔ mysql: mysql Ver 8.0.36
✔   MySQL connection: OK
✔ herd: installed
✔ fzf: installed
✔ editor: cursor

Config Files
✔ User config: /Users/you/.wtrc
  Project config: /Users/you/Herd/.wtconfig (not found)

✔ All checks passed!
```

### Navigation Commands

| Command | Description |
|---------|-------------|
| `wt cd <repo> [branch]` | Print worktree path (for use with `cd`) |
| `wt code <repo> [branch]` | Open in editor (Cursor/VS Code) |
| `wt open <repo> [branch]` | Open URL in browser |
| `wt switch <repo> [branch]` | cd + code + browser in one command |

#### The `switch` command

Opens a worktree in your editor and browser simultaneously. Prints the path for use with `cd`.

```bash
# With fzf picker
cd "$(wt switch myapp)"

# Explicit branch
cd "$(wt switch myapp feature/login)"
```

This single command:
1. Prints the worktree path (for `cd`)
2. Opens the worktree in your editor
3. Opens the URL in your browser

#### The `add` command in detail

Creates a new worktree for a branch, setting up a complete Laravel development environment.

```bash
# Create from existing remote branch
wt add myapp feature/existing-branch

# Create new branch from staging (default base)
wt add myapp feature/new-work

# Create new branch from a specific base
wt add myapp feature/new-work origin/main
```

**What it does automatically:**

1. Fetches all branches from remote
2. If using `origin/...` as base, explicitly fetches that branch with `--force` to ensure it's up-to-date
3. Creates the worktree directory at `~/Herd/<repo>--<branch-slug>/`
4. **Pushes new branch to remote and sets up tracking** (prevents accidental pushes to wrong branch)
5. Runs `post-add` lifecycle hooks (see below)

**With the example Laravel hooks installed, it also:**

6. Copies `.env.example` to `.env`
7. Sets `APP_URL` and `DB_DATABASE` in `.env`
8. Creates a MySQL database named `<repo>__<branch_slug>`
9. Secures the site with HTTPS via `herd secure`
10. Runs `composer install` and generates app key
11. Runs `npm install` and `npm run build`
12. Runs Laravel migrations

**Database naming:** Branch slashes become underscores, dashes become underscores:
- `myapp` + `feature/login` → `myapp__feature_login`
- `myapp` + `bugfix-123` → `myapp__bugfix_123`

**Output with `--json`:**
```json
{"path": "/Users/you/Herd/myapp--feature-login", "url": "https://myapp--feature-login.test", "branch": "feature/login", "database": "myapp__feature_login"}
```

#### The `rm` command in detail

Removes a worktree with automatic cleanup of associated resources.

```bash
# Interactive selection (with fzf)
wt rm myapp

# Explicit branch
wt rm myapp feature/done

# Force remove (skip uncommitted changes warning)
wt rm -f myapp feature/done

# Remove worktree AND delete the local branch
wt rm --delete-branch myapp feature/done

# Combine flags
wt rm -f --delete-branch myapp feature/done
```

**What it does automatically:**

1. Runs `pre-rm` lifecycle hooks (can abort removal)
2. Removes the worktree directory
3. Optionally deletes the local branch (with `--delete-branch`)
4. Prunes stale worktree references
5. Runs `post-rm` lifecycle hooks

**With the example Laravel hooks installed, it also:**

- Backs up the database to `$DB_BACKUP_DIR/<repo>/<db_name>_<timestamp>.sql` (skip with `--no-backup`)
- Unsecures the site via `herd unsecure`
- Drops the database (only with `--drop-db` flag)

**Backup location:**
```text
~/Code/Project Support/Worktree/Database/Backup/
└── myapp/
    ├── myapp__feature_login_20241220_143052.sql
    └── myapp__feature_dashboard_20241220_150312.sql
```

**Safety:**

- **Protected branches** (`staging`, `main`, `master`) require `-f` flag to remove
- Warns if there are uncommitted changes (override with `-f`)
- Database backup happens before removal
- `--delete-branch` only deletes the local branch, not remote
- Set `WT_DB_BACKUP=false` to disable database backups
- Customise protected branches via `WT_PROTECTED_BRANCHES`

### Git Operations

| Command | Description |
|---------|-------------|
| `wt pull <repo> [branch]` | Pull latest changes with rebase |
| `wt pull-all <repo>` | Pull all worktrees for a repo |
| `wt sync <repo> [branch] [base]` | Rebase branch onto base branch |
| `wt status <repo>` | Dashboard of all worktrees |

#### The `pull` command

Pulls latest changes for a specific worktree using `git pull --rebase`.

```bash
# Interactive selection (with fzf)
wt pull myapp

# Explicit branch
wt pull myapp feature/login
```

#### The `pull-all` command

Pulls all worktrees for a repository **in parallel** for faster updates. Great for your morning routine.

```bash
wt pull-all myapp
```

Shows success/failure for each worktree:
```text
→ Fetching latest...
→ Pulling 3 worktree(s) in parallel...
✔   feature/login
✔   feature/dashboard
✔   staging

✔ Pulled 3 worktree(s)
```

**Features:**

- **Parallel execution** - All worktrees are pulled simultaneously
- **macOS notification** - Sends a desktop notification when complete (useful for large repos)
- **Error reporting** - Failed pulls are clearly marked with ✖

#### The `status` command

Shows a dashboard view of all worktrees with their state and sync status.

```bash
wt status myapp
```

Output:
```text
📊 Worktree Status: myapp

  BRANCH                         STATE        SYNC       SHA
  ──────────────────────────────────────────────────────────────────────
  staging                        ●            ↑0 ↓0      a1b2c3d
  feature/login                  ◐ 3          ↑5 ↓12     e4f5g6h
  feature/dashboard              ●            ↑2 ↓0      i7j8k9l

⚠ Branch/Directory Mismatches Detected:
  myapp--old-feature-name
    Current branch:  feature/new-name
    Expected dir:    myapp--feature-new-name
    Fix: Checkout correct branch or recreate worktree
```

- **State**: `●` = clean, `◐ N` = N uncommitted changes
- **Sync**: `↑N` = commits ahead, `↓N` = commits behind (vs `origin/staging`)
- **Mismatch warning**: Shown when a worktree's directory name doesn't match its branch (e.g., someone ran `git checkout` inside the worktree)

#### The `ls` command

Lists all worktrees with detailed information.

```bash
wt ls myapp
```

Output:
```text
[1] 📁 /Users/you/Herd/myapp--staging
    branch  🌿 staging
    sha     a1b2c3d
    state   ● clean
    sync    ↑0 ↓0
    url     🌐 https://myapp--staging.test
    cd      cd '/Users/you/Herd/myapp--staging'

[2] 📁 /Users/you/Herd/myapp--feature-login
    branch  🌿 feature/login
    sha     e4f5g6h
    state   ◐ 3 uncommitted
    sync    ↑5 ↓12
    url     🌐 https://myapp--feature-login.test
    cd      cd '/Users/you/Herd/myapp--feature-login'

[3] 📁 /Users/you/Herd/myapp--old-name
    branch  🌿 feature/renamed-branch
    sha     m1n2o3p
    state   ● clean
    url     🌐 https://myapp--old-name.test
    cd      cd '/Users/you/Herd/myapp--old-name'
    ⚠ MISMATCH Directory name doesn't match branch!
      Expected: myapp--feature-renamed-branch
```

**Mismatch warnings**: If someone runs `git checkout` inside a worktree, the directory name no longer matches the branch. This warning helps catch these issues.

**JSON output:**
```bash
wt ls --json myapp
```
```json
[{"path": "/Users/you/Herd/myapp--staging", "branch": "staging", "sha": "a1b2c3d", "url": "https://myapp--staging.test", "dirty": false, "ahead": 0, "behind": 0, "mismatch": false}]
```

#### The `sync` command in detail

The `sync` command rebases your feature branch onto a base branch (default: `origin/staging`). This keeps your branch up to date with the latest changes.

```bash
# Interactive (fzf picker for branch)
wt sync myapp

# Explicit branch, default base (origin/staging)
wt sync myapp feature/login

# Explicit branch and custom base
wt sync myapp feature/login origin/main
```

**Safety measures:**

1. **Fetches first** - Always gets the latest remote state before rebasing
2. **Uncommitted changes check** - Refuses to run if you have uncommitted work:
   ```text
   ✖ ERROR: Worktree has uncommitted changes. Commit or stash them first.
   ```

3. **Standard rebase** - Uses regular `git rebase`, no force or destructive options

**What to expect:**

- **Rebase conflicts** - If your commits conflict with changes in the base branch, Git will pause and ask you to resolve them. After resolving, run `git rebase --continue`.
- **Already pushed?** - If you've already pushed your branch to remote, you'll need to force push after syncing: `git push --force-with-lease`

**Under the hood**, `sync` is equivalent to:
```bash
git fetch --all --prune
git rebase origin/staging
```

### Laravel Commands

| Command | Description |
|---------|-------------|
| `wt fresh <repo> [branch]` | Reset database and rebuild frontend |
| `wt migrate <repo> [branch]` | Run database migrations |
| `wt tinker <repo> [branch]` | Open Laravel Tinker REPL |
| `wt log <repo> [branch]` | Show recent git commits |

#### The `fresh` command

Resets your Laravel application to a clean state. Useful when switching to a branch with significant database changes.

```bash
# Interactive selection (with fzf)
wt fresh myapp

# Explicit branch
wt fresh myapp feature/login
```

**What it does:**

1. Runs `php artisan migrate:fresh --seed`
2. Runs `npm ci` (clean install of dependencies)
3. Runs `npm run build`

**Note:** This command drops all tables and recreates them. Use with caution on worktrees with data you want to keep.

#### The `migrate` command

Runs Laravel migrations for a worktree.

```bash
# Interactive selection (with fzf)
wt migrate myapp

# Explicit branch
wt migrate myapp feature/login
```

Equivalent to running `php artisan migrate` in the worktree directory.

#### The `tinker` command

Opens Laravel Tinker, the interactive REPL for your Laravel application.

```bash
# Interactive selection (with fzf)
wt tinker myapp

# Explicit branch
wt tinker myapp feature/login
```

Tinker opens in the worktree's context, so models and services are available.

#### The `log` command

Shows recent git commits for a worktree.

```bash
# Interactive selection (with fzf)
wt log myapp

# Explicit branch
wt log myapp feature/login
```

Displays the last 15 commits in a compact one-line format with relative dates.

### Maintenance

| Command | Description |
|---------|-------------|
| `wt clone <url> [name] [branch]` | Clone as bare repo (create specific worktree) |
| `wt prune <repo>` | Clean up stale worktrees and merged branches |
| `wt exec <repo> <branch> <cmd>` | Run command in worktree |
| `wt health <repo>` | Check repository health |
| `wt report <repo> [--output <file>]` | Generate markdown status report |
| `wt repair [repo]` | Fix orphaned worktrees, remove stale locks |
| `wt doctor` | Check system requirements |
| `wt cleanup-herd` | Remove orphaned Herd nginx configs |
| `wt unlock [repo]` | Remove stale git lock files |

### Parallel Operations

| Command | Description |
|---------|-------------|
| `wt build-all <repo>` | Run `npm run build` on all worktrees |
| `wt exec-all <repo> <cmd>` | Execute command across all worktrees |
| `wt pull-all <repo>` | Pull all worktrees (parallel) |

#### Parallel concurrency

Configure the maximum number of parallel operations via the `WT_MAX_PARALLEL` environment variable (default: 4):

```bash
# In ~/.wtrc
WT_MAX_PARALLEL=8
```

#### The `clone` command

Clones a repository as a bare repo and creates an initial worktree.

```bash
# Clone with auto-detected name (creates staging/main/master worktree)
wt clone git@github.com:your-org/your-app.git

# Clone with custom name
wt clone git@github.com:your-org/your-app.git myapp

# Clone and create worktree for specific existing branch
wt clone git@github.com:your-org/your-app.git myapp feature/auth

# Clone and create new feature branch (based on staging/main/master)
wt clone git@github.com:your-org/your-app.git myapp feature/new-dashboard
```

**What it does:**

1. Clones as a bare repository to `~/Herd/<repo>.git/`
2. Configures fetch to get all branches
3. Fetches all remote branches
4. Creates the initial worktree:
   - If `[branch]` specified and exists on remote: creates worktree for that branch
   - If `[branch]` specified but doesn't exist: creates new branch from staging/main/master
   - If no branch specified: auto-creates worktree for staging, main, or master (first found)

This means you can clone and start working on a specific feature immediately:

```bash
# Start working on an existing feature
wt clone git@github.com:your-org/your-app.git myapp feature/auth
cd "$(wt cd myapp feature/auth)"

# Or start a new feature
wt clone git@github.com:your-org/your-app.git myapp feature/new-work
```

#### The `exec` command

Runs a command inside a worktree directory.

```bash
# Run artisan commands
wt exec myapp feature/login php artisan migrate
wt exec myapp feature/login php artisan test

# Run npm commands
wt exec myapp feature/login npm run dev

# Run any command
wt exec myapp feature/login git status
```

The command runs in the worktree directory, so relative paths work correctly.

#### The `prune` command in detail

The `prune` command cleans up your repository by removing stale worktree references and optionally deleting merged branches.

```bash
# Show stale worktrees and merged branches (dry run)
wt prune myapp

# Actually delete merged branches
wt prune myapp -f
```

**What it does:**

1. **Prunes stale worktrees** - Removes worktree entries that point to directories that no longer exist
2. **Finds merged branches** - Identifies local branches that have been merged into `origin/staging`
3. **Deletes merged branches** (with `-f`) - Force-deletes branches confirmed as merged

**Note on squash/rebase merges:** The prune command uses force-delete (`git branch -D`) for merged branches. This is necessary because squash-merged or rebase-merged branches have different commit SHAs than what ends up in staging, even though the content is merged.

**Safety:**

- Without `-f`, it only shows what would be deleted
- Never deletes `staging`, `main`, or `master` branches
- Only deletes **local** branches (never touches remote branches)
- Branches checked out in a worktree cannot be deleted until the worktree is removed

#### The `health` command

Performs a comprehensive health check on a repository, identifying potential issues.

```bash
wt health myapp
```

**What it checks:**

1. **Stale worktrees** - Worktree references pointing to directories that no longer exist
2. **Orphaned databases** - MySQL databases matching the repo pattern without corresponding worktrees
3. **Missing .env files** - Worktrees with `.env.example` but no `.env` file
4. **Branch consistency** - Directory names that don't match their checked-out branch

**Example output:**
```text
🏥 Health Check: myapp

Stale Worktrees
✔ No stale worktrees

Database Health
✔ No orphaned databases found

Environment Files
✔ All worktrees have .env files

Branch Consistency
✔ All worktrees match their expected branches

Summary
✔ No issues found - repository is healthy! 🎉
```

#### The `report` command

Generates a markdown status report for all worktrees in a repository.

```bash
# Output to console
wt report myapp

# Save to file
wt report myapp --output ~/Desktop/worktree-report.md
```

**What's included:**

- Summary table with total, clean, and dirty worktree counts
- Per-worktree details: branch, status, ahead/behind counts, last commit
- List of available lifecycle hooks

**Example output:**
```markdown
# Worktree Report: myapp

Generated: 2025-12-24 10:30:00

## Summary

| Metric | Count |
|--------|-------|
| Total worktrees | 5 |
| Clean | 3 |
| With changes | 2 |

## Worktrees

| Branch | Status | Ahead | Behind | Last Commit |
|--------|--------|-------|--------|-------------|
| `staging` | ✅ | 0 | 0 | Merge pull request #123... |
| `feature/auth` | ⚠️ 3 changes | 2 | 0 | Add login validation |

## Hooks Available

- ✅ `pre-add`
- ✅ `post-add`
- ⬜ `pre-rm`
- ⬜ `post-rm`
- ⬜ `post-pull`
- ⬜ `post-sync`
```

### Flags

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Suppress informational output |
| `-f, --force` | Skip confirmations, force operations |
| `-i, --interactive` | Interactive worktree creation wizard |
| `--dry-run` | Preview worktree creation without executing |
| `--json` | Output in JSON format (for `ls` and `add`) |
| `--pretty` | Colourised, formatted JSON output |
| `-t, --template=<name>` | Use a template when creating worktree |
| `--delete-branch` | Delete branch when removing worktree |
| `--drop-db` | Drop database after backup (with `rm`) |
| `--no-backup` | Skip database backup (with `rm`) |
| `-v, --version` | Show version |
| `-h, --help` | Show help |

**Flag position:** Flags can appear anywhere in the command line:

```bash
wt -f prune myapp        # ✔
wt prune -f myapp        # ✔
wt prune myapp -f        # ✔
```

**Flag usage by command:**

| Command | Useful flags |
|---------|--------------|
| `add` | `-i` (interactive), `--dry-run`, `--json`, `-t`/`--template` |
| `rm` | `-f` (force), `--delete-branch`, `--drop-db`, `--no-backup` |
| `ls` | `--json`, `--pretty` |
| `status` | `--json`, `--pretty` |
| `prune` | `-f` (actually delete merged branches) |
| `repos` | `--json` |
| `templates` | View template details |
| All | `-q` (quiet mode) |

---

## Worktree Templates

Templates let you predefine which setup hooks run when creating worktrees. This is useful when you have different project types or want quick minimal checkouts.

### Listing Templates

```bash
wt templates
```

Output:
```text
📋 Available Templates

  backend - Backend only - PHP, database, no npm/build
  laravel - Laravel with MySQL, Composer, NPM, and migrations
  minimal - Minimal - git worktree only, no setup
  node - Node.js project (npm only, no PHP/database)

Usage: wt templates <name>  - Show template details
       wt add <repo> <branch> --template=<name>
```

### Using a Template

```bash
# Use --template or -t flag when adding a worktree
wt add myapp feature/quick-fix --template=minimal

# Short form
wt add myapp feature/api-work -t backend
```

### Viewing Template Details

```bash
wt templates minimal
```

Output:
```text
📋 Template: minimal

Description: Minimal - git worktree only, no setup

File: /Users/you/.wt/templates/minimal.conf

Settings:
  WT_SKIP_DB = true (skipped)
  WT_SKIP_COMPOSER = true (skipped)
  WT_SKIP_NPM = true (skipped)
  WT_SKIP_BUILD = true (skipped)
  WT_SKIP_MIGRATE = true (skipped)
  WT_SKIP_HERD = true (skipped)

Usage: wt add <repo> <branch> --template=minimal
```

### Creating Custom Templates

Templates are simple key=value files in `~/.wt/templates/`:

```bash
# ~/.wt/templates/api-only.conf
TEMPLATE_DESC="API backend - database and PHP only"

WT_SKIP_NPM=true
WT_SKIP_BUILD=true
WT_SKIP_HERD=true
```

### Included Example Templates

The installer includes these templates in `examples/templates/`:

| Template | Description |
|----------|-------------|
| `laravel.conf` | Full Laravel setup - database, composer, npm, build, migrations |
| `node.conf` | Node.js projects - npm only, skips PHP and database |
| `minimal.conf` | Git worktree only - skips all setup hooks |
| `backend.conf` | Backend API work - PHP and database, no frontend build |

To install example templates:
```bash
cp examples/templates/*.conf ~/.wt/templates/
```

---

## Testing

The project includes a comprehensive test suite using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

### Running Tests

```bash
# Run all tests
./run-tests.sh

# Run only unit tests
./run-tests.sh unit

# Run only integration tests
./run-tests.sh integration

# Run a specific test file
./run-tests.sh validation.bats
```

### Test Coverage

The test suite includes **187 tests** covering:

- **Input validation** - Security-critical path traversal, git flag injection, reserved references
- **Branch slugification** - Converting branch names to filesystem-safe slugs
- **Database naming** - MySQL 64-character limits, hash suffix for long names
- **URL generation** - Worktree paths and URLs with subdomain support
- **JSON escaping** - Proper escaping for JSON output (including control characters)
- **Config parsing** - Security whitelist enforcement, injection prevention
- **Template security** - Path traversal prevention, variable injection protection

### Installing BATS

```bash
# macOS (Homebrew)
brew install bats-core

# npm
npm install -g bats

# Or use the bundled version
git clone https://github.com/bats-core/bats-core.git test_modules/bats
```

---

## Developer Guide

This section is for developers who want to contribute to `wt` or understand its internal architecture.

### Modular Architecture

As of v4.0.0, `wt` uses a modular architecture. The source code is split into focused modules in `lib/`, then concatenated into a single `wt` file for distribution.

```text
lib/
├── 00-header.sh       # Shebang, version, global defaults
├── 01-core.sh         # Config loading, colours, output helpers
├── 02-validation.sh   # Input validation, security checks
├── 03-paths.sh        # Path resolution, URL generation
├── 04-git.sh          # Git operations, branch helpers
├── 05-database.sh     # MySQL operations
├── 06-hooks.sh        # Hook system with security verification
├── 07-templates.sh    # Template loading
├── 08-spinner.sh      # Progress indicators (spinners)
├── 09-parallel.sh     # Parallel execution framework
├── 10-interactive.sh  # Interactive wizard (fzf-based)
├── 11-resilience.sh   # Retry logic, transactions, lock cleanup
├── 99-main.sh         # Entry point, usage, flag parsing
└── commands/
    ├── lifecycle.sh   # add, rm, clone, fresh
    ├── git-ops.sh     # pull, pull-all, sync, prune
    ├── navigation.sh  # code, open, cd, switch, exec
    ├── info.sh        # ls, status, repos, health, report
    ├── utility.sh     # doctor, templates, cleanup, repair
    └── laravel.sh     # migrate, tinker
```

### Building from Source

The `build.sh` script concatenates all modules into a single executable:

```bash
# Build the wt script
./build.sh

# Build to a custom location
./build.sh --output /path/to/output
```

The build process:
1. Starts with `00-header.sh` (includes shebang)
2. Concatenates modules in order (stripping shebangs)
3. Adds command modules from `lib/commands/`
4. Appends `99-main.sh` (entry point)
5. Makes the output executable

### Development Workflow

```bash
# 1. Edit modules in lib/
vim lib/02-validation.sh

# 2. Build the script
./build.sh

# 3. Test your changes
./wt doctor

# 4. Run the test suite
./run-tests.sh

# 5. Run specific tests
./run-tests.sh unit
./run-tests.sh integration
./run-tests.sh validation.bats
```

### Module Dependencies

Modules are sourced in numeric order. Each module may depend on functions from earlier modules:

| Module | Dependencies |
|--------|--------------|
| `00-header.sh` | None |
| `01-core.sh` | None |
| `02-validation.sh` | core |
| `03-paths.sh` | core, validation |
| `04-git.sh` | core, paths |
| `05-database.sh` | core |
| `06-hooks.sh` | core, validation |
| `07-templates.sh` | core, validation, paths |
| `08-spinner.sh` | core |
| `09-parallel.sh` | core, spinner |
| `10-interactive.sh` | core, paths, templates |
| `11-resilience.sh` | core |
| `commands/*.sh` | All above |

### Adding a New Command

1. Determine which command module fits your command (or create a new one)
2. Add your function with the `cmd_` prefix:
   ```zsh
   cmd_mycommand() {
     local repo="${1:-}"
     # ... implementation
   }
   ```
3. Register it in `lib/99-main.sh` in the `main()` function's case statement
4. Add help text in the `usage()` function
5. Add tests in `tests/`
6. Run `./build.sh` and test

### Adding a New Module

1. Create the module file with appropriate number prefix (e.g., `lib/12-newmodule.sh`)
2. Add a shebang and module comment:
   ```zsh
   #!/usr/bin/env zsh
   # 12-newmodule.sh - Description of module purpose
   ```
3. Add the module to the `MODULES` array in `build.sh`
4. Run `./build.sh` and test

### Test Structure

```text
tests/
├── unit/
│   ├── validation.bats      # Input validation tests
│   ├── slugify.bats         # Branch slugification
│   ├── db-naming.bats       # Database name generation
│   ├── url-generation.bats  # URL/path generation
│   ├── json-escape.bats     # JSON escaping
│   ├── config-parsing.bats  # Config file parsing
│   └── template-security.bats
├── integration/
│   └── commands.bats        # CLI parsing, help, validation
├── test-helper.bash         # Shared test utilities
└── run-tests.sh             # Test runner
```

### Code Style

- Use zsh syntax (this is not a POSIX shell script)
- Prefer `local` for function-scoped variables
- Use `readonly` for constants
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Use meaningful function and variable names
- Add comments for non-obvious logic

---

## Security

`wt` is designed with security in mind:

### Input Validation
- **Path traversal protection** - Repository and branch names are validated to prevent `../` attacks
- **Git flag injection prevention** - Names starting with `-` are rejected to prevent flag injection
- **Reserved reference blocking** - Special git references (`HEAD`, `refs/`) are blocked as branch names

### Configuration Security
- **Config whitelist** - Only specific configuration variables are loaded from `.wtrc` files
- **No code execution** - Config files are parsed as key-value pairs, not sourced as shell scripts
- **Hook verification** - Hooks must be owned by the current user and not world-writable

### Template Security
- **Template name validation** - Only alphanumeric characters, dashes, and underscores allowed
- **Path traversal prevention** - Template names cannot contain `..`, `/`, or `\`
- **Variable injection protection** - Template variables only accept `true` or `false` values

### Reporting Security Issues

If you discover a security vulnerability, please report it responsibly by opening a private issue or contacting the maintainer directly.

---

## Common Workflows

### Starting work on a new feature

```bash
# Create worktree from staging
wt add myapp feature/new-dashboard

# Open in editor
wt code myapp feature/new-dashboard

# Open in browser
wt open myapp feature/new-dashboard
```

### Reviewing a PR

```bash
# Create worktree for the PR branch
wt add myapp feature/someone-elses-work

# Check it out, run tests, etc.
wt exec myapp feature/someone-elses-work php artisan test

# Clean up when done
wt rm myapp feature/someone-elses-work
```

### Keeping branches up to date

```bash
# Pull all worktrees at once
wt pull-all myapp

# Or sync a specific branch with staging
wt sync myapp feature/login origin/staging
```

### Morning routine

```bash
# See status of all worktrees
wt status myapp

# Update everything
wt pull-all myapp
```

### Cleaning up after merging

```bash
# Remove worktree and delete the branch
wt rm --delete-branch myapp feature/completed-work

# Or just prune stale worktrees
wt prune myapp
```

## Directory Structure

After setting up, your Herd directory will look like:

```text
~/Herd/
├── myapp.git/                    # Bare repository
├── myapp--staging/               # staging branch
│   ├── .env                      # APP_URL=https://myapp--staging.test
│   ├── vendor/
│   └── ...
├── myapp--feature-login/         # feature/login branch
│   ├── .env                      # APP_URL=https://myapp--feature-login.test
│   ├── vendor/
│   └── ...
└── otherapp.git/                 # Another project
```

Each worktree:
- Has its own `.env` with unique `APP_URL`
- Has its own `vendor/` and `node_modules/`
- Is served by Herd at its own `.test` domain
- Can run simultaneously with other worktrees

## Tips

### Use aliases for common repos

Add to `~/.zshrc`:

```bash
alias wts="wt status scooda"
alias wtl="wt ls scooda"
alias wtc="wt code scooda"
```

### Quick navigation function

Add to `~/.zshrc`:

```bash
# Usage: wtcd myapp feature/login
wtcd() {
  cd "$(wt cd "$@")"
}
```

### Database per worktree

Each worktree can have its own database. In your `.env.example`:

```text
DB_DATABASE=myapp_${APP_URL##*--}
```

Or manually set different databases in each worktree's `.env`.

### Running commands across worktrees

```bash
# Run migrations on all worktrees
for branch in staging feature/login feature/dashboard; do
  wt exec myapp "$branch" php artisan migrate
done
```

## Repository Structure

This section describes the files in the wt-worktree-manager repository itself.

```text
wt-worktree-manager/
│
├── wt                          # Built executable (generated by build.sh)
├── _wt                         # Zsh tab completion definitions
├── build.sh                    # Build script - concatenates lib/ into wt
│
├── lib/                        # Source modules (v4.0.0+)
│   ├── 00-header.sh           # Version, global defaults
│   ├── 01-core.sh             # Config, colours, output helpers
│   ├── 02-validation.sh       # Input validation, security
│   ├── 03-paths.sh            # Path resolution, URL generation
│   ├── 04-git.sh              # Git operations, branch helpers
│   ├── 05-database.sh         # MySQL operations
│   ├── 06-hooks.sh            # Hook system with security
│   ├── 07-templates.sh        # Template loading
│   ├── 08-spinner.sh          # Progress indicators
│   ├── 09-parallel.sh         # Parallel execution
│   ├── 10-interactive.sh      # Interactive wizard
│   ├── 11-resilience.sh       # Retry, transactions, locks
│   ├── 99-main.sh             # Entry point, usage, flags
│   └── commands/
│       ├── lifecycle.sh       # add, rm, clone, fresh
│       ├── git-ops.sh         # pull, pull-all, sync, prune
│       ├── navigation.sh      # code, open, cd, switch, exec
│       ├── info.sh            # ls, status, repos, health
│       ├── utility.sh         # doctor, cleanup, repair
│       └── laravel.sh         # migrate, tinker
│
├── tests/                      # BATS test suite (187 tests)
│   ├── unit/                  # Unit tests
│   ├── integration/           # Integration tests
│   ├── test-helper.bash       # Shared utilities
│   └── run-tests.sh           # Test runner
│
├── install.sh                  # Installer - sets up symlinks, config, hooks
├── uninstall.sh                # Uninstaller - removes symlinks, preserves data
│
├── .wtrc.example               # Example configuration file
├── README.md                   # This documentation
├── CHANGELOG.md                # Version history and release notes
├── ROADMAP.md                  # Feature roadmap
├── CONTRIBUTING.md             # Contribution guidelines
├── LICENSE                     # MIT license
│
└── examples/
    ├── templates/              # Example worktree templates
    │   ├── laravel.conf
    │   ├── node.conf
    │   ├── minimal.conf
    │   └── backend.conf
    └── hooks/                  # Example lifecycle hooks
        ├── README.md           # Comprehensive hooks documentation
        ├── post-add.d/         # Scripts run after worktree creation
        │   ├── 00-register-project.sh
        │   ├── 01-copy-env.sh
        │   ├── 02-configure-env.sh
        │   ├── 03-create-database.sh
        │   ├── 04-herd-secure.sh
        │   ├── 05-composer-install.sh
        │   ├── 06-npm-install.sh
        │   ├── 07-build-assets.sh
        │   ├── 08-run-migrations.sh
        │   └── myapp/          # Repo-specific hooks example
        │       ├── 01-symlink-env.sh
        │       ├── 02-import-database.sh
        │       └── 03-seed-data.sh
        ├── pre-rm.d/
        │   └── 01-backup-database.sh
        └── post-rm.d/
            ├── 01-herd-unsecure.sh
            └── 02-drop-database.sh
```

### Key Files

| File | Purpose |
|------|---------|
| `wt` | The built executable (generated by `build.sh`) |
| `lib/` | Source modules - edit these to modify wt |
| `build.sh` | Builds `wt` from modules in `lib/` |
| `_wt` | Zsh completion script for tab completion |
| `install.sh` | Sets up symlinks, creates config and hooks directory |
| `uninstall.sh` | Removes symlinks, preserves user data |
| `.wtrc.example` | Template for `~/.wtrc` configuration |
| `examples/hooks/` | Example lifecycle hooks you can copy to `~/.wt/hooks/` |
| `examples/templates/` | Example worktree templates |

### User Data Locations

After installation, your personal data lives in these locations:

| Location | Purpose | Backed up? |
|----------|---------|------------|
| `~/.wtrc` | Your configuration (HERD_ROOT, editor, database settings) | You should |
| `~/.wt/hooks/` | Your lifecycle hooks (post-add, post-rm, etc.) | You should |
| `~/Herd/*.git/` | Your bare git repositories | Git remote |
| `~/Herd/*/` | Your worktrees (working directories) | Git remote |

### Installing Example Hooks

The installer handles hook installation. For existing installations, re-run it with `--merge`:

```bash
# Add new example hooks without overwriting your existing ones
cd ~/Projects/wt-worktree-manager
./install.sh --merge

# Or replace all hooks (backs up existing to ~/.wt/hooks.backup.<timestamp>/)
./install.sh --overwrite
```

You can also copy specific hooks manually:

```bash
# Copy a specific hook
cp ~/Projects/wt-worktree-manager/examples/hooks/post-add.d/03-create-database.sh ~/.wt/hooks/post-add.d/

# Create repo-specific hooks
mkdir -p ~/.wt/hooks/post-add.d/myapp
cp ~/Projects/wt-worktree-manager/examples/hooks/post-add.d/myapp/* ~/.wt/hooks/post-add.d/myapp/
```

See [examples/hooks/README.md](examples/hooks/README.md) for detailed hook documentation.

## Troubleshooting

### "Bare repo not found"

You need to clone the repo first:

```bash
wt clone git@github.com:org/repo.git
```

### "Worktree already exists"

The worktree directory already exists. Either:
- Use the existing worktree: `wt cd myapp branch-name`
- Remove it first: `wt rm myapp branch-name`

### Git commands fail with "command not found"

The script uses absolute paths (`/usr/bin/git`, `/usr/bin/ssh`). If your git is installed elsewhere, check:

```bash
which git
which ssh
```

### Branch not found

Fetch the latest branches first:

```bash
git --git-dir="$HOME/Herd/myapp.git" fetch --all
```

### Worktree has uncommitted changes

Before removing or syncing, commit or stash your changes:

```bash
cd "$(wt cd myapp feature/work)"
git stash
# or
git add -A && git commit -m "WIP"
```

### Prune doesn't delete merged branches

Make sure to use the `-f` flag:

```bash
wt prune -f myapp
```

Without `-f`, prune only shows what would be deleted.

### Rebase conflicts during sync

If `wt sync` encounters conflicts:

1. Navigate to the worktree:
   ```bash
   cd "$(wt cd myapp feature/branch)"
   ```

2. Resolve conflicts in your editor

3. Stage resolved files:
   ```bash
   git add <resolved-files>
   ```

4. Continue the rebase:
   ```bash
   git rebase --continue
   ```

5. Or abort if needed:
   ```bash
   git rebase --abort
   ```

### Can't delete branch (checked out in worktree)

A branch can't be deleted while it's checked out. Remove the worktree first:

```bash
wt rm myapp feature/branch
wt prune -f myapp
```

### SSH authentication issues

If git operations fail with SSH errors, ensure your SSH agent is running:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Can't remove staging/main/master worktree

Protected branches require the force flag:

```bash
wt rm -f myapp staging
```

To change protected branches, set in `~/.wtrc`:

```bash
PROTECTED_BRANCHES="main production"  # Your custom list
```

### fzf picker not working

Install fzf:

```bash
brew install fzf
```

If installed but not working, check it's in your PATH:

```bash
which fzf
```

### Database not created

If the database isn't being created automatically:

1. Check MySQL is running:
   ```bash
   mysql -u root -e "SELECT 1"
   ```

2. If you have a password, set it in `~/.wtrc`:
   ```bash
   DB_PASSWORD=your_password
   ```

3. Or disable auto-creation and create manually:
   ```bash
   # In ~/.wtrc
   DB_CREATE=false
   ```
   ```bash
   # Create manually
   mysql -u root -e "CREATE DATABASE myapp__feature_login"
   ```

### Database name too long

MySQL database names are limited to 64 characters. If your repo + branch name exceeds this, you may need to use shorter branch names or manually set `DB_DATABASE` in the `.env` file.

## Version

Current version: **4.0.0**

Check with: `wt --version`

### What's New in 4.0.0

**Major architecture overhaul:**
- **Modular architecture** - The 3,162-line monolithic script has been refactored into 18 focused modules in `lib/` for better maintainability
- **Build system** - `build.sh` concatenates modules into a single `wt` file for distribution
- **187 tests** - Expanded test suite covering all new functionality

**Interactive mode:**
- **`wt add --interactive` / `-i`** - Guided worktree creation wizard with 5 steps:
  1. Repository selection (fzf picker)
  2. Base branch selection (fzf picker)
  3. Branch name input with live preview (path, URL, database)
  4. Template selection (optional fzf picker)
  5. Confirmation with full summary

**Progress indicators:**
- **Spinner animation** - Braille-pattern spinner for long operations
- Spinners available for hooks to use in `composer install`, `npm ci`, etc.

**Parallel operations:**
- **`wt build-all <repo>`** - Run `npm run build` on all worktrees
- **`wt exec-all <repo> <cmd>`** - Execute any command across all worktrees
- Configurable concurrency via `WT_MAX_PARALLEL` (default: 4)

**Resilience improvements:**
- **`wt repair [repo]`** - Scan for and fix common issues (orphaned worktrees, stale locks)
- **Retry logic** - Exponential backoff for transient failures
- **Lock cleanup** - Automatic detection and removal of stale index locks
- **Disk space checks** - Pre-flight checks before operations

**Developer experience:**
- **`--dry-run` flag** - Preview worktree creation without executing
- **`--pretty` flag** - Colourised JSON output
- **"Did you mean?" suggestions** - Helpful suggestions for mistyped template names

### What's New in 3.7.0

**Generic worktree manager:**
- `wt` is now framework-agnostic - all Laravel-specific functionality has been moved to optional hooks
- Core tool handles only git worktree operations (create, remove, sync, pull, status)
- Install example hooks for Laravel projects, or create custom hooks for any framework

**Hook-based architecture:**
- Comprehensive example hooks for Laravel: env setup, database creation, Herd securing, composer/npm install, migrations
- Repo-specific hooks via subdirectories (e.g., `post-add.d/myapp/` runs only for `myapp` repo)
- Hook control flags: `WT_SKIP_DB`, `WT_SKIP_COMPOSER`, `WT_SKIP_NPM`, etc.
- Per-repository config files: `~/Herd/repo.git/.wtconfig`

**Bug fixes:**
- Fixed hooks not running (zsh glob qualifier order)
- Fixed URL generation to include repository name
- Fixed per-repo config loading for `DEFAULT_BASE`

**Installer improvements:**
- `--merge` mode: Add new hooks without overwriting existing ones
- `--overwrite` mode: Replace all hooks (backs up first)
- `--skip-hooks` mode: Skip hook installation entirely

### What's New in 3.6.0

**New commands:**
- **`wt health <repo>`** - Check repository health (stale worktrees, orphaned databases, missing .env files, branch mismatches)
- **`wt report <repo>`** - Generate markdown status report with worktree summary, status, and hook availability
- **`wt clone` branch argument** - Clone and immediately create worktree for a specific branch: `wt clone <url> [name] [branch]`

**New lifecycle hooks:**
- **`pre-add`** - Runs before worktree creation (can abort with non-zero exit)
- **`pre-rm`** - Runs before worktree removal (can abort with non-zero exit)
- **`post-pull`** - Runs after `wt pull` succeeds
- **`post-sync`** - Runs after `wt sync` succeeds

**Security hardening:**
- **Config file security** - Configuration files are now parsed as key-value pairs instead of sourced, preventing arbitrary code execution via malicious `.wtrc` files
- **Hook execution security** - Hooks are verified to be owned by the current user and not world-writable before execution
- **Input validation** - Added protection against absolute paths, git flag injection, reserved git references, and malformed paths

**Other improvements:**
- **Database name limits** - Names exceeding MySQL's 64-character limit are automatically truncated with a hash suffix
- **Fresh command safety** - `wt fresh` now requires confirmation before running `migrate:fresh` (use `-f` to skip)
- **Remote branch fetching** - `origin/...` base branches are now explicitly fetched to ensure the latest version is used

### What's New in 3.5.0

- **Improved remote branch fetching** - When using `origin/...` as a base branch, `wt add` now explicitly fetches the latest version with `--force`. This ensures branches with slashes (e.g., `origin/proj-jl/rethink`) are always up-to-date, even if they weren't properly tracked locally.

### What's New in 3.3.0

- **Branch/directory mismatch detection** - `wt ls` and `wt status` now warn when a worktree's directory name doesn't match its checked-out branch (e.g., if someone ran `git checkout` inside a worktree)
- **Automatic remote tracking setup** - New branches are automatically pushed and set to track their own remote branch (prevents accidental pushes to wrong branch)
- **JSON output includes mismatch field** - `wt ls --json` now includes `"mismatch": true/false`

### What's New in 3.0.0

- **New commands**: `repos`, `doctor`, `fresh`, `switch`, `migrate`, `tinker`, `log`
- **Parallel pull-all**: Pulls all worktrees concurrently for faster updates
- **macOS notifications**: Get notified when long operations complete
- **Auto-create staging**: Clone now automatically creates a staging worktree
- **Branch protection**: Protected branches (staging, main, master) require `-f` to remove
- **Database cleanup**: `--drop-db` flag to drop database after backup
- **Skip backup**: `--no-backup` flag to skip database backup on removal

## Common Workday Scenarios

### Starting your day

```bash
# Check what you were working on
wt status myapp

# Pull all worktrees to get overnight changes
wt pull-all myapp

# Jump straight into your current feature
cd "$(wt switch myapp)"
```

### Starting a new feature

```bash
# Create worktree (auto-creates branch from staging, sets up DB, secures site)
wt add myapp feature/user-avatars

# Opens editor + browser, prints path for cd
cd "$(wt switch myapp feature/user-avatars)"

# Run migrations for the new database
wt migrate myapp feature/user-avatars
```

### Reviewing a colleague's PR

```bash
# Create worktree for their branch
wt add myapp feature/colleague-work

# Open it up
cd "$(wt switch myapp feature/colleague-work)"

# Reset to clean state if needed
wt fresh myapp feature/colleague-work

# When done reviewing, clean up
wt rm --drop-db myapp feature/colleague-work
```

### Quick hotfix on staging

```bash
# Make sure staging is up to date
wt pull myapp staging

# Open staging
cd "$(wt switch myapp staging)"

# Make your fix, commit, then switch back to your feature
cd "$(wt switch myapp feature/current-work)"
```

### Keeping your feature branch up to date

```bash
# Sync your branch with latest staging (fetches + rebases)
wt sync myapp feature/user-avatars

# If there are conflicts, resolve them then:
git rebase --continue

# After syncing, you may need to force push
git push --force-with-lease
```

### Switching between features

```bash
# Quick switch with fzf picker
cd "$(wt switch myapp)"

# Or explicit branch
cd "$(wt switch myapp feature/other-feature)"
```

### Debugging with Tinker

```bash
# Open tinker for a specific worktree
wt tinker myapp feature/user-avatars

# Check recent commits if something looks wrong
wt log myapp feature/user-avatars
```

### End of day cleanup

```bash
# See what branches you have
wt ls myapp

# Remove any branches you're done with (keeps backup)
wt rm myapp feature/completed-work

# Or if you want to drop the database too
wt rm --drop-db myapp feature/completed-work

# Clean up any merged branches
wt prune -f myapp
```

### After a PR is merged

```bash
# Remove the worktree and delete the local branch
wt rm --delete-branch --drop-db myapp feature/merged-feature

# Update staging
wt pull myapp staging

# Sync any other feature branches with the new staging
wt sync myapp feature/other-feature
```

### Setting up a new project

```bash
# Clone the repo (auto-creates staging worktree)
wt clone git@github.com:your-org/new-project.git

# Open it immediately
cd "$(wt switch new-project staging)"

# Check everything is working
wt doctor
```

### Working on multiple related features

```bash
# Create worktrees for each feature
wt add myapp feature/api-endpoints
wt add myapp feature/frontend-components
wt add myapp feature/integration-tests

# See all of them at once
wt status myapp

# Keep them all updated
wt pull-all myapp
```

### Investigating a bug on a specific branch

```bash
# Create worktree for the problematic branch
wt add myapp bugfix/investigate-issue-123

# Open tinker to poke around
wt tinker myapp bugfix/investigate-issue-123

# Check recent commits
wt log myapp bugfix/investigate-issue-123

# Run specific artisan commands
wt exec myapp bugfix/investigate-issue-123 php artisan route:list
```

## Using wt with Claude Code

Git worktrees and Claude Code are a powerful combination. Each worktree runs as a **completely isolated Claude Code session**, enabling true parallel AI-assisted development.

### Basic Workflow

```bash
# Create worktree
wt add myapp feature/user-avatars

# Navigate to it and start Claude Code
cd "$(wt cd myapp feature/user-avatars)"
claude

# In another terminal, work on a different feature with another Claude session
cd "$(wt cd myapp feature/payments)"
claude
```

### Session Management Across Worktrees

Claude Code recognises sessions across all worktrees in the same repository:

```bash
# Inside Claude, see sessions from ALL worktrees
/resume

# Name sessions for easy switching
/rename user-avatars-feature

# Resume by name from command line
claude --resume user-avatars-feature

# Continue most recent session in this worktree
claude --continue
```

### The `switch` + Claude Pattern

The `wt switch` command pairs perfectly with Claude Code:

```bash
# Switch context completely (opens editor + browser, prints path)
cd "$(wt switch myapp)"
claude    # Start or resume Claude session
```

### CLAUDE.md with Worktrees

| File | Scope | Use case |
|------|-------|----------|
| `./CLAUDE.md` | Shared across all worktrees | Project conventions, committed to repo |
| `./.claude/CLAUDE.local.md` | Per-worktree only | Personal preferences, gitignored |
| `~/.claude/CLAUDE.md` | Global, all projects | Your personal defaults |

Since all worktrees share the same Git history, your project `CLAUDE.md` is automatically available in every worktree.

### Parallel Development Patterns

**Pattern 1: Claude works while you review**

```bash
# Terminal 1: Claude implements a feature
cd "$(wt cd myapp feature/auth)"
claude
# "Implement OAuth2 login with Google..."

# Terminal 2: You review and test another feature
cd "$(wt cd myapp feature/dashboard)"
wt open myapp feature/dashboard  # Test in browser
```

**Pattern 2: Multiple Claude sessions**

```bash
# Terminal 1: Claude on backend
cd "$(wt cd myapp feature/api-endpoints)"
claude --resume api-work

# Terminal 2: Claude on frontend
cd "$(wt cd myapp feature/frontend-components)"
claude --resume frontend-work
```

**Pattern 3: Quick context switch**

```bash
# Working on feature, need to check something on staging
cd "$(wt switch myapp staging)"
claude
# "Show me how the payment flow currently works"

# Switch back to your feature
cd "$(wt switch myapp feature/payments)"
claude --continue
```

### Tips for Claude Code + Worktrees

1. **Name your sessions early** - Use `/rename feature-name` so you can easily resume later
2. **Use descriptive branch names** - They help Claude understand context
3. **One task per worktree** - Keep Claude sessions focused on specific features
4. **Document in CLAUDE.md** - Add your worktree workflow to help Claude understand your setup

### Example CLAUDE.md Addition

Add this to your project's `CLAUDE.md`:

```markdown
## Worktree Development

This project uses Git worktrees for parallel development:
- Each feature gets its own worktree via `wt add`
- Worktrees are at `~/Herd/<repo>--<branch-slug>/`
- Each worktree has its own database: `<repo>__<branch_slug>`
- URLs follow pattern: `https://<repo>--<branch-slug>.test`

Common commands:
- `wt ls myapp` - List all worktrees
- `wt switch myapp` - Switch to a worktree (with fzf)
- `wt fresh myapp <branch>` - Reset database and rebuild
```
