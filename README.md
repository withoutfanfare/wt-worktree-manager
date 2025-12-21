# wt - Git Worktree Manager for Laravel Herd

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Laravel Herd](https://img.shields.io/badge/Laravel%20Herd-FF2D20?logo=laravel&logoColor=white)](https://herd.laravel.com/)

A command-line tool for managing Git worktrees with Laravel Herd integration. Work on multiple branches simultaneously without stashing or switching.

**Perfect for:** Laravel developers who work on multiple features/bugs in parallel and want each branch to have its own isolated environment with automatic database setup, HTTPS, and Herd integration.

## Features

- **Parallel Development** - Work on multiple branches simultaneously, each with its own URL
- **Automatic Environment Setup** - Creates `.env`, runs `composer install`, generates app key
- **Database Per Worktree** - Auto-creates MySQL databases, backs up on removal
- **Laravel Herd Integration** - HTTPS via `herd secure`, `.test` domains
- **Interactive Selection** - fzf-powered branch picking
- **Claude Code Integration** - Isolated AI sessions per worktree
- **macOS Notifications** - Get notified when long operations complete
- **Customisable Hooks** - Run your own scripts after worktree creation

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

## Requirements

| Requirement | Status | Notes |
|-------------|--------|-------|
| macOS | Required | Uses Herd and osascript |
| zsh | Required | Script is zsh-specific |
| Git 2.5+ | Required | Worktree support |
| [Laravel Herd](https://herd.laravel.com/) | Required | Site management |
| Composer | Required | Laravel dependency management |
| MySQL | Optional | Auto-creates databases per worktree |
| [fzf](https://github.com/junegunn/fzf) | Optional | Interactive branch selection |

## Installation

### Quick Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/wt-worktree-manager.git
cd wt-worktree-manager

# Run the installer
chmod +x install.sh
./install.sh
```

The installer will:
1. Check requirements
2. Install `wt` to `/usr/local/bin/`
3. Install zsh completions
4. Create a config file at `~/.wtrc`

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/wt-worktree-manager.git
cd wt-worktree-manager

# Copy the script
sudo cp wt /usr/local/bin/wt
sudo chmod +x /usr/local/bin/wt

# Set up completions
mkdir -p ~/.zsh/completions
cp _wt ~/.zsh/completions/

# Add to ~/.zshrc
echo 'fpath=(~/.zsh/completions $fpath)' >> ~/.zshrc
echo 'autoload -Uz compinit && compinit' >> ~/.zshrc

# Create config
cp .wtrc.example ~/.wtrc

# Reload shell
source ~/.zshrc
```

### Install fzf (Recommended)

fzf enables interactive branch selection:

```bash
brew install fzf
```

### Verify Installation

```bash
wt --version
wt doctor
```

### Tab Completion

After installation, you can use Tab to complete commands, repos, and branches:

```bash
wt pu<Tab>             # completes to 'pull' or 'pull-all'
wt pull my<Tab>        # completes to 'myapp'
wt pull myapp f<Tab>   # completes to available branches
```

### Uninstall

```bash
cd wt-worktree-manager
./uninstall.sh
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
| `WT_HOOKS_DIR` | `~/.wt/hooks` | Directory containing hook scripts |
| `WT_DB_HOST` | `127.0.0.1` | MySQL host for database operations |
| `WT_DB_USER` | `root` | MySQL user for database operations |
| `WT_DB_PASSWORD` | (empty) | MySQL password for database operations |
| `WT_DB_CREATE` | `true` | Auto-create database on `wt add` |
| `WT_DB_BACKUP` | `true` | Backup database on `wt rm` |
| `WT_DB_BACKUP_DIR` | `~/Code/Project Support/Worktree/Database/Backup` | Backup directory |
| `WT_PROTECTED_BRANCHES` | `staging main master` | Space-separated list of protected branches |

### Hooks

Hooks allow you to run custom scripts after certain wt operations. This is useful for automating setup steps specific to your workflow.

#### Available hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `post-add` | After `wt add` | Runs after worktree creation completes |

#### Creating a hook

1. Create the hooks directory:
   ```bash
   mkdir -p ~/.wt/hooks
   ```

2. Create an executable script with the hook name:
   ```bash
   # ~/.wt/hooks/post-add
   #!/bin/bash

   # Run npm install and build assets
   npm ci
   npm run build

   # Run database migrations
   php artisan migrate

   # Clear caches
   php artisan config:clear
   php artisan route:clear
   ```

3. Make it executable:
   ```bash
   chmod +x ~/.wt/hooks/post-add
   ```

#### Environment variables in hooks

Hooks receive context about the worktree via environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `WT_REPO` | Repository name | `myapp` |
| `WT_BRANCH` | Branch name | `feature/login` |
| `WT_PATH` | Worktree path | `/Users/you/Herd/myapp--feature-login` |
| `WT_URL` | Application URL | `https://myapp--feature-login.test` |
| `WT_DB_NAME` | Database name | `myapp__feature_login` |
| `WT_HOOK_NAME` | Current hook name | `post-add` |

#### Example: Conditional hook

```bash
#!/bin/bash
# ~/.wt/hooks/post-add

# Only run npm for repos that have package.json
if [[ -f "package.json" ]]; then
  npm ci
  npm run build
fi

# Only run migrations for Laravel projects
if [[ -f "artisan" ]]; then
  php artisan migrate
fi

# Log the creation
echo "$(date): Created $WT_REPO / $WT_BRANCH" >> ~/.wt/worktree.log
```

#### Multiple hooks

For complex setups, create a `.d` directory with numbered scripts:

```text
~/.wt/hooks/
├── post-add              # Single hook (runs first if exists)
└── post-add.d/           # Multiple hooks (run in order)
    ├── 01-npm.sh
    ├── 02-migrate.sh
    └── 03-notify.sh
```

All executable scripts in the `.d` directory run in alphabetical order.

#### Verify hooks with doctor

Check your hooks configuration:

```bash
wt doctor
```

Output includes:
```text
Hooks
✔ Hooks directory: /Users/you/.wt/hooks
✔   post-add: enabled
```

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
wt add <repo> <branch>          # Create worktree
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

# Cleanup
wt rm <repo> <branch>           # Remove worktree (backs up DB)
wt rm --drop-db <repo> <branch> # Remove and drop database
wt rm --no-backup <repo> <branch> # Remove without backup
wt prune -f <repo>              # Delete merged branches
```

## Commands Reference

### Core Commands

| Command | Description |
|---------|-------------|
| `wt add <repo> <branch> [base]` | Create a new worktree |
| `wt rm <repo> [branch]` | Remove a worktree |
| `wt ls <repo>` | List all worktrees with status |
| `wt repos` | List all repositories in HERD_ROOT |
| `wt clone <url> [name]` | Clone as bare repo (auto-creates staging) |

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
2. Creates the worktree directory at `~/Herd/<repo>--<branch-slug>/`
3. Pushes new branch to remote and sets correct tracking (prevents accidental pushes to wrong branch)
4. Copies `.env.example` to `.env` (if exists)
5. Sets `APP_URL` in `.env` to `https://<repo>--<branch-slug>.test`
6. Creates a MySQL database named `<repo>__<branch_slug>` (underscores for MySQL compatibility)
7. Sets `DB_DATABASE` in `.env` to the new database name
8. Secures the site with HTTPS via `herd secure`
9. Runs `composer install`
10. Generates Laravel app key

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

1. **Backs up the database** to `$DB_BACKUP_DIR/<repo>/<db_name>_<timestamp>.sql`
2. **Unsecures the site** via `herd unsecure`
3. Removes the worktree directory
4. Optionally deletes the local branch (with `--delete-branch`)
5. Prunes stale worktree references

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

[3] 📁 /Users/you/Herd/myapp--old-feature-name
    branch  🌿 feature/new-name
    ⚠️  MISMATCH: Directory suggests 'old-feature-name' but branch is 'feature/new-name'
    sha     i7j8k9l
    state   ● clean
    sync    ↑0 ↓0
    url     🌐 https://myapp--old-feature-name.test
    cd      cd '/Users/you/Herd/myapp--old-feature-name'
```

- **Mismatch warning**: Shown inline when a worktree's directory name doesn't match its checked-out branch (e.g., if someone ran `git checkout` inside the worktree instead of using `wt add`)

**JSON output:**
```bash
wt ls --json myapp
```
```json
[
  {"path": "/Users/you/Herd/myapp--staging", "branch": "staging", "sha": "a1b2c3d", "url": "https://myapp--staging.test", "dirty": false, "ahead": 0, "behind": 0, "mismatch": false},
  {"path": "/Users/you/Herd/myapp--feature-login", "branch": "feature/login", "sha": "e4f5g6h", "url": "https://myapp--feature-login.test", "dirty": true, "ahead": 5, "behind": 12, "mismatch": false},
  {"path": "/Users/you/Herd/myapp--old-feature-name", "branch": "feature/new-name", "sha": "i7j8k9l", "url": "https://myapp--old-feature-name.test", "dirty": false, "ahead": 0, "behind": 0, "mismatch": true}
]
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
| `wt clone <url> [name]` | Clone as bare repo (auto-creates staging) |
| `wt prune <repo>` | Clean up stale worktrees and merged branches |
| `wt exec <repo> <branch> <cmd>` | Run command in worktree |

#### The `clone` command

Clones a repository as a bare repo and automatically creates a staging worktree.

```bash
# Clone with auto-detected name
wt clone git@github.com:your-org/your-app.git

# Clone with custom name
wt clone git@github.com:your-org/your-app.git myapp
```

**What it does:**

1. Clones as a bare repository to `~/Herd/<repo>.git/`
2. Configures fetch to get all branches
3. Fetches all remote branches
4. **Automatically creates a worktree** for the first available branch: `staging`, `main`, or `master`

This means after cloning you can immediately start working:

```bash
wt clone git@github.com:your-org/your-app.git
wt code your-app staging  # Ready to go!
```

To skip auto-creation, you can manually remove the worktree or set up your preferred branch.

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

### Flags

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Suppress informational output |
| `-f, --force` | Skip confirmations, force operations |
| `--json` | Output in JSON format (for `ls` and `add`) |
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
| `rm` | `-f` (force), `--delete-branch`, `--drop-db`, `--no-backup` |
| `ls` | `--json` |
| `add` | `--json` |
| `prune` | `-f` (actually delete merged branches) |
| `repos` | `--json` |
| All | `-q` (quiet mode) |

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

Current version: **3.3.0**

Check with: `wt --version`

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
