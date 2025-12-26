# wt-worktree-manager Enhancement Roadmap

A prioritised roadmap for future development of the wt worktree manager.

---

## Overview

**Current State (v4.0.0):**
- Mature, production-ready Git worktree manager
- Framework-agnostic with hook-based extensibility
- **28 commands** covering full worktree lifecycle
- Comprehensive documentation
- macOS/Zsh focused
- **187 automated tests** (BATS test suite)
- **Template system** for standardised worktree setups
- **Enhanced status dashboard** with stale/merge indicators
- **Modular architecture** with 18 focused modules in `lib/`
- **Interactive mode** for guided worktree creation
- **Progress indicators** (spinners) for long operations
- **Parallel operations** (build-all, exec-all)
- **Resilience improvements** (repair, lock cleanup, retry logic)

**Key Gaps Identified:**
- macOS-only (no Linux/WSL support)
- Limited CI/CD integration (shellcheck + BATS locally, no GitHub Actions yet)
- No plugin ecosystem

---

## Phase 1: Foundation & Quality (High Priority)

### 1.1 Automated Testing Framework ✅ COMPLETE (v3.8.0)
**Why:** Critical for reliability and contribution confidence

- [x] Create `tests/` directory structure
- [x] Implement BATS (Bash Automated Testing System) test suite
- [x] Test categories:
  - Unit tests for helper functions (validation, path resolution)
  - Integration tests for commands (in isolated temp directories)
  - Security tests (config parsing, hook verification, input validation)
- [x] Add test fixtures (mock repos, sample configs)
- [x] **187 tests** covering all critical paths

**Implemented structure:**
```text
tests/
├── unit/
│   ├── validation.bats        # Input validation, security
│   ├── slugify.bats           # Branch name slugification
│   ├── db-naming.bats         # Database name generation
│   ├── url-generation.bats    # URL/path generation
│   ├── json-escape.bats       # JSON escaping
│   ├── config-parsing.bats    # Config file parsing
│   └── template-security.bats # Template security tests
├── integration/
│   └── commands.bats          # CLI parsing, help, validation
└── test-helper.bash           # Shared test utilities
```

Run with: `./run-tests.sh` (all), `./run-tests.sh unit`, `./run-tests.sh integration`, `./run-tests.sh lint`

### 1.2 CI/CD Pipeline 🔄 PARTIAL (v3.9.0)
**Why:** Automated quality gates for contributions

- [x] Shellcheck linting (local via `./run-tests.sh lint`)
- [x] BATS test suite execution (local via `./run-tests.sh`)
- [x] `.shellcheckrc` configuration for zsh compatibility
- [ ] GitHub Actions workflow for automated PR checks
- [ ] Version tag releases
- [ ] Pre-commit hooks for contributors
- [ ] Automated changelog generation from conventional commits

### 1.3 Code Modularisation ✅ COMPLETE (v4.0.0)
**Why:** 3,162-line monolith was difficult to maintain

- [x] Split into modular files (18 modules):
  ```text
  lib/
  ├── 00-header.sh      # Version, global defaults
  ├── 01-core.sh        # Config loading, colours, output helpers
  ├── 02-validation.sh  # Input validation, security
  ├── 03-paths.sh       # Path resolution, URL generation
  ├── 04-git.sh         # Git operations, branch helpers
  ├── 05-database.sh    # MySQL operations
  ├── 06-hooks.sh       # Hook system with security
  ├── 07-templates.sh   # Template loading
  ├── 08-spinner.sh     # Progress indicators (NEW)
  ├── 09-parallel.sh    # Parallel execution (NEW)
  ├── 10-interactive.sh # Interactive wizard (NEW)
  ├── 11-resilience.sh  # Retry, transactions (NEW)
  ├── 99-main.sh        # Entry point, usage, flags
  └── commands/
      ├── lifecycle.sh  # add, rm, clone, fresh
      ├── git-ops.sh    # pull, pull-all, sync, prune
      ├── navigation.sh # code, open, cd, switch, exec
      ├── info.sh       # ls, status, repos, health, report
      ├── utility.sh    # doctor, cleanup-herd, unlock, repair
      └── laravel.sh    # migrate, tinker
  ```

- [x] `build.sh` concatenates modules into single `wt` file for distribution
- [x] Backwards compatible (single-file install still works)

