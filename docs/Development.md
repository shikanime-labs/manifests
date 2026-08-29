<!-- owner: shikanime | zone: internal | purpose: local setup and render loop -->

# Development

## Prerequisites

- Nix with flakes, `direnv`, and the repo's SOPS age key (for `*.enc.*`
  rendering).
- The `gitlint` commit-msg hook is enforced locally.

## Local loop

1. `direnv allow` (or `nix develop`) to enter the dev shell.
2. Edit manifests under `apps/`, `infrastructure/`, `configs/`, `clusters/`.
3. `nix fmt` (treefmt) before shipping.
4. Render a profile to preview the composed output:

   ```sh
   skaffold render -p <cluster>-tailnet
   ```

## Commit style

Plain-text capitalized title (no conventional-commit prefix) with `Design:`,
`Related:`, `Closes #` body labels. `gitlint` enforces the title locally.

## VCS

Jujutsu (`.jj`) primary. One logical change per PR; large work splits into a
`gh stack` of PRs. Land stacks with `gh stack merge`, never `gh pr merge` on
a stacked PR.
