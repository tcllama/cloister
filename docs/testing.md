# Testing

This repo now has a section-oriented Nix test layout designed for local development and GitHub Actions.

- `make test` runs both eval and runtime checks in one `nix build` so Nix can schedule them together.
- `make test-eval` is the fast eval-only subset.
- `make test-runtime` is the VM-backed subset for behaviors eval tests cannot prove.

## Concrete Checklist

- [x] Create shared eval helpers for Home Manager-style and NixOS-style module tests.
- [x] Add section-scoped flake checks so changed code can run a targeted subset.
- [x] Add an examples eval check so published example configs stay importable.
- [x] Add first-pass coverage for `registry`, `presets`, `sandbox-core`, `gui-dbus-audio`, `rendered-config`, `image-store`, and `netns`.
- [x] Expand negative tests from fail-or-pass checks into message-specific assertion coverage where useful.
- [x] Add more fixture coverage for `managedFile`, shell custom rc, image-store edge cases, and additional netns address-allocation cases.
- [x] Add a GitHub Actions matrix job that runs eval checks independently.
- [x] Add a separate runtime/VM test tier for high-value integration behavior.

## Test Commands

- `make test`
- `make test-eval`
- `make test-runtime`
- `make rust-test`
- `make test-changed`
- `make test-changed BASE_REF=origin/main`
- `make test-changed TEST_CHANGED_FILES="modules/cloister/_registry.nix modules/cloister-netns/default.nix"`
- `make test-changed TEST_CHANGED_FILES="helpers/cloister-netns/src/main.rs"`
- `make test-eval TEST_CHECKS="test-cloister-registry test-cloister-netns"`
- `nix build .#checks.x86_64-linux.test-cloister-registry`
- `nix build .#checks.x86_64-linux.test-cloister-bwrap`
- `nix build .#checks.x86_64-linux.test-cloister-examples`
- `nix build .#checks.x86_64-linux.test-cloister-presets`
- `nix build .#checks.x86_64-linux.test-cloister-sandbox-core`
- `nix build .#checks.x86_64-linux.test-cloister-gui-dbus-audio`
- `nix build .#checks.x86_64-linux.test-cloister-rendered-config`
- `nix build .#checks.x86_64-linux.test-cloister-image-store`
- `nix build .#checks.x86_64-linux.test-cloister-netns`
- `nix build .#checks.x86_64-linux.test-runtime-gui-dbus-audio`
- `nix build .#checks.x86_64-linux.test-runtime-image-store`
- `nix build .#checks.x86_64-linux.test-runtime-netns`
- `nix build .#checks.x86_64-linux.tests-runtime`

## Change Mapping

- `modules/cloister/_bwrap.nix`, `pkgs/bubblewrap-subset-pid/*` -> `test-cloister-bwrap`
- `examples/*` -> `test-cloister-examples`
- `modules/cloister/_registry.nix`, `modules/cloister/_wrappers.nix` -> `test-cloister-registry`
- `modules/cloister/_options.nix`, `modules/cloister/default.nix`, `modules/cloister/_mkShells.nix`, `modules/cloister/_shells/*`, `modules/cloister/_resolve.nix`, `modules/cloister/_dangerous.nix`, `modules/cloister/_patterns.nix` -> `test-cloister-registry`, `test-cloister-presets`, `test-cloister-sandbox-core`, `test-cloister-gui-dbus-audio`, `test-runtime-gui-dbus-audio`, `test-cloister-rendered-config`, `test-cloister-image-store`, `test-runtime-image-store`
- `modules/cloister/_sandbox.nix`, `modules/cloister/_assertions.nix` -> `test-cloister-sandbox-core`, `test-cloister-gui-dbus-audio`, `test-runtime-gui-dbus-audio`, `test-cloister-rendered-config`, `test-cloister-image-store`, `test-runtime-image-store`
- GUI, portal, and D-Bus-related changes -> `test-cloister-gui-dbus-audio`, `test-runtime-gui-dbus-audio`
- `modules/cloister/package-config.nix` -> `test-cloister-sandbox-core`, `test-cloister-rendered-config`, `test-cloister-gui-dbus-audio`, `test-runtime-gui-dbus-audio`, `test-cloister-image-store`, `test-runtime-image-store`
- `modules/cloister-image-store/default.nix` -> `test-cloister-image-store`
- `modules/cloister-netns/default.nix` -> `test-cloister-netns`
- `tests/cloister/gui-dbus-audio.nix`, `tests/runtime/gui-dbus-audio.nix` -> `test-cloister-gui-dbus-audio`, `test-runtime-gui-dbus-audio`
- `tests/runtime/image-store.nix` -> `test-runtime-image-store`
- `tests/runtime/netns.nix` -> `test-runtime-netns`
- `helpers/cloister-*` -> `make rust-test` for the changed helper crates

## Concurrency

- `make test` calls a single `nix build` with all eval and runtime checks, so Nix can schedule the full test suite concurrently instead of stepping through `nix flake check` serially.
- `make test-eval` keeps the eval-only subset available for fast module iteration.
- `make test-runtime` keeps the VM-backed runtime checks available as a focused subset.
- `make rust-test` runs `cargo test` for each Rust helper inside `nix develop`, so crates with system-library dependencies still work locally.
- `make test-changed` maps changed files to eval checks, runtime checks, and changed Rust helpers, then runs only the needed subsets.
- `make test-changed` uses `BASE_REF` for the committed diff and also includes staged, unstaged, and untracked files.
- Override `TEST_CHANGED_FILES` when you want to drive the mapping manually without relying on git diff state.
- Override `TEST_CHECKS` to run just an eval subset while keeping the same concurrent `nix build` flow.
- Override `RUNTIME_TEST_CHECKS` to run just a runtime subset.
- GitHub Actions runs the targeted eval and runtime checks directly so failures stay isolated by test tier, and helper tests run through `make rust-test`.
