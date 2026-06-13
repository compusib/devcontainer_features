Generate commit messages in Conventional Commits format.

## Mantra

> Not a single word that can be avoided, but not a single addressed issue skipped.

Conciseness is paramount — shorter is always better — yet completeness is never
sacrificed: every change actually made must be reflected. The two are not in tension;
they are the same discipline applied to wording and to coverage.

## Format

```
<type>(<scope>): <description>

[optional body]
```

You may provide multiple entries. Each entry must follow the same header format:

```
<type>(<scope>): <description>
```

and may be followed by its own optional body.

If an optional body is present, it must be a bullet-point list using `*`.

## Scope

This repo is a collection of devcontainer **features**. Each feature lives in
`src/<name>/` and is marked by `src/<name>/devcontainer-feature.json`. Features are the
conceptual scopes — there are no `apps`/`libs` here. Tests mirror features under
`test/<name>/`.

Derive `<scope>` from changed file paths only (never from config keys, module names, or
diff text).

Scope derivation order:
1. If the path is under `src/<name>/...` (where `src/<name>/devcontainer-feature.json`
   exists), scope is `<name>` — the feature. This applies to nested folders too.
2. If the path is under `test/<name>/...`, scope is `<name>` (the feature under test).
3. If the path is under `test/_global/...`, scope is `test`.
4. Otherwise, scope is a short name based on the root directory, with the leading dot
   dropped (for example `.devcontainer` -> `devcontainer`, `.github/workflows` ->
   `github/workflows`, `.github/...` -> `github`, `.vscode` -> `vscode`).

Rules:
- For feature changes, use only `<name>` (never `src/<name>` or `test/<name>`).
- Never use filenames as scope.
- Never use content tokens as scope (for example `git_ops`, `bash`, `docker`).

Scope examples:
- `src/bashrc/install.sh` -> `bashrc` ✅
- `src/bashrc/install.sh` -> `src` ❌
- `test/git-hooks/test.sh` -> `git-hooks` ✅
- `src/claude/devcontainer-feature.json` -> `claude` ✅
- `.github/workflows/release.yaml` -> `github/workflows` ✅
- `.github/commit-message-guideline.md` -> `github` ✅
- `.devcontainer/devcontainer.json` -> `devcontainer` ✅

Validation checklist:
- Scope is derived from path, not content.
- A feature scope is exactly `<name>` (no `src/`/`test/` prefix).
- A non-feature scope is the root directory's short name, leading dot dropped.
- Header type exactly matches one of the allowed types.

## Multiple scopes

This guideline parses scopes as a comma-separated list, following the
[git_ops](https://github.com/zachdaniel/git_ops) convention. This allows multiple scopes
in one header: `chore(bashrc, starship): bump versions`.

- Prefer a **single scope**. One commit = one logical change to one feature.
- When a change genuinely spans several scopes — typically chores such as a mass rename,
  version bumps across features, or structural refactors with no functionality change —
  list them comma-separated with a space: `chore(bashrc, starship, git-hooks): bump versions`.
- Needing many scopes is a signal the commit may be too broad and worth splitting.

## Fallback: multiple commit blocks

When changes are varied and cannot be cleanly attributed to a single scope (or a small
comma-list), do **not** force everything into one header. Instead emit multiple full
commit blocks — each with its own `<type>(<scope>): <description>` header plus optional
`*` body — exactly as Conventional Commits permits (separate blocks, not just
comma-delimited scopes in one header).

In that case, also **offer separate commits as an alternative** alongside the generated
multi-block message, so the change can be split into distinct commits rather than one
commit carrying several blocks.

## Prefer the shortest faithful structure

When a pattern of change makes a shorter form still cover everything, choose it:
- comma-delimited scopes in a single header (`chore(bashrc, starship): ...`) over several
  full commit blocks;
- a single tight line over a bulleted body.

Escalate to multiple blocks only when no shorter form can capture every addressed issue.

## Types

Allowed types:
- `feat`
- `fix`
- `docs`
- `style`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `revert`
- `tidbit` (excluded from changelog)

Type is strict: only the exact values above are allowed.
Do not use aliases or variants such as `feature`, `bugfix`, `documentation`, `tests`,
`performance`, or `breaking`.
Example: `feature(bashrc): ...` is invalid; use `feat(bashrc): ...`.

For JSDoc additions/changes, use `docs` (not `refactor`).

## Attribution

Attribute humans only. Do not add AI/tool attribution trailers such as
`Co-Authored-By: Claude ...`, `Generated with ...`, or similar machine-authored credits.
Commit authorship reflects the people responsible for the change.

## Body

- If present, the body must use `*` bullet points.
- Explain why the change was needed.
- Include relevant context or technical details.

Multiline descriptions are permitted: per Conventional Commits, a commit may carry a
multiline body separated from the header by a blank line. Each bullet may wrap across
lines, and the body may contain several bullets. Use this room only as the mantra
requires — when an addressed issue would otherwise be skipped, never to add avoidable
words.
