# Lifecycle Hooks

wt supports lifecycle hooks that run automatically during worktree operations. All worktree setup (database, .env, composer, npm, Herd) is handled via hooks, making wt highly customisable.

## Quick Start

```bash
# Install all example hooks (recommended for Laravel projects)
./install.sh --merge

# Or manually copy specific hooks
cp examples/hooks/post-add.d/03-create-database.sh ~/.wt/hooks/post-add.d/
cp examples/hooks/post-add.d/05-composer-install.sh ~/.wt/hooks/post-add.d/
```

## Architecture

wt is a **generic git worktree manager**. All framework-specific setup (Laravel, Node.js, etc.) is handled via hooks:

```text
wt add myapp feature/new
    │
    ├── Git: Create worktree
    ├── Git: Set up remote tracking
    │
    └── Run post-add hooks:
        ├── 01-copy-env.sh         # Copy .env.example → .env
        ├── 02-configure-env.sh    # Set APP_URL, DB_DATABASE
        ├── 03-create-database.sh  # Create MySQL database
        ├── 04-herd-secure.sh      # Secure with HTTPS
        ├── 05-composer-install.sh # composer install
        ├── 06-npm-install.sh      # npm install
        ├── 07-build-assets.sh     # npm run build
        ├── 08-run-migrations.sh   # php artisan migrate
        │
        └── myapp/                 # Repo-specific hooks
            ├── 01-symlink-env.sh  # Override with symlinked .env
            └── 02-import-database.sh
```

## Directory Structure

```text
~/.wt/hooks/
├── pre-add                     # Single script (runs first)
├── pre-add.d/                  # Multiple scripts (run in order)
│   └── *.sh
│
├── post-add                    # Single script
├── post-add.d/                 # Multiple scripts
│   ├── 00-register-project.sh  # Register in projects file
│   ├── 01-copy-env.sh          # Copy .env.example → .env
│   ├── 02-configure-env.sh     # Set APP_URL, DB_DATABASE
│   ├── 03-create-database.sh   # Create MySQL database
│   ├── 04-herd-secure.sh       # Secure with Herd HTTPS
│   ├── 05-composer-install.sh  # composer install + key:generate
│   ├── 06-npm-install.sh       # npm install
│   ├── 07-build-assets.sh      # npm run build
│   ├── 08-run-migrations.sh    # php artisan migrate
│   │
│   ├── myapp/                  # Repo-specific hooks for 'myapp'
│   │   ├── 01-symlink-env.sh   # Symlink to pre-built .env
│   │   └── 02-import-database.sh
│   │
│   └── scooda/                 # Repo-specific hooks for 'scooda'
│       └── 01-custom-setup.sh
│
├── pre-rm                      # Before worktree removal (can abort)
├── pre-rm.d/
│   └── 01-backup-database.sh   # Backup before removal
│
├── post-rm                     # After worktree removal
├── post-rm.d/
│   ├── 01-herd-unsecure.sh     # Remove Herd SSL
│   ├── 02-drop-database.sh     # Drop database (if --drop-db)
│   └── myapp/
│       └── 01-cleanup-logs.sh
│
├── post-pull.d/                # After wt pull succeeds
│   └── *.sh
│
└── post-sync.d/                # After wt sync succeeds
    └── *.sh
```

## Execution Order

1. **Single script** (`post-add`) runs first
2. **Global hooks** (`post-add.d/*.sh`) run in alphabetical order
3. **Repo-specific hooks** (`post-add.d/<repo>/*.sh`) run last

Example for `myapp` repo:
```text
00-register-project.sh    (global)
01-copy-env.sh            (global)
02-configure-env.sh       (global)
03-create-database.sh     (global)
04-herd-secure.sh         (global)
05-composer-install.sh    (global)
06-npm-install.sh         (global)
07-build-assets.sh        (global)
08-run-migrations.sh      (global)
myapp/01-symlink-env.sh   (repo)   ← Replaces .env with symlink
myapp/02-import-database.sh (repo) ← Imports SQL dump
```

## Available Hooks

| Hook | When | Can Abort? | Use Case |
|------|------|------------|----------|
| `pre-add` | Before worktree creation | Yes (exit 1) | Validation, resource checks |
| `post-add` | After worktree creation | No | Setup: .env, database, composer, npm |
| `pre-rm` | Before worktree removal | Yes (exit 1) | Database backup, validation |
| `post-rm` | After worktree removal | No | Cleanup: Herd, database drop |
| `post-pull` | After `wt pull` succeeds | No | Cache clear, migrations |
| `post-sync` | After `wt sync` succeeds | No | Rebuild after rebase |

## Environment Variables

Available in all hooks:

| Variable | Example | Description |
|----------|---------|-------------|
| `WT_REPO` | `myapp` | Repository name |
| `WT_BRANCH` | `feature/new-feature` | Branch name |
| `WT_PATH` | `/Users/you/Herd/myapp--feature-new-feature` | Worktree directory path |
| `WT_URL` | `https://myapp--feature-new-feature.test` | Local development URL |
| `WT_DB_NAME` | `myapp__feature_new_feature` | Generated database name |
| `WT_HOOK_NAME` | `post-add` | Current hook being executed |
| `WT_NO_BACKUP` | `true` | Set when `--no-backup` flag used |
| `WT_DROP_DB` | `true` | Set when `--drop-db` flag used |

## Example Hooks Included

### Global Hooks (post-add.d/)

