# Changelog

All notable changes to the `wt` Git Worktree Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.7.0] - 2025-12-25

### Changed
- **Generic worktree manager** - Refactored `wt` to be a framework-agnostic git worktree manager. All Laravel-specific functionality (database creation, composer install, npm, Herd securing, migrations) has been moved into optional hooks
- **Hook-based architecture** - Worktree setup is now fully customisable via lifecycle hooks in `~/.wt/hooks/`. Install the example hooks for Laravel projects, or create your own for any framework

### Added
- **Comprehensive example hooks** for Laravel projects:
  - `00-register-project.sh` - Register worktree in `~/.projects` for quick navigation
  - `01-copy-env.sh` - Copy `.env.example` to `.env`
  - `02-configure-env.sh` - Set `APP_URL` and `DB_DATABASE` in `.env`
  - `03-create-database.sh` - Create MySQL database
  - `04-herd-secure.sh` - Secure site with Herd HTTPS
  - `05-composer-install.sh` - Run `composer install` + generate app key
  - `06-npm-install.sh` - Run `npm install`
  - `07-build-assets.sh` - Run `npm run build`
  - `08-run-migrations.sh` - Run Laravel migrations
  - `pre-rm.d/01-backup-database.sh` - Backup database before removal
  - `post-rm.d/01-herd-unsecure.sh` - Remove Herd SSL config
  - `post-rm.d/02-drop-database.sh` - Drop database (opt-in via `--drop-db`)
- **Repo-specific hooks** - Create subdirectories matching repo names (e.g., `post-add.d/myapp/`) for hooks that only run for specific repositories
- **Per-repository config** - Load `.wtconfig` from bare repo directory (e.g., `~/Herd/myapp.git/.wtconfig`) for repo-specific settings like `DEFAULT_BASE`
- **Hook control flags** - Skip specific hooks via environment variables: `WT_SKIP_DB`, `WT_SKIP_COMPOSER`, `WT_SKIP_NPM`, `WT_SKIP_BUILD`, `WT_SKIP_MIGRATE`, `WT_SKIP_HERD`
- **Installer merge/overwrite modes** - Run `./install.sh --merge` to add new example hooks without overwriting existing ones, or `--overwrite` to replace all hooks (backs up first)

### Fixed
- **Hooks not running** - Fixed zsh glob qualifier order bug where `*(.x)(N)` didn't match executable files. Corrected to `*(N.x)` (null glob must come first)
- **URL generation** - Fixed `url_for()` to include repository name, generating correct URLs like `https://myapp--feature-login.test` instead of just `https://feature-login.test`
- **Repo-specific config loading** - Fixed `DEFAULT_BASE` not being loaded from per-repo `.wtconfig` files

## [3.6.0] - 2025-12-24

### Security
- **Config file hardening** - Configuration files are now parsed as key-value pairs instead of sourced, preventing arbitrary code execution via malicious `.wtrc` files
- **Hook execution security** - Hooks are now verified to be owned by the current user and not world-writable before execution
- **Input validation hardening** - Added protection against absolute paths, git flag injection (branches starting with `-`), reserved git references (`HEAD`, `refs/`), and malformed paths

### Added
- **`wt health <repo>`** - New command to check repository health (stale worktrees, orphaned databases, missing .env files, branch mismatches)
- **`wt report <repo>`** - New command to generate markdown status report with worktree summary, status, and hook availability
- **`wt clone` branch argument** - Clone and create worktree for a specific branch in one command: `wt clone <url> [name] [branch]`
  - If branch exists on remote, creates worktree for it
  - If branch doesn't exist, creates new branch from staging/main/master
- **Additional lifecycle hooks** - Added `pre-add`, `pre-rm`, `post-pull`, and `post-sync` hooks alongside existing `post-add` and `post-rm`
  - Pre-hooks can abort operations by returning non-zero exit code
- Database names are now automatically truncated with a hash suffix if they exceed MySQL's 64-character limit
- Confirmation prompt before `wt fresh` runs `migrate:fresh` (use `-f` to skip)

### Fixed
- Explicitly fetch remote base branches when using `origin/...` to ensure the latest version is used
- Branches with slashes (e.g., `origin/proj-jl/rethink`) are now properly fetched before creating worktrees

## [3.4.0] - 2025-12-23

### Added
- `wt cleanup` command to remove orphaned Herd nginx configurations and certificates
- `wt unlock` command to safely remove stale git lock files
- Helper to clean individual Herd site configs when unsecuring sites

### Fixed
- Improved temporary directory handling with explicit paths for safer cleanup during parallel pulls
- Prevents nginx startup failures caused by stale Herd configuration files

## [3.3.1] - 2025-12-21

### Changed
- URLs now use just the feature name instead of repo--branch format
  - Example: `feature/sms-unsubscribe` becomes `sms-unsubscribe.test` (was `scooda--feature-sms-unsubscribe.test`)

### Added
- `WT_URL_SUBDOMAIN` config option for subdomain prefix (e.g., `WT_URL_SUBDOMAIN=api` gives `api.sms-unsubscribe.test`)
- `wt ls` now reads `APP_URL` from `.env` when available

### Documentation
- Added "Golden Rule" section explaining that each worktree is a permanent home for one branch
- Documented safe vs unsafe git operations within worktrees
- Added guidance on fixing accidental branch switches

## [3.3.0] - 2025-12-21

### Added
- Branch/directory mismatch detection in `wt ls` and `wt status`
  - Warns when a worktree's directory name doesn't match its checked-out branch
- Automatic remote tracking setup when creating new branches
  - New branches are pushed and set to track their own remote branch
- JSON output now includes `mismatch` field in `wt ls --json`

### Fixed
- Fixed branch tracking issue where new branches could track wrong remote
- Worktrees now created with `--no-track` to prevent inheriting base branch tracking

## [3.2.1] - 2025-12-21

### Fixed
- Minor bug fixes and stability improvements

## [3.2.0] - 2025-12-20

### Added
- Initial public release
- Core worktree management: `add`, `rm`, `ls`, `repos`
- Navigation commands: `cd`, `code`, `open`, `switch`
- Git operations: `pull`, `pull-all`, `sync`, `status`
- Laravel integration: `fresh`, `migrate`, `tinker`, `log`
- Maintenance: `clone`, `prune`, `exec`, `doctor`
- Automatic `.env` setup with unique `APP_URL` per worktree
- Automatic MySQL database creation per worktree
- Laravel Herd integration with HTTPS via `herd secure`
- fzf integration for interactive branch selection
- Tab completion for zsh
- JSON output mode for scripting
- Protected branch safety (staging, main, master require `-f` to remove)
- Database backup on worktree removal
- macOS desktop notifications for long operations
- Parallel execution for `pull-all`

### Features from 3.0.0 (pre-public development)
- New commands: `repos`, `doctor`, `fresh`, `switch`, `migrate`, `tinker`, `log`
- Parallel `pull-all` for concurrent worktree updates
- Auto-create staging worktree on `clone`
- `--drop-db` flag to drop database after backup
- `--no-backup` flag to skip database backup on removal
