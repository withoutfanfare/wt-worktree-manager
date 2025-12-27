# wt Tutorials (Onboarding + Recipes)

This document is a **recipe-style onboarding guide** for `wt`. Every command shown is copy/paste-able, and each `wt` command has at least one working example.

If you’re brand new to worktrees, skim the “Golden Rule” section in `README.md` first.

## Quick Start (10 minutes)

```bash
# 1) Install / update wt
git clone https://github.com/dannyharding10/wt-worktree-manager.git ~/Projects/wt-worktree-manager
cd ~/Projects/wt-worktree-manager
./install.sh

# 2) New terminal (so PATH updates), then sanity check
wt --version
wt doctor

# 3) Clone a project into Herd (creates a bare repo + a default worktree)
wt clone git@github.com:org/myapp.git

# 4) Create a new worktree for a feature branch
wt add myapp feature/login

# 5) Jump into it (path printed; you choose how to cd)
cd "$(wt cd myapp feature/login)"
```

## Concepts (the 30-second mental model)

- `wt clone` creates a **bare** git repo at `~/Herd/<repo>.git` (by default).
- Every branch you work on gets its own folder: `~/Herd/<repo>--<branch-slug>/`.
- **One branch per worktree**: don’t `git checkout` to another branch inside a worktree; use `wt add` / `wt switch` instead.

## Table of Contents