---

## Phase 2: Cross-Platform Support (High Priority)

### 2.1 Linux Support
**Why:** Expand user base significantly

- [ ] Abstract macOS-specific commands:
  - `open` → `xdg-open` on Linux
  - Herd paths → configurable web server root
- [ ] Test on Ubuntu, Fedora, Arch
- [ ] Document Linux-specific setup (Valet Linux, ServBay, etc.)
- [ ] Add platform detection in `wt doctor`

### 2.2 WSL2 Support
**Why:** Windows developers using WSL

- [ ] Handle Windows path translation
- [ ] Support Windows browsers from WSL
- [ ] Document WSL-specific configuration
- [ ] Test with Docker Desktop integration

### 2.3 Bash Compatibility
**Why:** Broader shell support

- [ ] Port to POSIX-compliant shell where possible
- [ ] Maintain Zsh-specific features as optional enhancements
- [ ] Bash completion script (`_wt.bash`)

---

## Phase 3: User Experience Improvements (Medium Priority)

### 3.1 Interactive Mode ✅ COMPLETE (v4.0.0)
**Why:** Guided workflows for new users

- [x] `wt add --interactive` / `-i` with 5-step wizard:
  1. Select repository (fzf picker)
  2. Choose base branch (fzf picker)
  3. Name new branch (with live preview of path, URL, database)
  4. Select template (optional fzf picker)
  5. Confirm with full summary
- [x] Requires fzf to be installed (die with install instructions if missing)
- [ ] `wt setup` wizard for first-time configuration

### 3.2 Enhanced Status Dashboard ✅ COMPLETE (v3.8.0)
**Why:** Better visibility into worktree state

- [x] `wt status` improvements:
  - Show uncommitted changes count (STATE column)
  - Display ahead/behind remote (SYNC column)
  - Indicate stale worktrees (🔴 marker for >50 commits behind)
  - Show last activity timestamp (AGE column: 1d, 2w, 3mo)
  - Show merge status (MERGED column: ✓ if merged to base)
- [x] Colour-coded health indicators (red for stale, yellow for inactive >30 days)
- [x] JSON output option for scripting: `wt status <repo> --json`

**New columns:** AGE, MERGED, stale indicator in SYNC column

### 3.3 Smart Branch Suggestions 🔄 PARTIAL (v3.9.0)
**Why:** Reduce typing and errors

- [x] "Did you mean?" suggestions for mistyped template names (fuzzy matching)
- [ ] Fuzzy matching for branch names: `wt cd scooda feat-auth` → `feature/auth-improvements`
- [ ] Recent branches shortcut: `wt cd scooda @1` (most recent)
- [ ] Branch name autocomplete from remote

### 3.4 Progress Indicators ✅ COMPLETE (v4.0.0)
**Why:** Long operations feel unresponsive

- [x] Spinner animation (Braille pattern) for long operations:
  - `spinner_start "message"` / `spinner_stop "ok|fail|skip"`
  - `with_spinner "message" command...` - Wrap commands with progress
  - Step progress indicator for multi-step operations
- [x] Spinner available for hooks to use in `composer install`, `npm ci`, etc.
- [x] Progress indication in `pull-all` and parallel operations
- [ ] Estimated time remaining for builds

---

## Phase 4: Advanced Features (Medium Priority)

### 4.1 Worktree Templates ✅ COMPLETE (v3.8.0)
**Why:** Standardised setups for different project types

- [x] Template definitions in `~/.wt/templates/` (simple key=value format):
  ```bash
  # ~/.wt/templates/laravel.conf
  TEMPLATE_DESC="Laravel with MySQL, Composer, NPM"
  WT_SKIP_DB=false
  WT_SKIP_COMPOSER=false
  WT_SKIP_NPM=false
  WT_SKIP_BUILD=false
  WT_SKIP_MIGRATE=false
  ```
- [x] `wt add myapp feature/x --template=laravel` or `-t laravel`
- [x] `wt templates` - List available templates
- [x] `wt templates <name>` - View template details
- [x] `--dry-run` flag to preview worktree creation (v3.9.0)
- [x] Template name validation (security hardening v3.8.1)
- [ ] Project-level templates in `.wtconfig`

**Included templates:** `laravel.conf`, `node.conf`, `minimal.conf`, `backend.conf`

