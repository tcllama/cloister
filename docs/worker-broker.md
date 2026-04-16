# Worker Broker

Worker broker lets a parent Cloister sandbox launch pre-approved child sandboxes for the same project without giving the parent general host container authority.

## What It Is For

Use worker broker when a sandboxed tool needs to delegate work to another Cloister sandbox, such as:

- launching a more restricted worker sandbox from a broader development sandbox
- running nested helper commands against the same project checkout
- exposing only specific delegated per-directory mounts like worktrees or caches

The parent sandbox gets an opaque capability token in env, while authoritative launch policy stays on the host in a trusted session record. The parent launcher may still have host-authored broker profile and delegated mount metadata available from its rendered config.

## Trust Model

- parent sandboxes receive an opaque capability token in env
- parent launchers may also have host-authored broker profile and delegated mount metadata from rendered config
- child launches re-load policy from a trusted mounted session record
- child launches must stay within the same project identity
- delegated mounts come only from host-authored `availableDelegatedPerDirMounts`
- session-record cleanup is attempted on normal parent exit

Crash-leftover session records are not yet pruned automatically.

## Minimal Configuration

```nix
cloister.sandboxes = {
  dev = {
    preset = "dev";
    sandbox.bindWorkingDirectory = true;

    workerBroker = {
      enable = true;

      spawnableProfiles.project = {
        sandbox = "worker";
        workspace.mode = "project-rw";
      };

      spawnableProfiles.overlay = {
        sandbox = "worker";
        workspace.mode = "project-overlay";
        delegatedPerDirMounts.worktrees = "rw";
        delegatedPerDirMounts.".cache/pre-commit" = "ro";
      };

      availableDelegatedPerDirMounts.worktrees = {
        path = "/local/worktrees/dev";
      };

      availableDelegatedPerDirMounts.".cache/pre-commit" = {
        path = "/local/ephemeral/dev";
        subPath = ".cache/pre-commit";
      };
    };
  };

  worker = {
    preset = "hardened";
    shell.hostConfig = false;
  };
};
```

## Choosing A Workspace Mode

### `project-rw`

Use `project-rw` when the child sandbox should write directly to the same project tree the parent is using.

### `project-overlay`

Use `project-overlay` when the child sandbox should see the project tree but keep its file writes isolated in an overlay view.

This is useful for nested automation that should inspect and modify files temporarily without writing back to the host checkout.

## Delegated Per-Directory Mounts

`delegatedPerDirMounts` lets a spawnable profile opt into specific extra paths under the project root.

Example:

- `worktrees = "rw"` can expose a writable worktree area
- `".cache/pre-commit" = "ro"` can expose a shared read-only cache

The profile can only request delegated mounts that were declared in `availableDelegatedPerDirMounts`.

## Manual Test Flow

One simple manual test is:

1. Start in a project checkout managed by the `dev` sandbox.
1. Enter the parent sandbox normally.
1. From inside that sandbox, select a worker-broker profile and launch the configured child sandbox command. For example, set `CLOISTER_BROKER_CHILD_PROFILE=overlay` and then invoke the child launcher for the configured `worker` sandbox. The exact wrapper name depends on how this repo exposes the sandbox command, but the profile-selection env var is required.
1. In the child sandbox, verify that:
   - the child is running in the `worker` sandbox
   - the project root matches the same project
   - delegated mounts appear only where configured
   - `project-rw` writes affect the shared project tree, or `project-overlay` writes stay isolated

The runtime coverage for this flow lives in `tests/runtime/worker-broker.nix`.

## Current Limitations

- session-record cleanup is best-effort on normal parent exit
- crash or hard-kill leftovers are not yet pruned automatically
- worker broker requires `sandbox.bindWorkingDirectory = true`
- child launches are limited to the same project identity and configured profiles
