.PHONY: fmt lint clippy rust-test test test-eval test-runtime test-changed check clean

TEST_CHECKS ?= \
	test-cloister-bwrap \
	test-cloister-examples \
	test-cloister-registry \
	test-cloister-presets \
	test-cloister-sandbox-core \
	test-cloister-gui-dbus-audio \
	test-cloister-rendered-config \
	test-cloister-image-store \
	test-cloister-netns

TEST_TARGETS = $(addprefix .#checks.x86_64-linux.,$(TEST_CHECKS))
RUNTIME_TEST_CHECKS ?= \
	test-runtime-sandbox-core \
	test-runtime-gui-dbus-audio \
	test-runtime-image-store \
	test-runtime-netns
RUNTIME_TEST_TARGETS = $(addprefix .#checks.x86_64-linux.,$(RUNTIME_TEST_CHECKS))
ALL_TEST_TARGETS = $(TEST_TARGETS) $(RUNTIME_TEST_TARGETS)
RUST_TEST_HELPERS ?= \
	helpers/cloister-dbus-validate \
	helpers/cloister-netns \
	helpers/cloister-pipewire-validate \
	helpers/cloister-sandbox \
	helpers/cloister-wayland-validate \
	helpers/cloister-seccomp-filter \
	helpers/cloister-seccomp-validate
BASE_REF ?= main
TEST_CHANGED_FILES ?=

# Apply treefmt fixes, then verify the treefmt check is clean
fmt:
	nix run .#formatter.x86_64-linux --
	nix build .#checks.x86_64-linux.treefmt --print-build-logs

# Static analysis (statix + deadnix)
lint:
	nix run nixpkgs#statix -- check .
	nix run nixpkgs#deadnix -- --fail .

# Clippy with security-relevant lints
clippy:
	cd helpers/cloister-dbus-validate && cargo clippy -- -D warnings -W clippy::cast_possible_truncation
	cd helpers/cloister-netns && cargo clippy -- -D warnings -W clippy::cast_possible_truncation
	cd helpers/cloister-pipewire-validate && cargo clippy -- -D warnings -W clippy::cast_possible_truncation
	cd helpers/cloister-sandbox && cargo clippy -- -D warnings -W clippy::cast_possible_truncation
	cd helpers/cloister-wayland-validate && cargo clippy -- -D warnings -W clippy::cast_possible_truncation
	cd helpers/cloister-seccomp-filter && cargo clippy -- -D warnings -W clippy::cast_possible_truncation
	cd helpers/cloister-seccomp-validate && cargo clippy -- -D warnings -W clippy::cast_possible_truncation

# Rust helper tests (inside the dev shell for system dependencies)
rust-test:
	nix develop -c sh -eu -c 'for dir in "$$@"; do printf "Running Rust tests in %s\n" "$$dir"; (cd "$$dir" && cargo test); done' sh $(RUST_TEST_HELPERS)

# Full test suite; Nix can build eval and runtime checks concurrently in one invocation
test:
	nix build --print-build-logs $(ALL_TEST_TARGETS)

# Eval tests only
test-eval:
	nix build --print-build-logs $(TEST_TARGETS)

# Runtime VM tests; kept separate from the fast eval-only loop
test-runtime:
	nix build --print-build-logs $(RUNTIME_TEST_TARGETS)

# Run only checks matching changed files; override TEST_CHANGED_FILES for ad hoc selection
test-changed:
	@set -eu; \
	add_check() { \
		case " $$checks " in \
			*" $$1 "*) ;; \
			*) checks="$$checks $$1" ;; \
		esac; \
	}; \
	add_runtime_check() { \
		case " $$runtime_checks " in \
			*" $$1 "*) ;; \
			*) runtime_checks="$$runtime_checks $$1" ;; \
		esac; \
	}; \
	add_helper() { \
		case " $$helpers " in \
			*" $$1 "*) ;; \
			*) helpers="$$helpers $$1" ;; \
		esac; \
	}; \
	add_dbus_checks() { \
		add_check test-cloister-gui-dbus-audio; \
		add_runtime_check test-runtime-gui-dbus-audio; \
	}; \
	if [ -n "$(TEST_CHANGED_FILES)" ]; then \
		changed_files="$(TEST_CHANGED_FILES)"; \
	else \
		if git rev-parse --verify "$(BASE_REF)" >/dev/null 2>&1; then \
			compare_ref="$(BASE_REF)...HEAD"; \
		else \
			compare_ref="HEAD"; \
		fi; \
		changed_files="$$( \
			{ \
				git diff --name-only --diff-filter=ACMR $$compare_ref; \
				git diff --name-only --diff-filter=ACMR; \
				git diff --cached --name-only --diff-filter=ACMR; \
				git ls-files --others --exclude-standard; \
			} | sort -u \
		)"; \
	fi; \
	if [ -z "$$changed_files" ]; then \
		printf 'No changed files detected. Nothing to test.\n'; \
		exit 0; \
	fi; \
	checks=""; \
	runtime_checks=""; \
	helpers=""; \
	for path in $$changed_files; do \
		case "$$path" in \
			Makefile|.github/workflows/*) \
				checks="$(TEST_CHECKS)"; \
				runtime_checks="$(RUNTIME_TEST_CHECKS)"; \
				break \
				;; \
			tests/cloister/gui-dbus-audio.nix|tests/runtime/gui-dbus-audio.nix) \
				add_dbus_checks \
				;; \
			tests/runtime/sandbox-core.nix) \
				add_runtime_check test-runtime-sandbox-core \
				;; \
			tests/runtime/image-store.nix) \
				add_runtime_check test-runtime-image-store \
				;; \
			tests/runtime/netns.nix) \
				add_runtime_check test-runtime-netns \
				;; \
			flake.nix) \
				checks="$(TEST_CHECKS)"; \
				runtime_checks="$(RUNTIME_TEST_CHECKS)"; \
				helpers="$(RUST_TEST_HELPERS)"; \
				break \
				;; \
			tests/default.nix) \
				checks="$(TEST_CHECKS)"; \
				runtime_checks="$(RUNTIME_TEST_CHECKS)"; \
				break \
				;; \
			tests/*) \
				checks="$(TEST_CHECKS)"; \
				break \
				;; \
			modules/cloister/_bwrap.nix|pkgs/bubblewrap-subset-pid/*) \
				add_check test-cloister-bwrap \
				;; \
			examples/*) \
				add_check test-cloister-examples \
				;; \
			modules/cloister/_registry.nix|modules/cloister/_wrappers.nix) \
				add_check test-cloister-registry \
				add_runtime_check test-runtime-sandbox-core \
				;; \
			modules/cloister/_options.nix|modules/cloister/default.nix|modules/cloister/_mkShells.nix|modules/cloister/_shells/*|modules/cloister/_resolve.nix|modules/cloister/_dangerous.nix|modules/cloister/_patterns.nix) \
				add_check test-cloister-registry; \
				add_check test-cloister-presets; \
				add_check test-cloister-sandbox-core; \
				add_dbus_checks; \
				add_runtime_check test-runtime-sandbox-core; \
				add_check test-cloister-rendered-config; \
				add_check test-cloister-image-store; \
				add_runtime_check test-runtime-image-store \
				;; \
			modules/cloister/_assertions.nix) \
				add_check test-cloister-sandbox-core; \
				add_dbus_checks \
				;; \
			modules/cloister/_sandbox.nix) \
				add_check test-cloister-sandbox-core; \
				add_dbus_checks; \
				add_runtime_check test-runtime-sandbox-core; \
				add_check test-cloister-rendered-config; \
				add_check test-cloister-image-store; \
				add_runtime_check test-runtime-image-store \
				;; \
			modules/cloister/package-config.nix) \
				add_check test-cloister-sandbox-core; \
				add_runtime_check test-runtime-sandbox-core; \
				add_check test-cloister-rendered-config; \
				add_dbus_checks; \
				add_check test-cloister-image-store; \
				add_runtime_check test-runtime-image-store \
				;; \
			modules/cloister-image-store/*) \
				add_check test-cloister-image-store; \
				add_runtime_check test-runtime-image-store \
				;; \
			modules/cloister-netns/*) \
				add_check test-cloister-netns; \
				add_runtime_check test-runtime-netns \
				;; \
			helpers/cloister-dbus-validate|helpers/cloister-dbus-validate/*) \
				add_helper helpers/cloister-dbus-validate \
				;; \
			helpers/cloister-netns|helpers/cloister-netns/*) \
				add_helper helpers/cloister-netns \
				;; \
			helpers/cloister-pipewire-validate|helpers/cloister-pipewire-validate/*) \
				add_helper helpers/cloister-pipewire-validate \
				;; \
			helpers/cloister-sandbox|helpers/cloister-sandbox/*) \
				add_helper helpers/cloister-sandbox \
				;; \
			helpers/cloister-wayland-validate|helpers/cloister-wayland-validate/*) \
				add_helper helpers/cloister-wayland-validate \
				;; \
			helpers/cloister-seccomp-filter|helpers/cloister-seccomp-filter/*) \
				add_helper helpers/cloister-seccomp-filter \
				;; \
			helpers/cloister-seccomp-validate|helpers/cloister-seccomp-validate/*) \
				add_helper helpers/cloister-seccomp-validate \
				;; \
			README.md|CLAUDE.md|docs/*) \
				: \
				;; \
			*) \
				checks="$(TEST_CHECKS)"; \
				break \
				;; \
		esac; \
	done; \
	checks="$$(printf '%s\n' $$checks | xargs)"; \
	runtime_checks="$$(printf '%s\n' $$runtime_checks | xargs)"; \
	helpers="$$(printf '%s\n' $$helpers | xargs)"; \
	if [ -z "$$checks" ] && [ -z "$$runtime_checks" ] && [ -z "$$helpers" ]; then \
		printf 'No eval, runtime, or Rust checks mapped for changed files: %s\n' "$$changed_files"; \
		exit 0; \
	fi; \
	if [ -n "$$checks" ]; then \
		printf 'Running eval checks: %s\n' "$$checks"; \
		$(MAKE) test-eval TEST_CHECKS="$$checks"; \
	fi; \
	if [ -n "$$runtime_checks" ]; then \
		printf 'Running runtime checks: %s\n' "$$runtime_checks"; \
		$(MAKE) test-runtime RUNTIME_TEST_CHECKS="$$runtime_checks"; \
	fi; \
	if [ -n "$$helpers" ]; then \
		printf 'Running Rust helper tests: %s\n' "$$helpers"; \
		$(MAKE) rust-test RUST_TEST_HELPERS="$$helpers"; \
	fi

# Common local validation
check: fmt test clippy

# Remove Rust build artifacts
clean:
	cd helpers/cloister-dbus-validate && cargo clean
	cd helpers/cloister-netns && cargo clean
	cd helpers/cloister-pipewire-validate && cargo clean
	cd helpers/cloister-sandbox && cargo clean
	cd helpers/cloister-wayland-validate && cargo clean
	cd helpers/cloister-seccomp-filter && cargo clean
	cd helpers/cloister-seccomp-validate && cargo clean