### 4.2 Dependency Sharing
**Why:** Save disk space and setup time

- [ ] Shared `vendor/` via symlinks to cached version
- [ ] Shared `node_modules/` with pnpm-style content-addressed storage
- [ ] `wt share-deps myapp` to enable
- [ ] Cache invalidation on lockfile changes

### 4.3 Snapshot & Restore
**Why:** Quick state preservation

- [ ] `wt snapshot myapp feature/x` - Save current state
- [ ] `wt restore myapp feature/x --snapshot=<id>` - Restore
- [ ] Snapshots include:
  - Database dump
  - Uncommitted changes (stash)
  - Environment file
- [ ] Automatic snapshots before risky operations

### 4.4 Worktree Archiving
**Why:** Preserve but clean up inactive worktrees

- [ ] `wt archive myapp feature/x` - Remove worktree, keep branch + snapshot
- [ ] `wt unarchive myapp feature/x` - Restore from archive
- [ ] Auto-archive suggestions for stale worktrees
- [ ] Configurable archive location (local/cloud)

---

## Phase 5: Integration & Ecosystem (Medium Priority)

### 5.1 Git Hosting Integration
**Why:** Streamline PR workflows

- [ ] GitHub CLI integration:
  - `wt pr myapp feature/x` - Create PR from worktree
  - `wt checkout-pr myapp 123` - Create worktree from PR
  - Show PR status in `wt ls`
- [ ] GitLab/Bitbucket equivalents
- [ ] PR template auto-population

### 5.2 IDE Deep Integration
**Why:** Seamless editor experience

- [ ] VS Code extension:
  - Worktree picker in command palette
  - Status bar indicator
  - Quick switch between worktrees
- [ ] JetBrains plugin (PHPStorm, WebStorm)
- [ ] Neovim/Vim plugin with Telescope integration

### 5.3 Docker Integration
**Why:** Containerised development environments

- [ ] `wt docker myapp feature/x` - Manage containers per worktree
- [ ] Isolated Docker networks per worktree
- [ ] Container lifecycle tied to worktree
- [ ] Support for Laravel Sail, DDEV, Lando

### 5.4 Hook Marketplace
**Why:** Community-contributed hooks

- [ ] Central hook repository (GitHub)
- [ ] `wt hooks search laravel`
- [ ] `wt hooks install laravel-sail-setup`
- [ ] Hook versioning and updates
- [ ] Security review process for community hooks

---

## Phase 6: Performance & Reliability (Lower Priority)

### 6.1 Parallel Operations ✅ COMPLETE (v4.0.0)
**Why:** Faster multi-worktree operations

- [x] Parallel execution for:
  - `wt build-all <repo>` - npm run build on all worktrees
  - `wt exec-all <repo> <cmd>` - Execute any command on all worktrees
  - `wt pull-all <repo>` - Already parallel (enhanced)
- [x] Configurable concurrency limit: `WT_MAX_PARALLEL` (default: 4)
- [x] `parallel_run` framework for adding parallel operations to any command
- [ ] `wt prune --parallel` - Parallel cleanup

### 6.2 Caching Layer
**Why:** Avoid redundant operations

- [ ] Cache worktree metadata (avoid repeated git commands)
- [ ] Intelligent rebuild detection (skip if no changes)
- [ ] Dependency cache sharing across worktrees
- [ ] Cache invalidation triggers

### 6.3 Resilience Improvements ✅ COMPLETE (v4.0.0)
**Why:** Graceful handling of edge cases

- [x] **`wt repair [repo]`** - New command to fix common issues:
  - Prunes orphaned worktree entries
  - Removes stale git index locks (>5 min old)
  - Checks for missing `.git` files in worktrees
- [x] Automatic lock file cleanup: `check_index_locks <git_dir> [--auto-clean]`
- [x] Transaction pattern: `transaction_start`, `transaction_register`, `transaction_commit`
  - Automatic rollback on failure with trap handlers
- [x] Retry logic: `with_retry <max_attempts> <command>` with exponential backoff
- [x] Disk space checks: `check_disk_space <path> <min_mb>` before operations
- [ ] Better handling of network failures during fetch
- [ ] Recovery mode for corrupted worktrees

---

## Phase 7: Enterprise Features (Lower Priority)

