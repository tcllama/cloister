# Contributing

Thanks for improving Cloister.

## Before you open a pull request

- Confirm the change matches the repository scope: sandboxing, docs, examples, helper tools, or tests.
- Keep changes focused so `make test-changed` can select the smallest relevant validation set.
- Update docs and examples when behavior or defaults change.

## Local development

1. Enter the dev shell with `nix develop`.
1. Make your change.
1. Run the smallest matching validation command:
   - docs and formatting: `make fmt`
   - Nix module changes: `make test-changed`
   - Rust helper changes: `nix develop -c make clippy` and `nix develop -c make rust-test`
1. If the change touches multiple areas, run `nix flake check --print-build-logs` before asking for review.

## Pull request guidelines

- Explain the user-visible reason for the change.
- Link the issue or motivation when possible.
- Include any follow-up work that should stay out of the current PR.
- Add or extend focused tests near the behavior you changed.

## Coding notes

- Prefer targeted tests over broad new suites.
- Do not check in secrets, private credentials, or local machine paths.
- Keep examples importable and runnable as published documentation.

## Questions and support

- Use GitHub issues for bugs, usability problems, and feature requests.
- For security-sensitive problems, follow `SECURITY.md` instead of opening a public issue.
