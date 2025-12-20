# Contributing to wt

Thanks for your interest in contributing to wt! This document provides guidelines for contributing.

## Code of Conduct

Be respectful and constructive. We're all here to make a useful tool.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Include your macOS version, Herd version, and `wt --version`
3. Provide steps to reproduce the issue
4. Include the actual vs expected behaviour

### Suggesting Features

1. Check existing issues/discussions first
2. Explain the use case - what problem does it solve?
3. Consider if it fits the tool's scope (Laravel Herd + worktrees)

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly (see below)
5. Submit a PR with a clear description

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/wt-worktree-manager.git
cd wt-worktree-manager

# Create a test symlink (don't overwrite your installed version)
ln -s "$(pwd)/wt" /usr/local/bin/wt-dev

# Test your changes
wt-dev doctor
wt-dev --help
```

## Testing Checklist

Before submitting a PR, please test:

- [ ] `wt --version` shows correct version
- [ ] `wt doctor` passes all checks
- [ ] `wt clone <repo>` works
- [ ] `wt add <repo> <branch>` creates worktree correctly
- [ ] `wt ls <repo>` shows worktrees
- [ ] `wt rm <repo> <branch>` removes worktree
- [ ] Tab completion works
- [ ] Works with and without fzf installed

## Code Style

- Use consistent indentation (2 spaces)
- Use meaningful function and variable names
- Add comments for non-obvious logic
- Follow existing patterns in the codebase
- Use British English in user-facing text (colour, honour, etc.)

## Commit Messages

Use conventional commit format:

```bash
feat: add new command for X
fix: correct database backup path
docs: update installation instructions
refactor: simplify branch detection logic
```

## Architecture Notes

The script is organised into sections:

1. **Configuration** - Defaults and config file loading
2. **Helpers** - Colour output, notifications, utilities
3. **Core functions** - Path resolution, git operations
4. **Commands** - Each `cmd_*` function is a subcommand
5. **Main** - Argument parsing and dispatch

When adding a new command:

1. Create `cmd_yourcommand()` function
2. Add to the `case` statement in `main()`
3. Add to help text in `show_help()`
4. Update the completion script `_wt`
5. Add documentation to README.md

## Questions?

Open an issue or discussion - happy to help!
