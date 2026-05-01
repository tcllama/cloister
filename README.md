# cloister

A bubblewrap namespace sandbox for shell and GUI applications. Every tool - editors, AI assistants, language toolchains, git - runs inside an isolated namespace with access only to the current directory and explicitly declared state paths. Multiple sandboxes can coexist with different security profiles.

## Why

The sandbox limits what a compromised or misbehaving tool can access. A prompt-injected AI assistant, a compromised GUI app, a supply-chain attack in an npm package, or a malicious build script cannot read your SSH keys, cloud credentials, other projects, or personal files. Each sandbox sees only what you explicitly grant it.

## Who this is for

- Nix and Home Manager users who want tighter boundaries around editors, AI agents, browsers, and GUI apps
- People who want separate trust levels for different tools without maintaining full containers or VMs
- Linux users who are comfortable declaring persistent state, device access, and desktop integration explicitly

## Requirements

- **Linux only** - bubblewrap uses Linux namespaces; macOS is not supported
- **Published support today: `x86_64-linux`** - that is the only flake output currently exposed in `flake.nix`
- **home-manager >= 25.05** - uses `programs.zsh.initContent`
- **Flake-based Home Manager setup** - Cloister is imported as a flake input and module
- **NixOS not required** - works on Linux with Nix + home-manager; the optional netns and image-store host modules are NixOS-only

## Start here

Pick the closest starting point, then refine from there:

- **Trusted development tools** -> `preset = "developer"` -> `examples/developer.nix`
- **Low-trust CLI tools or AI agents** -> `preset = "hardened"` -> `examples/hardened.nix`
- **General desktop apps** -> `preset = "gui"` -> `examples/gui.nix` or `examples/evince.nix`
- **Chromium-family browsers** -> `preset = "chromium"` -> `examples/chromium.nix`

## Quick start

### Optional: enable the Cachix binary cache

Using the public Cachix cache can significantly reduce build time.

If you already have `cachix` installed, run:

```sh
cachix use tcllama
```

Or add the cache manually to your Nix settings:

```nix
nix.settings = {
  substituters = [
    "https://tcllama.cachix.org"
  ];
  trusted-public-keys = [
    "tcllama.cachix.org-1:lwfv8+bXn43j8VdlKIlutiX9vHpBfAc0fCkoAJFdbxU="
  ];
};
```

On non-NixOS systems, you can add the equivalent settings to `~/.config/nix/nix.conf`.

Prerequisites:

- you already manage your user config with a flake-based Home Manager setup
- you are targeting `x86_64-linux`
- you want one initial sandbox named `dev`

Add `cloister` as a flake input and import the home-manager module:

```nix
cloister.url = "github:tcllama/cloister";
```

<details>
<summary>Standalone home-manager flake.nix</summary>

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    cloister.url = "github:tcllama/cloister";
  };

  outputs = { nixpkgs, home-manager, cloister, ... }: {
    homeConfigurations."yourname" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        cloister.homeManagerModules.default
        {
          cloister = {
            enable = true;
            sandboxes.dev.preset = "hardened";
          };
        }
      ];
    };
  };
}
```

</details>

<details>
<summary>NixOS with home-manager module flake.nix</summary>

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    cloister.url = "github:tcllama/cloister";
  };

  outputs = { nixpkgs, home-manager, cloister, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.yourname = {
            imports = [ cloister.homeManagerModules.default ];
            cloister = {
              enable = true;
              sandboxes.dev.preset = "hardened";
            };
          };
        }
      ];
    };
  };
}
```

</details>

After adding the input, run `nix flake lock --update-input cloister` to fetch it, then apply your config:

- Standalone Home Manager: `home-manager switch --flake .#yourname`
- NixOS: `sudo nixos-rebuild switch --flake .#yourhostname`

Then launch your first sandbox:

```sh
cl-dev
```

Expected result:

- Cloister drops you into an interactive shell inside the sandbox
- the current directory is available read-write
- host shell config, network, and other host integrations stay off unless you opt back in
- the generated wrapper is named `cl-dev` because the sandbox is declared as `sandboxes.dev`

### Usage

