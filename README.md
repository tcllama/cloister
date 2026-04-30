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

An empty sandbox declaration (`sandboxes.dev = { };`) is convenience-first: it keeps
`shell.hostConfig = true` and `network.enable = true`. Use `preset = "hardened"`
for low-trust tools, AI agents, and unknown scripts.

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
  hostConfig = true; # default
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
- **Dangerous path detection** - build-time checks prevent accidentally binding credential locations
- **Validator helpers** - install Wayland/D-Bus/seccomp validators and wrap them outside the sandbox

## Presets

Sandboxes can opt into opinionated presets with `cloister.sandboxes.<name>.preset`. Presets apply defaults only, so explicit sandbox options still win.

- `hardened` - low-trust CLI sandbox: no network, SSH agent, git config, D-Bus, GUI, or audio; enables validators
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

All per-sandbox options live under `cloister.sandboxes.<name>.*`. For the full reference, defaults, and detailed behavior, use [Configuration & Options Reference](docs/configuration.md).

The options most users reach for first are:

- `preset` - start from `hardened`, `developer`, `gui`, or `chromium`
- `defaultCommand` - make `cl-<name>` launch an app instead of an interactive shell
- `extraPackages` - add tools to the sandbox PATH
- `sandbox.extraBinds.*` - persist config, caches, and per-project state explicitly
- `network.enable` or `network.namespace` - disable network or route through a named namespace
- `gui.wayland.enable`, `dbus.enable`, `audio.pipewire.*` - opt into desktop integration
- `ssh.enable` and `git.enable` - expose host SSH agent or git config only where needed
- `validators.enable` - install validator helpers for Wayland, D-Bus, seccomp, and PipeWire

### NixOS host options

These are the host-level NixOS settings exposed by Cloister itself:

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `cloister.imageStore.base` | str | `"/var/lib/cloister/images"` | Publish immutable store images and metadata by store hash |
| `cloister.imageStore.mountBase` | str | `"/run/cloister/images"` | Mount immutable store images by store hash |
| `cloister.imageStore.enable` | bool | `false` | Enable periodic cleanup of published image-store links |
| `cloister.imageStore.interval` | str | `"weekly"` | systemd timer schedule for image-store cleanup |

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
