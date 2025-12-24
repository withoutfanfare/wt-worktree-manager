# Changelog

All notable changes to the `wt` Git Worktree Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