Minimal first sandbox:

```nix
cloister = {
  enable = true;
  sandboxes.dev.preset = "hardened";
};
```

An empty sandbox declaration (`sandboxes.dev = { };`) keeps host shell config off
by default while leaving `network.enable = true`. Use `preset = "hardened"` for
low-trust tools, AI agents, and unknown scripts.

Each sandbox defined under `cloister.sandboxes.<name>` produces a `cl-<name>` binary.

```sh
cl-dev              # interactive shell (detects git root automatically)
cl-dev cargo build  # run a single command and exit
cl-dev -c cargo build  # -c is accepted but optional
cl-dev -i cargo build  # run via the interactive shell startup path
```

Use `-i` for commands that depend on shell startup behavior inside the sandbox, such as `direnv`, shell functions, or environment setup from `init.text`. Cloister runs the command through the interactive shell startup path and, when `direnv` is available in the sandbox, delegates to `direnv exec "$PWD" ...` before launching the target so one-shot commands inherit the repo env too. When using registry-wrapped commands, put those in `registry.interactiveCommands` so Cloister generates `cl-<name> -i ...` wrappers automatically.

You can use host shell config or provide sandbox-specific rc files (sourced before `init.text` and registry snippets). When `hostConfig = true`, the shell loads host startup files through its normal startup path; Cloister then sources any custom rc files, `init.text`, and registry snippets. Custom rc files are mounted under `~/.config/cl-shell/<name>/custom/`.

```nix
cloister.sandboxes.dev.shell = {
  name = "zsh";
  hostConfig = true; # opt in to host shell startup files
  customRcPath.zshrc = ./configs/zsh/dev.zshrc;
};
```

Example: two sandboxes with different zshrc subsets

See `examples/shell-custom-rc.nix`.

Directory detection rules:

- Inside a **git repo** -> uses the repo root
- In a **non-git directory** -> uses the current directory
- In **`$HOME`** -> error (ambiguous - set `CLOISTER_DIR` or cd into a directory)

Override the sandbox directory with `CLOISTER_DIR`:

```sh
CLOISTER_DIR=/path/to/project cl-dev
```

### Troubleshooting

- If `cl-dev` is missing, rebuild Home Manager/NixOS and confirm `cloister.enable = true` plus `sandboxes.<name>` are set
- If command or alias wrapping is missing in your normal shell, enable the matching Home Manager shell module so the generated init hook runs: `programs.zsh.enable = true` for zsh, `programs.bash.enable = true` for bash
- If GUI, D-Bus, audio, or portals do not work, start with `docs/diagnostics.md`
- If you use `network.namespace`, read `docs/network-namespace.md` first; it requires host-side NixOS setup
- If an example fails to import, check the `examples/` file directly and copy only the parts you need into your own module

## Features

- **Multiple sandboxes** - different security profiles side by side (`cl-dev`, `cl-pdf`, etc.)
- **Command wrapping** - typing `nvim` in your normal shell transparently routes through the sandbox
- **Shell choice** - zsh or bash as the interactive shell
- **Network control** - full network, no network, or routed through a VPN namespace
- **State persistence** - bind mount categories for caches, config, volume-backed storage, and per-directory isolation across multiple host roots
- **Home-manager integration** - bind Nix store-backed config files directly into the sandbox
- **Wayland forwarding** - with `wp-security-context-v1` to filter privileged protocols
- **PipeWire / PulseAudio** - audio with optional per-sandbox device filtering via WirePlumber
- **D-Bus notifications** - per-sandbox filtered proxy with configurable policies
- **SSH agent** - forward `SSH_AUTH_SOCK` into the sandbox (optional fingerprint filtering + timeout)
- **Validator helpers** - available separately via the `cloister-diagnostics` package

## Presets

Sandboxes can opt into opinionated presets with `cloister.sandboxes.<name>.preset`. Presets apply defaults only, so explicit sandbox options still win.