| Hook | Purpose |
|------|---------|
| `00-register-project.sh` | Register worktree in `~/.projects` for quick navigation |
| `01-copy-env.sh` | Copy `.env.example` to `.env` |
| `02-configure-env.sh` | Set `APP_URL` and `DB_DATABASE` in `.env` |
| `03-create-database.sh` | Create MySQL database |
| `04-herd-secure.sh` | Secure site with Herd HTTPS |
| `05-composer-install.sh` | Run `composer install` + generate app key |
| `06-npm-install.sh` | Run `npm install` |
| `07-build-assets.sh` | Run `npm run build` if build script exists |
| `08-run-migrations.sh` | Run Laravel migrations |

### Repo-Specific Hooks (post-add.d/myapp/)

| Hook | Purpose |
|------|---------|
| `01-symlink-env.sh` | Replace `.env` with symlink to pre-built version |
| `02-import-database.sh` | Import database from gzipped SQL dump |
| `03-seed-data.sh` | Seed database with development data |

### Pre-Removal Hooks (pre-rm.d/)

| Hook | Purpose |
|------|---------|
| `01-backup-database.sh` | Backup database before removal |

### Post-Removal Hooks (post-rm.d/)

| Hook | Purpose |
|------|---------|
| `01-herd-unsecure.sh` | Remove Herd SSL and nginx config |
| `02-drop-database.sh` | Drop database (only if `--drop-db` flag) |

## Control Flags

Skip specific hooks by setting environment variables:

```bash
# Skip database creation
WT_SKIP_DB=true wt add myapp feature/no-db

# Skip composer install
WT_SKIP_COMPOSER=true wt add myapp feature/quick

# Skip all npm operations
WT_SKIP_NPM=true WT_SKIP_BUILD=true wt add myapp feature/backend-only
```

## Common Patterns

### Pre-built .env Files

Keep your secrets in one place and symlink from worktrees:

```bash
# Create env storage directory
mkdir -p ~/Code/Worktree/myapp/myapp-env

# Create your .env with all secrets
cp /path/to/configured/.env ~/Code/Worktree/myapp/myapp-env/.env

# Create repo-specific hook to symlink it
mkdir -p ~/.wt/hooks/post-add.d/myapp
cat > ~/.wt/hooks/post-add.d/myapp/01-symlink-env.sh << 'EOF'
#!/bin/bash
ENV_SOURCE="$HOME/Code/Worktree/myapp/myapp-env/.env"
if [[ -f "$ENV_SOURCE" ]]; then
  rm -f "${WT_PATH}/.env"
  ln -sf "$ENV_SOURCE" "${WT_PATH}/.env"
  echo "  Linked .env → $ENV_SOURCE"
fi
EOF
chmod +x ~/.wt/hooks/post-add.d/myapp/01-symlink-env.sh
```

### Import Database from SQL Dump

For repos that need a baseline database:

```bash
# Store your SQL dump
mkdir -p ~/Code/Worktree/myapp/myapp-db
mysqldump myapp_reference | gzip > ~/Code/Worktree/myapp/myapp-db/myapp.sql.gz

# Create repo-specific hook
cat > ~/.wt/hooks/post-add.d/myapp/02-import-database.sh << 'EOF'
#!/bin/bash
DB_DUMP="$HOME/Code/Worktree/${WT_REPO}/${WT_REPO}-db/${WT_REPO}.sql.gz"
if [[ -f "$DB_DUMP" ]]; then
  echo "  Importing database..."
  gunzip -c "$DB_DUMP" | mysql "$WT_DB_NAME"
fi
EOF
chmod +x ~/.wt/hooks/post-add.d/myapp/02-import-database.sh
```

### Quick Project Navigation

Register worktrees for quick access with `cproj`:

```bash
# Add to ~/.zshrc:
cproj() {
  local dir=$(grep "^$1=" ~/.projects 2>/dev/null | cut -d= -f2)
  if [[ -n "$dir" && -d "$dir" ]]; then
    cd "$dir"
  else
    echo "Project not found: $1"
    echo "Available: $(cut -d= -f1 ~/.projects | tr '\n' ' ')"
  fi
}

# Tab completion for cproj
_cproj() {
  compadd $(cut -d= -f1 ~/.projects 2>/dev/null)
}
compdef _cproj cproj
```

Then use: `cproj myapp--feature-login`

### Non-Laravel Projects

For projects without Laravel/PHP, disable those hooks:

```bash
# Create a repo-specific skip file
mkdir -p ~/.wt/hooks/post-add.d/frontend-app
cat > ~/.wt/hooks/post-add.d/frontend-app/00-skip-laravel.sh << 'EOF'
#!/bin/bash
# Skip Laravel-specific hooks for this repo
export WT_SKIP_DB=true
export WT_SKIP_COMPOSER=true
echo "  Skipping Laravel setup for frontend-only repo"
EOF
chmod +x ~/.wt/hooks/post-add.d/frontend-app/00-skip-laravel.sh
```

Or simply don't install the Laravel hooks and only use what you need.

## Tips

- **Numbering**: Use `00-`, `01-`, etc. to control execution order
- **Permissions**: All hooks must be executable (`chmod +x`)
- **Conditionals**: Check if files exist before running commands
- **Output**: Prefix messages with spaces (`echo "  message"`) for clean output
- **Failures**: Hooks continue even if one fails (except pre-* hooks which can abort)
- **Security**: Hooks must be owned by you and not world-writable

## Migrating from Built-in Setup

If you were using wt before hooks were introduced, the built-in Laravel setup is now handled by hooks. Run the installer with `--merge` to get the example hooks:

```bash
cd ~/Projects/wt-worktree-manager
./install.sh --merge
```

This will install the example hooks without overwriting any custom hooks you may have.
