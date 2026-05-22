<!--
  Thanks for contributing to pg-sync!

  Before opening this PR, please skim CONTRIBUTING.md if you haven't:
  https://github.com/nixrajput/pg-sync/blob/main/CONTRIBUTING.md

  Keep the description focused: what changed and WHY. The diff shows what.
-->

## Summary

<!-- One or two sentences explaining the change. -->

## Related issue

<!-- Link an issue this PR addresses. Use "Closes #NN" to auto-close on merge. -->

Closes #

## Type of change

<!-- Tick all that apply. -->

- [ ] 🐛 Bug fix (non-breaking change that fixes an issue)
- [ ] ✨ New feature (non-breaking change that adds functionality)
- [ ] 💥 Breaking change (fix or feature that changes existing behavior)
- [ ] 📖 Documentation only
- [ ] 🧪 Tests only
- [ ] 🔧 Build / CI / tooling
- [ ] ♻️ Refactor (no behavior change)

## Motivation

<!--
  Explain *why* this change is needed. What problem does it solve?
  What's the user-visible benefit?
-->

## Testing performed

<!--
  How did you verify this works? Include exact commands.
  At minimum, all PRs must pass `make lint test`.
-->

- [ ] `make lint` passes locally
- [ ] `make test` passes locally
- [ ] `make build` produces a working tarball
- [ ] Manually tested with a real PostgreSQL DB (describe below)
- [ ] Tested on multiple OSes (specify)

<details>
<summary>Test details</summary>

```
# Paste your test commands and output here
```

</details>

## Screenshots / output samples

<!-- For UI/UX changes, paste before/after terminal output. -->

## Documentation updates

- [ ] README updated (if user-visible behavior changed)
- [ ] CHANGELOG.md updated under `[Unreleased]`
- [ ] `pg-sync --help` output updated (if flags changed)
- [ ] Inline comments cover non-obvious decisions

## Breaking change details (if applicable)

<!--
  If this is a breaking change, describe:
  - What breaks?
  - What's the migration path for existing users?
  - Why is the break necessary?
-->

## Reviewer checklist

<!-- For the reviewer; the contributor can leave this section as-is. -->

- [ ] Code follows the [style guide](https://github.com/nixrajput/pg-sync/blob/main/CONTRIBUTING.md#code-style)
- [ ] All log output goes to stderr; only return values go to stdout
- [ ] Strict mode (`set -euo pipefail`) is preserved at script level
- [ ] No secrets, credentials, or PII committed
- [ ] CHANGELOG entry is user-facing language, not commit-message language