- [Core workflow](#core-workflow)
- [Command cookbook (all commands)](#command-cookbook-all-commands)
- [Templates](#templates)
- [Hooks](#hooks)
- [Automation (JSON output)](#automation-json-output)
- [Troubleshooting recipes](#troubleshooting-recipes)

---

## Core workflow

### Create → open → keep in sync

```bash
# Create worktree for a new branch (base defaults to WT_BASE_DEFAULT / DEFAULT_BASE)
wt add myapp feature/payments

# Open it in your editor (auto-detects when run inside a worktree)
wt code myapp feature/payments

# Open its URL in a browser (uses APP_URL from .env if present, otherwise https://<folder>.test)
wt open myapp feature/payments

# Keep your feature branch up to date with the base branch (default: origin/staging)
wt sync myapp feature/payments
```

### Remove when done

```bash
# Remove the worktree directory and git worktree entry
wt rm myapp feature/payments

# Also delete the git branch (local + remote where possible)
wt rm myapp feature/payments --delete-branch
```

---

## Command cookbook (all commands)

Notes:
- Commands marked “auto-detect” can infer `<repo>` / `<branch>` if you run them *inside a worktree directory*.
- If `fzf` is installed, many commands will let you omit `<branch>` and pick interactively.

### `wt doctor`

```bash
wt doctor
```

### `wt repos`

```bash
wt repos
```

### `wt clone` — clone as a bare repo (and create a default worktree)

```bash
# Uses the repo name inferred from URL ("myapp")
wt clone git@github.com:org/myapp.git

# Explicit name + create a worktree for an initial branch
wt clone git@github.com:org/myapp.git myapp feature/login
```

### `wt add` — create a worktree

```bash
# Create (or check out) a branch worktree
wt add myapp feature/login

# Create using an explicit base
wt add myapp feature/login origin/main

# Preview without changing anything
wt add myapp feature/login --dry-run

# Guided interactive wizard
wt add --interactive
```

### `wt rm` — remove a worktree

```bash
wt rm myapp feature/login

# Force removal of protected branches (defaults: staging, main, master)
wt rm -f myapp staging

# Also delete the branch (use with care)
wt rm myapp feature/login --delete-branch

# Hook-friendly flags (used by the example hooks)
wt rm myapp feature/login --drop-db
wt rm myapp feature/login --no-backup
```

### `wt ls` — list worktrees for a repo

```bash
wt ls myapp
wt ls myapp --json
```

### `wt status` — dashboard for a single repo

```bash
wt status myapp
wt status myapp --json
```

### `wt dashboard` — overview of all repos

```bash
wt dashboard
```

### `wt pull` (auto-detect)

```bash
# From inside a worktree: auto-detect repo/branch
wt pull

# Or specify explicitly
wt pull myapp feature/login
```

### `wt pull-all` — pull every worktree (parallel)

```bash
wt pull-all myapp

# Across all repositories
wt pull-all --all-repos
```

### `wt sync` — rebase onto a base branch (auto-detect)

```bash
# From inside a worktree
wt sync

# Explicit base
wt sync myapp feature/login origin/main
```

### `wt diff` — compare against base (auto-detect)

```bash
# From inside a worktree
wt diff

# Explicit base
wt diff myapp feature/login origin/main
```

### `wt log` — recent commits (auto-detect)

```bash
# From inside a worktree
wt log

# Explicit
wt log myapp feature/login
```

### `wt prune` — clean up stale worktrees / references

```bash
wt prune myapp
```

### `wt exec` — run any command inside a worktree

```bash
wt exec myapp feature/login php artisan migrate
wt exec myapp feature/login npm test
```

### `wt exec-all` — run a command on all worktrees

```bash
wt exec-all myapp "php artisan about"

# Across all repositories
wt exec-all --all-repos "git status --porcelain"
```

### `wt build-all` — `npm run build` for all worktrees

```bash
wt build-all myapp
wt build-all --all-repos
```

### `wt fresh` — `migrate:fresh --seed` + npm install/build (auto-detect)

```bash
# From inside a worktree
wt fresh

# Or explicit
wt fresh myapp feature/login

# Skip confirmation prompts
wt fresh -f myapp feature/login
```

### `wt migrate` — run `php artisan migrate` (auto-detect)

```bash
wt migrate
wt migrate myapp feature/login
```

### `wt tinker` — run `php artisan tinker` (auto-detect)

```bash
wt tinker
wt tinker myapp feature/login
```

### `wt code` — open worktree in your editor (auto-detect)

```bash
wt code
wt code myapp feature/login
```

### `wt open` — open worktree URL in browser (auto-detect)

```bash
wt open
wt open myapp feature/login
```

### `wt cd` — print the worktree path (auto-detect)

```bash
cd "$(wt cd myapp feature/login)"

# From inside a worktree (prints the current worktree path)
cd "$(wt cd)"
```

### `wt switch` — cd path + open editor + open browser

```bash
# With fzf installed, omit branch to pick interactively
wt switch myapp

# Or explicit
cd "$(wt switch myapp feature/login)"
```

### `wt info` — detailed worktree information (auto-detect)

```bash
wt info myapp feature/login
wt info              # from inside a worktree
```

### `wt recent` — recently accessed worktrees

```bash
wt recent
wt recent 10
```

### `wt clean` — remove dependencies from inactive worktrees

```bash
# Preview what would be removed
wt clean myapp --dry-run

# Actually remove node_modules/vendor in inactive worktrees
wt clean myapp

# Across all repositories
wt clean
```

### `wt health` — repository health checks

```bash
wt health myapp
```

### `wt report` — generate a markdown report

```bash
# Print to stdout
wt report myapp

# Save to a file
wt report myapp --output /tmp/wt-report-myapp.md
```

### `wt cleanup-herd` — remove orphaned Herd nginx configs

```bash
wt cleanup-herd
```

### `wt unlock` — remove stale git lock files

```bash
wt unlock myapp

# Across all repositories
wt unlock
```

### `wt repair` — fix common issues

```bash
wt repair
wt repair myapp
```

### `wt templates` — view available templates

```bash
wt templates
wt templates minimal
```

### `wt alias` — manage branch aliases

Aliases are stored as `name=repo/branch` lines in `~/.wt/aliases`.

```bash
# List
wt alias
wt alias list

# Add (or overwrite)
wt alias add login myapp/feature/login
wt alias set staging myapp/staging

# Remove
wt alias rm login
wt alias remove staging
```

### `wt upgrade` — self-update

```bash
wt upgrade
```

### `wt --version` / `wt --version --check`

```bash
wt --version
wt --version --check
```

---

## Templates

Templates are small `.conf` files in `~/.wt/templates/` that set `WT_SKIP_*` flags for your hooks.

```bash
# Install the example templates shipped with this repo
mkdir -p ~/.wt/templates
cp examples/templates/*.conf ~/.wt/templates/

# List + inspect
wt templates
wt templates laravel

# Use a template when creating a worktree
wt add myapp feature/api --template=backend
```

---

## Hooks

Hooks are optional scripts under `~/.wt/hooks/` that run during the worktree lifecycle (pre/post add, pre/post rm, post pull, post sync).

```bash
# Install the example hooks shipped with this repo (recommended starting point)
./install.sh

# Manual install (if you prefer)
mkdir -p ~/.wt/hooks
cp -R examples/hooks/* ~/.wt/hooks/
chmod +x ~/.wt/hooks/* ~/.wt/hooks/*/*.sh 2>/dev/null || true
```

Common hook points:
- `pre-add`, `post-add`
- `pre-rm`, `post-rm`
- `post-pull`, `post-sync`

The hook environment includes:
`WT_REPO`, `WT_BRANCH`, `WT_PATH`, `WT_URL`, `WT_DB_NAME`

---

## Automation (JSON output)

Some commands support `--json` (and optionally `--pretty`) for scripting.

```bash
wt repos --json
wt ls myapp --json
wt status myapp --json

# Pretty-print JSON (useful for humans)
wt ls myapp --json --pretty
```

---

## Troubleshooting recipes

### “I’m in the wrong branch in this folder”

If you switched branches inside a worktree by accident, the folder name and branch won’t match. Use:

```bash
wt status myapp
```

Then either:
- checkout the correct branch for that folder, or
- remove/recreate the worktree with `wt rm` / `wt add`.

### “Git says: index.lock exists” / “could not lock config file”

```bash
wt unlock myapp
```

### “Herd has configs for worktrees that no longer exist”

```bash
wt cleanup-herd
```