- `hardened` - low-trust CLI sandbox: no network, SSH agent, git config, D-Bus, GUI, or audio
- `developer` - trusted dev sandbox: host shell config, network, git config, SSH agent, and D-Bus notifications enabled
- `gui` - general desktop-app sandbox: Wayland, network, D-Bus notifications enabled; host shell config, git config, and SSH agent disabled
- `chromium` - browser-oriented sandbox: Wayland, network, D-Bus notifications, PipeWire pulse-only mode, PipeWire filters, and Chromium seccomp compatibility enabled

```nix
cloister.sandboxes.dev.preset = "developer";
cloister.sandboxes.browser = {
  preset = "chromium";
  defaultCommand = [ "chromium" ];
};
```

## Network namespace access

If you use `cloister-netns` on NixOS, the helper is group-gated by default. Only users in the `cloister-netns` Unix group can execute the capability wrapper.

```nix
{
  users.users.yourname.extraGroups = [ "cloister-netns" ];
}
```

You can change the authorization group with `cloister-netns.group`. See `docs/network-namespace.md` for the full setup and security model.

## Key options

This is a quick map of the user-facing options most people edit first. For the full reference, defaults, and detailed behavior, use [Configuration & Options Reference](docs/configuration.md).

### Home Manager options

| Option | Default | Purpose |
|--------|---------|---------|
| `cloister.enable` | `false` | Enable the Home Manager integration. |
| `cloister.defaultShell` | `"zsh"` | Choose the default sandbox shell (`"zsh"` or `"bash"`). |
| `cloister.sandboxes.<name>` | `{ }` | Define a sandbox; each name generates a `cl-<name>` wrapper. |
| `cloister-diagnostics` package | not installed | Install validator helpers for Wayland, D-Bus, seccomp, and PipeWire. |

### Per-sandbox options

All options in this table are set under `cloister.sandboxes.<name>`, for example `cloister.sandboxes.dev.preset = "developer";`.

| Option | Default | Purpose |
|--------|---------|---------|
| `audio.pipewire.*` | disabled | Enable filtered PipeWire or PulseAudio-compatible audio access. |
| `dbus.*` | disabled | Enable filtered D-Bus, notifications, portals, logging, and raw policies. |
| `defaultCommand` | `null` | Make `cl-<name>` launch an app or command instead of an interactive shell. |
| `extraPackages` | `[ ]` | Add packages to the sandbox `PATH`. |
| `git.enable` | `false` | Expose host git config where needed. |
| `gui.*` | disabled | Enable Wayland, fonts, themes, extra GUI packages, and desktop entries. |
| `init.text` | `""` | Source custom shell code inside the sandbox at startup. |
| `network.enable` | `true` | Share host networking; set to `false` for no network access. |
| `network.namespace` | `null` | Enter a named network namespace instead of the host network. |
| `preset` | `null` | Start from `hardened`, `developer`, `gui`, or `chromium` defaults. |
| `registry.*` | empty | Create aliases, functions, command wrappers, and interactive wrappers. |
| `sandbox.anonymize.*` | disabled | Present a generic username, home directory, hostname, and process view. |
| `sandbox.bindWorkingDirectory` | `true` | Expose the detected git root or current directory read-write. |
| `sandbox.copies` | `[ ]` | Copy host files into writable sandbox state without mutating the host originals. |
| `sandbox.env` | `{ }` | Set fixed environment variables inside the sandbox. |
| `sandbox.readOnly` / `readWrite` / `managed` / `state.*` | empty | Expose host paths, managed config, and persistent or per-project state explicitly. |
| `sandbox.symlinks` | `[ ]` | Create symlinks inside the sandbox, with relative links resolved under the sandbox home. |
| `sandbox.nixStore.mode` | `"host"` | Use the host `/nix/store` or an immutable `"image-store"` mount. |
| `sandbox.passthroughEnv` | locale vars | Pass selected host environment variables through when set. |
| `sandbox.seccomp.*` | enabled | Tune syscall filtering, including Chromium/Electron compatibility. |
| `shell.customRcPath.*` | `null` | Use sandbox-specific startup files such as `zshrc`, `bashrc`, or `profile`. |
| `shell.hostConfig` | `false` | Bind host shell startup files into the sandbox. |
| `shell.name` | `cloister.defaultShell` | Select the sandbox shell (`"zsh"` or `"bash"`). |
| `ssh.allowFingerprints` | `[ ]` | Restrict SSH agent keys by allowed fingerprints. |
| `ssh.enable` | `false` | Expose host SSH agent access where needed. |
| `workerBroker.profiles` | `{ }` | Generate worker-broker launchers for delegated project workspaces; each profile requires `sandbox` and `workspace.mode`. |

