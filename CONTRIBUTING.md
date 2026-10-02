# Contributing to manifests

Thanks for contributing. This repo holds Kubernetes manifests and Kustomize
overlays for Shikanime infrastructure. Read this before you act — it covers the
judgment calls that shape how your work is received and what the artefacts you
submit must carry.

## Before you start

- **File an issue first** for anything non-trivial. This repo runs on a settled
  ledger; an unexplained PR gets triaged back to an issue. A one-line issue
  stating what you want to change and why is enough to start.
- **One logical change per PR.** Structural housekeeping and a feature change
  are two PRs. When a change is genuinely large, split it into a stack of PRs
  rather than one wide PR.
- **Send buildable work only.** Anything you submit must build. If you cannot
  confirm a change builds, do not send it.

## Commit shape

A good commit here is self-contained and traceable:

- **Title:** a plain capitalized sentence. No `feat:`/`fix:` prefix.
- **Body:** label the parts a reviewer needs — `Design:` for the approach,
  `Related:` for linked context, `Closes #N` for the issue it resolves.
- **Trailers:** every commit carries both
  `Signed-off-by: Shikanime Deva <william.phetsinorath@shikanime.studio>` and
  `Co-authored-by: Automata <automata@shikanime.studio>`. The `gitlint`
  commit-msg hook rejects messages that omit `Signed-off-by`. Note: on this
  repo the hook auto-injects `Signed-off-by` — if you add it yourself it
  duplicates, so leave that one to the hook.
- **PR body shape:** when you open a PR, the body should carry `## Why` (why
  now), `## What` (one-line summary + scope), and `## References`
  (`Related: <full issue URL>` plus any commits/specs proving the solution).
  The title should equal the commit subject.

## PR

- Open the PR **against `main`** on a feature branch.
- Link the issue you started from: `Closes #N` in the body, or a `Related:`
  link to the discussion when there is no closing issue.
- A code-owner review is required before merge — the `Landing protections`
  ruleset has `require_code_owner_review` on. Self-approval does not satisfy
  it.

## When it isn't clear

If anything here is unclear or doesn't match what you're trying to do, open an
issue and say what you tried. The conventions are living — a concrete example of
where they fell short is the fastest way to improve them.

## Repo tooling

This repo is jj-managed — local version control uses
[Jujutsu](https://jj-vcs.dev/), and GitHub PRs are still opened with the `gh`
CLI. The procedural runbook an agent executes once the human decisions are
settled is in AGENTS.md.