### 7.1 Team Configuration Sharing
**Why:** Consistent setup across teams

- [ ] `.wt/` directory in repository:
  - Team hooks
  - Shared templates
  - Required configuration
- [ ] `wt init` to bootstrap from repo config
- [ ] Override hierarchy: repo → user → global

### 7.2 Audit Logging
**Why:** Compliance and debugging

- [ ] Operation log: `~/.wt/audit.log`
- [ ] Configurable log level and retention
- [ ] Include: timestamps, commands, outcomes, durations
- [ ] Export for analysis

### 7.3 Resource Limits
**Why:** Prevent runaway resource usage

- [ ] Maximum worktrees per repo
- [ ] Disk space warnings/limits
- [ ] Database count limits
- [ ] Automatic cleanup of abandoned worktrees

---

## Phase 8: Documentation & Community (Ongoing)

### 8.1 Documentation Improvements
- [ ] Man page generation from README
- [ ] Searchable documentation site (GitHub Pages)
- [ ] Video tutorials for common workflows
- [ ] Cookbook of real-world scenarios

### 8.2 Community Building
- [ ] GitHub Discussions enabled
- [ ] Contributing guide improvements
- [ ] Issue templates (bug, feature, hook submission)
- [ ] Showcase of community hooks

### 8.3 Internationalisation
- [ ] Extract user-facing strings
- [ ] Translation framework
- [ ] Community translations

---

## Quick Wins (Can Implement Now)

These require minimal effort but add value:

1. **`wt version --check`** - Check for updates against GitHub releases
2. **`wt alias`** - Create short aliases for long branch names
3. **`wt recent`** - List recently used worktrees (last 5)
4. **`wt clean`** - Remove node_modules/vendor from inactive worktrees
5. **Quiet mode** - `wt add --quiet` for scripting
6. ~~**Dry run** - `wt rm --dry-run` to preview actions~~ ✅ **DONE (v3.9.0)** - `wt add --dry-run` previews worktree creation
7. **`wt info`** - Detailed info about a single worktree
8. **Configurable URL patterns** - Support custom URL schemes beyond `*.test`

**Additional v3.9.0 quick wins implemented:**
- `--pretty` flag for colourised JSON output
- "Did you mean?" suggestions for mistyped template names
- Template listing in `wt --help`

---

## Priority Matrix

| Priority | Phase | Effort | Impact | Status |
|----------|-------|--------|--------|--------|
| P0 | 1.1 Testing | High | Critical | ✅ DONE |
| P0 | 2.1 Linux | Medium | High | |
| P1 | 1.2 CI/CD | Medium | High | 🔄 Partial |
| P1 | 1.3 Modularise | High | Medium | ✅ DONE |
| P1 | 3.1 Interactive | Medium | Medium | ✅ DONE |
| P1 | 3.2 Status | Low | Medium | ✅ DONE |
| P1 | 3.4 Progress | Low | Medium | ✅ DONE |
| P1 | Quick Wins | Low | Medium | 🔄 Partial |
| P2 | 4.1 Templates | Medium | Medium | ✅ DONE |
| P2 | 5.1 GitHub | Medium | High | |
| P2 | 6.1 Parallel | Medium | Medium | ✅ DONE |
| P2 | 6.3 Resilience | Medium | Medium | ✅ DONE |
| P3 | 2.2 WSL | Medium | Medium | |
| P3 | 4.2 Dep Sharing | High | Medium | |
| P3 | 5.2 IDE | High | High | |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup. When working on roadmap items:

1. Open an issue to discuss approach
2. Reference roadmap item in PR title
3. Update CHANGELOG.md
4. Add/update tests for changes

---

## Versioning Plan

- **v3.7.0** - Hook-based architecture, framework-agnostic
- **v3.8.0** - Testing framework (187 tests), enhanced status, templates ✅
- **v3.8.1** - Security hardening (template validation, injection prevention) ✅
- **v3.9.0** - Developer experience (dry-run, pretty JSON, suggestions) ✅
- **v4.0.0** - Major release: modular architecture, interactive mode, spinners, parallel ops, resilience ✅ **CURRENT**
- **v4.x** - Linux support + GitHub Actions CI
- **v5.0** - Cross-platform (breaking: config changes for Linux/WSL)
- **v5.x** - Integrations, enterprise features
