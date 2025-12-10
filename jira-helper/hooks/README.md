# Git Hooks for jira-helper

Optional git hooks to validate code quality before committing or pushing.

## Available Hooks

### pre-push

Validates tags before pushing to remote. Runs the quick test suite (82 tests) to ensure:
- Bash syntax is valid
- All functions are defined
- Dependencies are available
- Tag format is correct (vX.Y.Z or vX.Y.Z-rcN)

**Installation:**
```bash
ln -sf ../../hooks/pre-push .git/hooks/pre-push
```

**What it does:**
- Checks tag format matches semantic versioning
- Runs `./run-tests.sh --quick` (no API calls, ~30 seconds)
- Blocks the push if tests fail

**When it runs:**
Only when pushing tags (not regular commits).

**To bypass (not recommended):**
```bash
git push --no-verify
```

## GitHub Actions

Tag validation also runs automatically on GitHub via `.github/workflows/tag-validation.yml`. The workflow will:
- Run full shellcheck linting
- Execute the test suite
- Validate tag format
- Report results

If tests fail, the tag is marked as invalid but not automatically deleted (you must delete manually and re-tag).