### NixOS host options

These host-level options are exposed by Cloister's optional NixOS modules.

| Option | Default | Purpose |
|--------|---------|---------|
| `cloister.imageStore.base` | `"/var/lib/cloister/images"` | Publish immutable store images and metadata by store hash. |
| `cloister.imageStore.mountBase` | `"/run/cloister/images"` | Mount immutable store images by store hash. |
| `cloister.imageStore.compression.enable` | `true` | Compress generated squashfs images with zstd level 10 and 1 MiB blocks. |
| `cloister.imageStore.enable` | `false` | Enable periodic cleanup of published image-store links. |
| `cloister.imageStore.interval` | `"weekly"` | Set the systemd timer schedule for image-store cleanup. |
| `cloister-netns.networks.<name>` | `{ }` | Define localhost, LAN, isolated, or WireGuard-routed network namespaces. |
| `cloister-netns.veth.addressPool` | `"172.29.0.0/16"` | Allocate veth address pairs for localhost and LAN namespaces. |
| `cloister-netns.group` | `"cloister-netns"` | Choose the Unix group allowed to run the network namespace helper. |

## Documentation

For deep details, use these docs in roughly this order:

- **[Configuration & Options Reference](docs/configuration.md)** - full per-option reference and common configuration patterns
- **[Sandbox Presets](docs/presets.md)** - which preset to start from for each trust level or app type
- **[Diagnostics](docs/diagnostics.md)** - first stop when setup, GUI, D-Bus, or audio forwarding does not behave as expected
- **[Security Model](docs/security.md)** - threat model and isolation boundaries
- **[Identity Anonymization](docs/anonymize.md)** - anonymized mode behavior and limits
- **[Audio](docs/audio.md)** - PipeWire, PulseAudio, filtering, and validation
- **[D-Bus Proxy](docs/dbus.md)** - per-sandbox D-Bus proxy behavior and policy design
- **[Image Store](docs/image-store.md)** - immutable `/nix/store` image mode and host-side publishing
- **[Network Namespaces](docs/network-namespace.md)** - localhost, LAN, isolated, and VPN-routed namespaces

## Examples

See the [examples/](examples/) directory for importable sandbox configurations that are also covered by an eval check:

- **[chromium.nix](examples/chromium.nix)** - Sandboxed browser with GPU, filtered PipeWire audio, notifications, and desktop entry
- **[developer.nix](examples/developer.nix)** - Trusted development sandbox preset with git, SSH, network, and notifications enabled
- **[discord.nix](examples/discord.nix)** - Sandboxed Discord with Wayland, filtered PipeWire (mic + camera), and Flatpak-aligned D-Bus policies
- **[evince.nix](examples/evince.nix)** - Network-isolated PDF viewer with desktop entry and MIME type registration
- **[gui.nix](examples/gui.nix)** - Wayland desktop-app preset with notifications and launcher integration
- **[hardened.nix](examples/hardened.nix)** - Low-trust preset for untrusted CLI tools with host integrations disabled
- **[image-store.nix](examples/image-store.nix)** - Immutable image-backed `/nix/store` for tighter store visibility and shared hashed mounts
- **[nixdev.nix](examples/nixdev.nix)** - Nix configuration development with editor, LSP, formatters, and persistent caches
- **[shell-custom-rc.nix](examples/shell-custom-rc.nix)** - Shell rc subset configuration with per-sandbox zshrc files
- **[untrusted.nix](examples/untrusted.nix)** - Legacy low-trust example now expressed with the `hardened` preset

## Project metadata

- [CONTRIBUTING.md](CONTRIBUTING.md) - local development and validation workflow
- [SECURITY.md](SECURITY.md) - how to report vulnerabilities responsibly
- [LICENSE](LICENSE) - MIT
