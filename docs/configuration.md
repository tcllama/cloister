# Configuration

All per-sandbox configuration lives under `cloister.sandboxes.<name>`. The module provides sensible defaults for a bare functional sandbox, and you layer on your preferences.

## Sandbox basics

### Multiple sandboxes

Define multiple sandboxes with different security profiles:

```nix
cloister = {
  enable = true;
  sandboxes.dev = {
    ssh.enable = true;
    network.enable = true;  # has network (default)
    registry.commands = [ "nvim" "cargo" "claude" ];
  };
  sandboxes.pdf = {
    network.enable = false;  # no network
    gui.wayland.enable = true;
    extraPackages = with pkgs; [ zathura imv ];
    registry.commands = [ "zathura" "imv" ];
  };
};
```

This produces `cl-dev` and `cl-pdf` binaries. Wrapped commands route to the correct sandbox automatically (e.g., `nvim` -> `cl-dev nvim`, `zathura` -> `cl-pdf zathura`).

Cross-sandbox name collisions are detected at build time - two sandboxes cannot wrap the same command name outside.

### Presets

See `docs/presets.md` for the available presets (`hardened`, `developer`, `gui`, `chromium`), examples, and override behavior.

### Adding packages

The sandbox includes a core set of 14 packages: bash, coreutils, curl, findutils, gawk, git, gnugrep, gnused, gnutar, gzip, less, nix, openssh, which, plus the configured shell. Add your tools with `extraPackages`:

```nix
cloister.sandboxes.dev.extraPackages = with pkgs; [
  cargo
  rustc
  nodejs
  neovim
];
```

### Nix store modes

Cloister supports two ways to expose `/nix/store` inside a sandbox.

- `sandbox.nixStore.mode = "host"` bind-mounts the host `/nix/store` directly.
- `sandbox.nixStore.mode = "image-store"` mounts a prebuilt immutable store image at `/nix/store`.

`image-store` shifts store preparation into `nixos-rebuild`: Cloister computes a stable store ID from the store paths the sandbox needs, builds a `squashfs` image for that closure, publishes it under `cloister.imageStore.base`, and mounts it system-wide under `cloister.imageStore.mountBase`.

When using `image-store`:

- the internally managed base packages and configured `extraPackages` are available on `PATH` and their runtime closures are exposed automatically
- some other store paths are included when Cloister references them directly, such as shell binaries, generated config files, or symlink targets

```nix
cloister.sandboxes.editor = {
  extraPackages = with pkgs; [
    helix
    nil
    lua-language-server
  ];

  sandbox = {
    nixStore.mode = "image-store";

    extraBinds.managedFile = [ "helix/languages.toml" ];
  };
};
```

To use `image-store`, also import the NixOS `cloister-image-store` module and set the global storage location if you want something other than the defaults:

```nix
{
  imports = [ inputs.cloister.nixosModules.cloister-image-store ];

  cloister.imageStore = {
    base = "/var/lib/cloister/images";
    mountBase = "/run/cloister/images";
  };
}
```

To clean up stale published image links periodically, set `cloister.imageStore.enable = true;` and optionally adjust `cloister.imageStore.interval` in the NixOS module.

If you want a complete example, see `examples/image-store.nix`.

### Validator helpers

Install the Wayland, D-Bus, seccomp, and PipeWire validators inside the sandbox and wrap them outside:

```nix
cloister.sandboxes.dev.validators.enable = true;
```

### Shell

```nix
cloister.sandboxes.dev.shell.name = "zsh";  # default is cloister.defaultShell ("zsh"); also supports "bash"
```

This controls the interactive shell inside the sandbox and the wrapper integration outside.

To bind host shell config files and/or add sandbox-specific ones:

```nix
cloister.sandboxes.dev.shell = {
  hostConfig = true; # default
  customRcPath = {
    zshenv = ./configs/zsh/dev.zshenv;
    zshrc = ./configs/zsh/dev.zshrc;
  };
};
```

Host config binds include the shell-specific config directories as well as the usual rc files (`~/.config/zsh`, `~/.zshenv`, `~/.zshrc` for zsh; `~/.config/bash`, `~/.bash_profile`, `~/.bashrc` for bash).

Custom rc files are bound into `~/.config/cl-shell/<name>/custom/` and sourced in this order:

1. Host shell startup files (when `hostConfig = true`, via the shell's normal startup path)
1. Custom rc files (when set)
1. `init.text`
1. Registry snippet (always last, so registry wins)

Notes:

- `customRcPath` entries are Nix paths (e.g. `./configs/zsh/dev.zshrc`), so they land in the Nix store and are bind-mounted read-only into the sandbox.
- Set `hostConfig = false` to avoid binding any host shell config files.

Example: two sandboxes, two different zshrc subsets

See `examples/shell-custom-rc.nix` and the companion files under `examples/configs/zsh/`.

> **Note:** Shell config files are bound read-only into the sandbox by default
> for zero-config sandboxes.
> Avoid storing secrets (API tokens, credentials) directly in shell config files,
> as they will be visible inside every sandbox. Use a credential manager or
> environment variable passthrough instead.

### Environment variables

```nix
cloister.sandboxes.dev.sandbox.env = {
  EDITOR = "nvim";
  RUST_BACKTRACE = "1";
};
```

`PATH` is computed from packages and cannot be overridden here. Base variables (`HOME`, `USER`, `SHELL`, `TERM`, `LOCALE_ARCHIVE`, etc.) use `mkDefault` so your values take precedence.

The `CLOISTER` env var is set to the sandbox name inside the sandbox (e.g., `CLOISTER=dev`).

When worker broker is enabled for a sandbox, Cloister also prepends generated `clb-<profile>` launchers to that sandbox's `PATH`, so they are available by plain name inside the parent sandbox.

`LOCALE_ARCHIVE` is set to the `glibcLocales` store path by default, providing glibc locale support inside the sandbox. This prevents "cannot set LC_ALL" warnings and ensures correct date formatting, sorting, and Unicode handling.

To pass through host environment variables when they are set, use `sandbox.passthroughEnv`:

```nix
cloister.sandboxes.dev.sandbox.passthroughEnv = [
  "LANG"
  "LC_ALL"
  "NIX_PATH"
];
```

Locale variables (`LANG` and `LC_*`) are included by default.

### Shell init snippet

Run arbitrary shell code inside the sandbox on session start:

```nix
cloister.sandboxes.dev.init.text = ''
  export GREETING="hello from the sandbox"
'';
```

## Paths and Environment Variables

Cloister strictly disallows bash environment variable expansions (like `$HOME`, `$XDG_RUNTIME_DIR`, or `$USER`) in configuration options related to paths (such as `sandbox.extraBinds.perDir`, `copyFiles`, `binds`, etc.). This is a security measure to prevent shell injection and path evaluation vulnerabilities during wrapper script execution.

Instead of bash variables, you should use **Nix-native path evaluations**. Since this module is configured within `home-manager`, you have full access to your home directory, runtime directories, and config paths through `config`.

**❌ Incorrect (Shell variables, will fail validation):**

```nix
cloister.sandboxes.dev.sandbox = {
  extraBinds.perDir."$HOME/.local/state/cloister" = [ ".cache/nix" ];
  copyFiles = [
    {
      src = "$XDG_CONFIG_HOME/task/taskrc";
      dest = "$HOME/.config/task/taskrc";
      mode = "0644";
    }
  ];
};
```

**✅ Correct (Nix-native pathing):**

```nix
# Ensure you inherit 'config' in your module arguments
{ config, pkgs, ... }:

cloister.sandboxes.dev.sandbox = {
  extraBinds.perDir."${config.home.homeDirectory}/.local/state/cloister" = [ ".cache/nix" ];
  copyFiles = [
    {
      src = "${config.xdg.configHome}/task/taskrc";
      dest = "${config.home.homeDirectory}/.config/task/taskrc";
      mode = "0644";
    }
  ];
};
```

### Common Nix replacements:

- `$HOME` ➔ `config.home.homeDirectory`
- `$XDG_CONFIG_HOME` ➔ `config.xdg.configHome`
- `$XDG_DATA_HOME` ➔ `config.xdg.dataHome`
- `$XDG_STATE_HOME` ➔ `config.xdg.stateHome`
- `$XDG_CACHE_HOME` ➔ `config.xdg.cacheHome`

> **Note:** The `dest` paths for home-relative extra binds (`sandbox.extraBinds.required.rw`, `sandbox.extraBinds.optional.ro`, etc.) are implicitly relative to the sandbox home and do not require `$HOME` prefixes.

## Registry

The registry system defines shell aliases, functions, and wrapped commands that work both inside and outside the sandbox:

```nix
cloister.sandboxes.dev.registry = {
  # Simple argv-style aliases (available inside sandbox, wrapped outside)
  aliases = {
    ll = "ls -la";
    gs = "git status";
  };

  # Shell functions (available inside sandbox, wrapped outside)
  # Use these for pipes, redirects, quoting, conditionals, or builtins.
  functions = {
    mkcd = ''
      mkdir -p "$1" && cd "$1"
    '';
  };

  # Commands to wrap outside the sandbox (typing these
  # in your normal shell routes them through cl-dev)
  commands = [ "nvim" "cargo" "claude" ];

  # Commands that should run through the shell startup path first
  # (useful for direnv, init.text, shell functions, etc.)
  interactiveCommands = [ "lazygit" "opencode" ];

  # Names that should NOT be wrapped outside
  noWrap = [ "git" ];
};
```

When `registry.commands` is set, typing the command in your normal shell transparently runs it through the sandbox. For example, `nvim` becomes `cl-dev nvim`. This means you never need to think about entering the sandbox - your tools just work, but sandboxed.

If a wrapped command depends on shell setup inside the sandbox (for example `direnv` hooks, shell functions, or environment initialization added by `init.text`), put it in `registry.interactiveCommands`. Cloister will then emit wrappers that invoke `cl-<name> -i ...`, which runs the target command through the interactive shell startup path before execution. When `direnv` is installed inside the sandbox, that `-i` path also delegates to `direnv exec "$PWD" ...` before launching the target so one-shot commands inherit the repo environment without requiring a custom wrapper.

Outside-wrapped aliases are intentionally limited to argv-safe strings. If an alias needs shell syntax such as pipes, redirects, variable expansion, quoting, or builtins, put it in `registry.functions` instead.

Outside wrapping is installed through the matching Home Manager shell module. Enable `programs.zsh.enable = true` for zsh-based sandboxes or `programs.bash.enable = true` for bash-based sandboxes so the generated init hook is sourced in your normal shell.

## State persistence

By default, the sandbox is ephemeral - only the working directory survives. To persist tool state (caches, history, databases), declare bind mounts using `sandbox.extraBinds`:

```nix
cloister.sandboxes.dev.sandbox.extraBinds = {
  # Read-write home-relative paths (must exist)
  required.rw = [ ".local/share/atuin" ];

  # Read-write home-relative paths (ok if missing)
  optional.rw = [ ".cargo/registry" ];

  # Read-only home-relative paths (ok if missing)
  optional.ro = [ ".config/starship.toml" ];

  # Volume-backed directories: key is a base directory on the host,
  # values are home-relative paths inside the sandbox.
  # Source: {key}/cloister/{name}/{path} -> dest: $HOME/{path}
  # Directories are created automatically.
  dir."/persist" = [ ".local/share/notes" ];

  # Volume-backed files: same path scheme as dir, but creates
  # individual files instead of directories (touch'd before bwrap).
  file."/persist" = [ ".local/share/myapp/config.db" ];

  # Per-directory state (isolated by a hash of the sandbox directory path)
  # Source: {base}/$HASH/{path} -> dest: $HOME/{path}
  perDir = {
    "/ephemeral" = [ ".local/state/cargo-target" ];
    "/local/worktrees" = [ ".local/worktrees/project" ];
  };
};
```

### Writable config file copies

If you need a writable copy of a host configuration file inside the sandbox (e.g. to modify it without affecting the host), you can use `copyFiles`:

```nix
cloister.sandboxes.dev.sandbox = {
  copyFileBase = "/local/ephemeral"; # optional, defaults to "${config.xdg.stateHome}/cloister"
  copyFiles = [
    {
      src = "${config.home.homeDirectory}/.config/task/home-manager-taskrc";
      dest = "${config.home.homeDirectory}/.config/task/taskrc";
      mode = "0644";
      overwrite = false; # if false, only copies when dest doesn't exist
    }
  ];
};
```

This automatically creates a volume-backed file bind and performs the host-side copy before the sandbox launches.
If `src` is missing or is not a regular file, sandbox startup fails immediately so misconfigured copies are visible.

### Home-manager managed files

If you manage config files through home-manager (`xdg.configFile`, `home.file`), you can bind their Nix store sources directly into the sandbox - read-only and tamper-proof:

```nix
cloister.sandboxes.dev.sandbox.extraBinds.managedFile = [
  "bat"             # prefix - binds bat/config, bat/themes/*, etc.
  "gh"              # prefix - binds gh/config.yml
  "starship.toml"   # exact key
  ".claude"          # prefix outside ~/.config/ - binds .claude/* from home.file
];
```

### Explicit store-backed managed files

If you want to bind files directly from the Nix store without managing them in Home Manager, use `extraBinds.managedFileBind`:

```nix
let
  opencodeAssetsDir = ./assets/opencode;
  opencodeFiles = [
    "tui.json"
    "opencode.json"
  ];
in
{
  cloister.sandboxes.opencode.sandbox.extraBinds = {
    perDir."/ephemeral" = [ ".config/opencode" ];
    managedFileBind = map (relativePath: {
      src = opencodeAssetsDir + "/${relativePath}";
      dest = ".config/opencode/${relativePath}";
    }) opencodeFiles;
  };
}
```

These binds are read-only and overlay correctly on top of `extraBinds.dir` and `extraBinds.perDir` mounts.

### Disabling working directory binding

App-specific sandboxes (like Discord or Chromium) don't need access to the host directory they're launched from. Disable the working directory bind for tighter isolation:

```nix
cloister.sandboxes.discord.sandbox = {
  bindWorkingDirectory = false;
  extraBinds.dir."/persist" = [
    ".config/discord"
    ".cache/discord"
  ];
};
```

When `bindWorkingDirectory` is false, the sandbox skips directory detection entirely and starts in the sandbox home directory. This is incompatible with `extraBinds.perDir` (which requires a working directory hash).

Each `extraBinds.perDir` key gets its own `manifest.json` and its own `${DIR_HASH}` namespace, so you can split ephemeral caches and reboot-persistent project state across different host roots.

## Security & isolation

### Network isolation

```nix
cloister.sandboxes.dev.network.enable = true;   # default - share host network
cloister.sandboxes.pdf.network.enable = false; # no network access
```

When `network.enable` is `true`, the sandbox shares the host network namespace (`--share-net`). When `false`, the sandbox does not share host networking and seccomp also denies new `AF_NETLINK` sockets.

### Network namespace

To route all sandbox network traffic through a specific Linux network namespace (for example, a VPN namespace), set:

```nix
cloister.sandboxes.dev.network.namespace = "vpn";
```

This requires the `cloister-netns` NixOS module on the host system plus at least one allowed namespace name:

```nix
{
  imports = [ cloister.nixosModules.cloister-netns ];
  cloister-netns = {
    enable = true;
    allowedNamespaces = [ "vpn" ];
  };
}
```

For full details (declarative namespace types, WireGuard and LAN examples, file-based secret options, and all `cloister-netns.*` options), see [Network Namespaces](network-namespace.md).
For veth-based namespace types (`localhost`, `lan`), addresses are auto-assigned from host-level pools (`cloister-netns.addressPools.localhost` and `cloister-netns.addressPools.lan`).
For localhost namespaces, `cloister-netns.firewall.autoOpenLocalhostPorts = true` (default) auto-opens host firewall ports on `veth-<name>` and adds matching accepts in cloister-netns localhost nft `input` rules. Setting it to `false` disables both auto-open paths.
If `/etc/netns/<name>/hosts` or `/etc/netns/<name>/resolv.conf` is missing, Cloister falls back to host `/etc/hosts` and `/etc/resolv.conf`.

### Git configuration

```nix
cloister.sandboxes.dev.git.enable = true;   # bind .gitconfig and .config/git/config read-only
cloister.sandboxes.pdf.git.enable = false; # default - no git config inside this sandbox
```

When enabled, `.gitconfig` and `.config/git/config` are bound read-only. This includes credential helper configuration. Disabled by default to avoid exposing credential helper configuration.

### Dangerous path detection

The module checks all bind paths at build time against a list of known credential locations (`.ssh`, `.gnupg`, `.aws`, `.kube`, `.docker/config.json`, keyrings, etc.). If any match, the build fails with a clear error explaining the risk.

> **Note:** This is a best-effort, informational check designed to prevent accidental exposure of common secrets. It is not a strict security boundary, as it relies on static analysis and cannot detect if a user binds a symlink pointing to a sensitive location.

To acknowledge specific paths as intentionally bound:

```nix
cloister.sandboxes.dev.sandbox.allowDangerousPaths = [ ".config/gh/hosts.yml" ];
```

To disable all path checks: `sandbox.dangerousPathWarnings = false`.

## Desktop integration

### Wayland

```nix
cloister.sandboxes.dev.gui.wayland.enable = true;
```

By default, `wp-security-context-v1` is required - the compositor filters which protocol globals are advertised to the sandbox, hiding privileged extensions (screencopy, virtual keyboard injection, etc.). Disable with `gui.wayland.securityContext.enable = false` for raw socket passthrough.

### GPU acceleration

```nix
cloister.sandboxes.dev.gui.gpu.enable = true;  # auto-enabled when Wayland is on
cloister.sandboxes.dev.gui.gpu.shm = true;     # default - private tmpfs at /dev/shm for GPU drivers
```

Binds `/dev/dri` into the sandbox for hardware-accelerated rendering. Auto-enabled when Wayland is active, but can be explicitly disabled with `gui.gpu.enable = false`. A private tmpfs is mounted at `/dev/shm` by default (not the host's `/dev/shm`) since most GPU drivers and multi-process applications (Chromium, Firefox) require POSIX shared memory.

In addition to `/dev/dri`, the sandbox binary automatically detects and binds the following paths when they exist (all as `--ro-bind`, not `--dev-bind`):

- **`/run/opengl-driver`** - NixOS-specific Mesa driver libraries. Without this, GPU apps fail to find `libGL`, `libEGL`, and driver backends.
- **`/sys/dev/char`** - character device node resolution. Allows `libdrm` to map `/dev/dri/cardN` major:minor numbers to their sysfs device nodes.
- **GPU PCI sysfs paths** - auto-detected from `/sys/class/drm/card*` symlinks. These provide vendor/device IDs that Mesa and Vulkan drivers query to identify the GPU hardware.

These binds are detected at runtime by the compiled sandbox binary, so they work across different hardware configurations without per-sandbox configuration.

### HiDPI scaling

```nix
cloister.sandboxes.chromium.gui.scaleFactor = 2.0;
```

When set, `GDK_SCALE`, `GDK_DPI_SCALE`, and `QT_SCALE_FACTOR` are configured inside the sandbox so that GUI applications render at the correct size on HiDPI displays. Set this to the host's display scale (e.g. `2.0` for a 2× HiDPI display). When `null` (default), no scaling variables are set and applications use their own defaults.

### GTK theme

```nix
cloister.sandboxes.dev.gui.gtk = {
  enable = true;    # default - auto-enabled when Wayland is on
  theme = "Adwaita"; # default
};
```

When `gui.gtk.enable` is true, `GTK_THEME` is set inside the sandbox and `gtk3`/`gtk4` are added to the default `gui.dataPackages`, providing built-in Adwaita theme assets. GTK is auto-enabled whenever a GUI display protocol is active, but can be explicitly disabled with `gui.gtk.enable = false` (e.g., for Qt-only apps that don't need GTK).

For alternative themes, add the theme package and set the name:

```nix
cloister.sandboxes.myapp.gui.gtk = {
  theme = "Adwaita:dark";
  packages = with pkgs; [ adw-gtk3 ];  # merged into XDG_DATA_DIRS
};
```

`GTK_THEME` cannot be set directly via `sandbox.env` when GUI is enabled - use `gui.gtk.theme` instead.

### Qt theme

```nix
cloister.sandboxes.dev.gui.qt = {
  enable = true;
  # platformTheme = "gtk3";  # default - reads GTK_THEME, built into qtbase
  # style = null;            # default - no QT_STYLE_OVERRIDE
};
```

When `gui.qt.enable` is true, `QT_QPA_PLATFORMTHEME` is set inside the sandbox. The default `"gtk3"` platform theme is built into qtbase and reads `GTK_THEME`, so Qt apps follow the GTK theme automatically when `gui.gtk` is also enabled.

For apps needing additional Qt plugins (e.g., `qt6ct` for fine-grained control):

```nix
cloister.sandboxes.myapp.gui.qt = {
  enable = true;
  platformTheme = "qt6ct";
  packages = with pkgs; [ qt6ct ];  # adds to QT_PLUGIN_PATH (both qt-5 and qt-6 paths)
};
```

To force a specific Qt style (sets `QT_STYLE_OVERRIDE`):

```nix
cloister.sandboxes.myapp.gui.qt.style = "Fusion";
```

`QT_QPA_PLATFORMTHEME`, `QT_STYLE_OVERRIDE`, and `QT_PLUGIN_PATH` cannot be set directly via `sandbox.env` when Qt is enabled - use the `gui.qt.*` options instead.

### Icon themes and XDG data

```nix
cloister.sandboxes.dev.gui.dataPackages = with pkgs; [ hicolor-icon-theme gtk3 gtk4 gsettings-desktop-schemas ];  # default when GTK is enabled
```

When a GUI display protocol is enabled, `XDG_DATA_DIRS` is computed from `gui.dataPackages` (plus `gui.gtk.packages`) - each package's `/share` directory is included. The defaults provide:

- **`hicolor-icon-theme`** - the freedesktop fallback icon theme required by GTK and Qt (always included when GUI is enabled)
- **`gtk3`** / **`gtk4`** - built-in Adwaita theme assets (only included when `gui.gtk.enable` is true)
- **`gsettings-desktop-schemas`** - GSettings schemas for desktop settings (only included when `gui.gtk.enable` is true)

To add additional icon themes or MIME type databases:

```nix
cloister.sandboxes.evince.gui.dataPackages = with pkgs; [
  hicolor-icon-theme
  gtk3
  gtk4
  gsettings-desktop-schemas
  adwaita-icon-theme
  shared-mime-info
];
```

`XDG_DATA_DIRS` cannot be set directly via `sandbox.env` when GUI is enabled - use `gui.dataPackages` instead.

### Fonts

```nix
cloister.sandboxes.dev.gui.fonts.packages = with pkgs; [ dejavu_fonts ];  # default when GUI is enabled
```

When a GUI display protocol is enabled, a self-contained fontconfig configuration is generated via `pkgs.makeFontsConf` and injected into the sandbox as `FONTCONFIG_FILE`. This replaces the previous host `/etc/fonts` bind mount, making font rendering a declared sandbox property instead of a host-dependent side-effect.

The default provides **`dejavu_fonts`** - a widely-compatible font family covering Latin, Greek, Cyrillic, and more. To add additional fonts:

```nix
cloister.sandboxes.myapp.gui.fonts.packages = with pkgs; [
  dejavu_fonts
  noto-fonts
  noto-fonts-cjk-sans
];
```

Set to an empty list to disable the generated fontconfig entirely (e.g., if the application bundles its own fonts):

```nix
cloister.sandboxes.myapp.gui.fonts.packages = lib.mkForce [ ];
```

`FONTCONFIG_FILE` cannot be set directly via `sandbox.env` when GUI is enabled - use `gui.fonts.packages` instead.

### Desktop entries

```nix
cloister.sandboxes.chromium.gui.desktopEntry = {
  enable = true;
  name = "Chromium (Sandboxed)";
  execArgs = "%U";
  icon = "chromium";
  categories = [ "Network" "WebBrowser" ];
  mimeType = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
};
```

Generates an XDG `.desktop` file so the sandbox appears in your app launcher. Requires a GUI display protocol to be enabled and `defaultCommand` to be set. The `Exec` line launches `cl-<name>` with any `execArgs` appended, so `defaultCommand` is what makes that wrapper behave like an application launcher instead of opening an interactive shell. When `name` is empty, it falls back to `cl-<name>`.

### Device integrations

Use named integration toggles for common device access:

- `video.enable` for `/dev/video*` webcam/camera access
- `fido2.enable` for FIDO2/U2F security keys
- `printing.enable` for CUPS printing

For uncommon devices, including `/dev/kvm`, pass explicit device nodes with `sandbox.devBinds`:

```nix
cloister.sandboxes.dev.sandbox.devBinds = [ "/dev/input/js0" ];
```

Device paths are mounted with `--dev-bind`. Missing devices are warned about at runtime rather than failing startup.

### Examples

See the [examples/](../examples/) directory for complete, importable sandbox configurations.

### PipeWire audio modes

Cloister supports two PipeWire-backed audio modes. Both use a per-sandbox filtered PipeWire backend socket; direct host PulseAudio passthrough, unfiltered PipeWire forwarding, in-sandbox `pipewire-pulse` compatibility, and ALSA compatibility are not supported.

| Option | Protocol exposed inside sandbox | Audio | Screen sharing / cameras | Filtering |
|--------|---------------------------------|-------|--------------------------|-----------|
| `audio.pipewire.enable` | PipeWire native | Yes | Yes | Always (`filters.*`) |
| `audio.pipewire.pulseOnly` | PulseAudio-compatible proxy | Yes | No | Always (`filters.audioOut`, `audioIn`, `control`) |

Use `audio.pipewire.pulseOnly = true` for audio-only sandboxes that need playback, optional microphone access, and volume control without exposing native PipeWire inside the sandbox. Use filtered native `audio.pipewire` when the sandbox also needs cameras, screen sharing, or native PipeWire clients.

### Filtered native PipeWire

```nix
cloister.sandboxes.dev.audio.pipewire = {
  enable = true;
  filters = {
    # filters.enable defaults to true when PipeWire audio is enabled.
    audioOut = true;  # speakers (default)
    # audioIn = true; # microphones
    # videoIn = true; # webcams (also needs video.enable)
  };
};
```

Creates a dedicated restricted PipeWire socket, exposing only the device classes and capabilities you specify while still allowing clients to create the playback/capture streams needed for enabled sinks, microphones, and cameras. See the [audio guide](audio.md) for the full option reference.

### Pulse-only proxy

```nix
cloister.sandboxes.dev.audio.pipewire = {
  enable = true;
  pulseOnly = true;
  filters = {
    audioOut = true;
    audioIn = true;
    control = false;
  };
};
```

This keeps the backend on filtered PipeWire, but exposes only a PulseAudio-compatible proxy socket inside the sandbox. `audioOut`, `audioIn`, and `control` still apply. Native PipeWire tools and camera/screencast flows are intentionally unavailable in this mode.

### Webcam/Camera

```nix
cloister.sandboxes.dev.video.enable = true;
```

Binds `/dev/video*` devices and related sysfs paths for webcam/camera access. At runtime, the sandbox binary scans `/sys/class/video4linux/` to discover all V4L2 video devices and their USB/PCI parent device paths, binding each one into the sandbox. Useful for video calls in sandboxed browsers or video capture applications.

### Printing

```nix
cloister.sandboxes.dev.printing.enable = true;
```

Forwards the CUPS printing socket (`/run/cups/cups.sock`) into the sandbox. Sets `CUPS_SERVER` to the socket path so applications can discover the printer. The socket is bound read-only.

### D-Bus notifications

```nix
cloister.sandboxes.dev.dbus = {
  enable = true;
  portal.notifications = true;
};
```

Allows sandboxed tools to send desktop notifications through a filtered, per-launch D-Bus proxy. See [dbus.md](dbus.md) for policy examples and setup details.

### Worker broker

`workerBroker` config renders the host-side policy the parent launcher needs to register worker sessions and advertise spawnable profiles.

```nix
cloister.sandboxes = {
  dev.workerBroker = {
    enable = true;
    spawnableProfiles.project = {
      sandbox = "worker";
      workspace.mode = "project-rw";
      delegatedPerDirMounts.worktrees = "rw";
    };
    availableDelegatedPerDirMounts.worktrees.path = "/local/worktrees/dev";
  };

  worker = {
    preset = "hardened";
    shell.hostConfig = false;
  };
};
```

This also installs generated launchers in the parent sandbox package named `clb-<profile>`. Run them inside the parent sandbox as `clb-<profile> <command> [args...]`.

Trust model:

- parent sandboxes receive only opaque capability info
- child launches resolve policy from trusted mounted session records / host-side session store
- session record cleanup is attempted on normal parent exit
- env-carried full session JSON is not trusted

The rendered sandbox JSON still includes the worker broker profile and delegated mount metadata because the parent launcher needs that host-authored policy when registering launches. That does not make child-side environment variables authoritative: child launches re-resolve the selected profile from the trusted mounted session record instead of trusting env-carried policy blobs.

For an end-to-end setup and manual testing walkthrough, see [worker-broker.md](worker-broker.md).

Session-record cleanup is currently best-effort on normal parent exit. Records left behind by crashes or hard kills are not yet pruned automatically.

### SSH agent

```nix
cloister.sandboxes.dev.ssh.enable = true;
```

Forwards `SSH_AUTH_SOCK` into the sandbox when set on the host.

To filter which keys are visible, set `ssh.allowFingerprints`. When filtering is enabled,
the proxy uses a read/write timeout (default 60s) that can be tuned for interactive agents:

```nix
cloister.sandboxes.dev.ssh = {
  enable = true;
  allowFingerprints = [ "SHA256:..." ];
  filterTimeoutSeconds = 60; # set 0 to disable timeouts
};
```

> **Security Note:** Forwarding the SSH agent socket allows any process inside the sandbox to use your loaded keys to authenticate or sign commits. To mitigate the risk of a compromised tool misusing your agent, it is highly recommended to use hardware-backed keys that require physical touch (e.g., FIDO2) or add keys to the agent with confirmation required (`ssh-add -c`). Alternatively, you can run a separate, restricted `ssh-agent` specifically for lower-trust sandboxes.

## Default command

For app-specific sandboxes, `defaultCommand` specifies the command to run when the sandbox binary is invoked without arguments. This turns `cl-<name>` from an interactive shell into a direct app launcher:

```nix
cloister.sandboxes.evince = {
  extraPackages = with pkgs; [ evince ];
  defaultCommand = [ "evince" ];
  gui.wayland.enable = true;
};
```

Now `cl-evince` launches evince directly instead of opening a shell. Additional arguments are appended to the default command, so `cl-evince document.pdf` runs `evince document.pdf`. To run a different command explicitly, use `-c`: `cl-evince -c some-other-command`. To run a command through the interactive shell startup path first, use `-i`: `cl-evince -i some-other-command`. When `direnv` is present in the sandbox, that path also uses `direnv exec "$PWD" ...` before the final `exec`, which makes one-shot launches pick up the active repo environment. Bare `-c` and bare `-i` are invalid and exit with a usage error. To pass values like `--version`, `--build-info`, `-c`, or `-i` through to the sandboxed default command instead of the launcher, insert `--` first: `cl-evince -- --version`. Generated wrapped command aliases also pass their leading arguments through to the app now, so sandbox control flags like `--shell` should be used on `cl-<name>` itself. This is especially useful with `gui.desktopEntry`, because the desktop entry launches `cl-<name>` and relies on `defaultCommand` to start the application.

## Identity anonymization

See `docs/anonymize.md` for anonymized identity behavior, proc privacy details, audio constraints, and limitations.

# Options reference

See the sections above for usage examples and explanations.

## Global options

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `cloister.enable` | bool | `false` | Gate the entire module |
| `cloister.defaultShell` | enum | `"zsh"` | Default interactive shell for sandboxes (`"zsh"` or `"bash"`) |

## NixOS host options (`cloister.imageStore.*`)

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `cloister.imageStore.base` | string | `"/var/lib/cloister/images"` | NixOS global publish directory for immutable store images |
| `cloister.imageStore.mountBase` | string | `"/run/cloister/images"` | NixOS global mount directory for immutable store images |
| `cloister.imageStore.compression.enable` | bool | `true` | Compress generated squashfs images with zstd level 10 and 1 MiB blocks |
| `cloister.imageStore.enable` | bool | `false` | Enable periodic cleanup of published image-store links |
| `cloister.imageStore.interval` | string | `"weekly"` | systemd timer schedule for image-store cleanup |

## Per-sandbox options (`cloister.sandboxes.<name>.*`)

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `defaultCommand` | nullOr (listOf str) | `null` | Default command prefix used when invoked without args, or when appending positional args |
| `extraPackages` | list of package | `[]` | Additional packages appended to the internally managed base PATH |
| `preset` | nullOr enum | `null` | Apply one of `hardened`, `developer`, `gui`, or `chromium` default profiles |
| `shell.name` | enum | `cloister.defaultShell` | Interactive shell (`"zsh"` or `"bash"`) |
| `shell.hostConfig` | bool | `true` | Bind host shell config files into the sandbox |
| `shell.customRcPath.zshenv` | nullOr path | `null` | Custom zshenv file to source inside the sandbox |
| `shell.customRcPath.zshrc` | nullOr path | `null` | Custom zshrc file to source inside the sandbox |
| `shell.customRcPath.bashenv` | nullOr path | `null` | Custom bashenv file to source inside the sandbox |
| `shell.customRcPath.bashrc` | nullOr path | `null` | Custom bashrc file to source inside the sandbox |
| `shell.customRcPath.profile` | nullOr path | `null` | Custom profile file to source inside the sandbox |
| `validators.enable` | bool | `false` | Install cloister validator helpers and wrap them outside |
| `workerBroker.enable` | bool | `false` | Enable worker broker support for spawnable sandbox profiles |
| `workerBroker.spawnableProfiles` | attrsOf submodule | `{}` | Spawnable worker broker profiles keyed by profile name |
| `workerBroker.availableDelegatedPerDirMounts` | attrsOf submodule | `{}` | Available delegated per-directory mounts keyed by sandbox-relative path |
| `network.enable` | bool | `true` | Share host network namespace |
| `network.namespace` | nullOr str | `null` | Linux network namespace to join (localhost-netns host services are reachable as `host.internal:<port>`) |
| `sandbox.bindWorkingDirectory` | bool | `true` | Bind-mount the working directory (git root or CWD) into the sandbox. Disable for app-specific sandboxes |
| `sandbox.nixStore.mode` | enum | `"host"` | How Cloister exposes `/nix/store`: bind the host store or a mounted immutable image store |
| `sandbox.env` | attrsOf str | *(base vars)* | Environment variables inside sandbox |
| `sandbox.passthroughEnv` | list of str | *(locale vars)* | Host env vars to pass through when set |
| `sandbox.dirs` | list of str | *(system dirs)* | Directories to create inside the sandbox |
| `sandbox.extraDirs` | list of str | `[]` | Additional directories appended to sandbox dirs |
| `sandbox.tmpfs` | list of str | `["/tmp"]` | Tmpfs mounts inside the sandbox |
| `sandbox.symlinks` | list of {target, link} | *(core shell and compatibility symlinks)* | Symlinks to create inside the sandbox |
| `sandbox.extraSymlinks` | list of {target, link} | `[]` | Additional symlinks appended to sandbox symlinks |
| `sandbox.binds.ro` | list of bind | *(system paths)* | Read-only bind mounts |
| `sandbox.binds.rw` | list of bind | `[]` | Additional read-write bind mounts |
| `sandbox.extraBinds.required.ro` | list of str | `[]` | Home-relative required read-only binds |
| `sandbox.extraBinds.required.rw` | list of str | `[]` | Home-relative required read-write binds |
| `sandbox.extraBinds.optional.ro` | list of str | `[]` | Home-relative optional read-only binds |
| `sandbox.extraBinds.optional.rw` | list of str | `[]` | Home-relative optional read-write binds |
| `sandbox.extraBinds.dir` | attrsOf (list of str) | `{}` | Volume-backed directory binds (auto-created) |
| `sandbox.extraBinds.file` | attrsOf (list of str) | `{}` | Volume-backed file binds (auto-created) |
| `sandbox.extraBinds.perDir` | attrsOf (list of str) | `{}` | Per-directory binds keyed by host base directory |
| `sandbox.extraBinds.managedFile` | list of str | `[]` | Home-manager managed file keys bound read-only |
| `sandbox.extraBinds.managedFileBind` | list of {src, dest} | `[]` | Explicit read-only file binds from Nix store or fixed paths |
| `sandbox.dangerousPathWarnings` | bool | `true` | Fail on binds to known credential locations |
| `sandbox.allowDangerousPaths` | list of str | `[]` | Acknowledged credential paths to allow |
| `sandbox.enforceStrictHomePolicy` | bool | `true` | Prevent sandboxing home dirs and dot-dirs |
| `sandbox.disallowedPaths` | list of str | `["/", "/root"]` | Paths disallowed as sandbox directory |
| `sandbox.copyFileBase` | str | `"${config.xdg.stateHome}/cloister"` | Base directory on the host where copyFiles are stored |
| `sandbox.copyFiles` | list of {src, dest, mode, overwrite} | `[]` | Files to copy writable into the sandbox state; missing sources fail startup |
| `sandbox.anonymize.enable` | bool | `false` | Present generic identity (username/hostname `ubuntu`, synthetic `/proc` files, blocked `/proc/sys`) |
| `sandbox.anonymize.username` | str | `"ubuntu"` | Username and home directory name used by anonymized sandboxes |
| `gui.wayland.enable` | bool | `false` | Forward Wayland display socket |
| `gui.wayland.securityContext.enable` | bool | `true` | Require wp-security-context-v1 for Wayland |
| `gui.gpu.enable` | bool | `false`\* | Bind /dev/dri for GPU acceleration (*auto-enabled with Wayland) |
| `gui.gpu.shm` | bool | `true` | Mount a private tmpfs at /dev/shm when GPU is enabled (does not expose host shared memory) |
| `gui.scaleFactor` | nullOr float | `null` | Display scale factor for HiDPI (sets `GDK_SCALE`, `GDK_DPI_SCALE`, `QT_SCALE_FACTOR`) |
| `gui.dataPackages` | list of package | `[hicolor-icon-theme]`* | Packages whose `/share` dirs form `XDG_DATA_DIRS` (*`gtk3`/`gtk4`/`gsettings-desktop-schemas` added when `gui.gtk.enable`) |
| `gui.fonts.packages` | list of package | `[]`* | Font packages for fontconfig (*`dejavu_fonts` added when Wayland enabled) |
| `gui.gtk.enable` | bool | `false`* | Enable GTK theming (*auto-enabled with Wayland) |
| `gui.gtk.theme` | str | `"Adwaita"` | GTK theme name (sets `GTK_THEME` env var) |
| `gui.gtk.packages` | list of package | `[]` | Additional GTK theme packages merged into `XDG_DATA_DIRS` |
| `gui.qt.enable` | bool | `false` | Enable Qt theming (`QT_QPA_PLATFORMTHEME`, etc.) |
| `gui.qt.platformTheme` | str | `"gtk3"` | Qt platform theme plugin (sets `QT_QPA_PLATFORMTHEME`) |
| `gui.qt.style` | nullOr str | `null` | Qt style override (sets `QT_STYLE_OVERRIDE` when non-null) |
| `gui.qt.packages` | list of package | `[]` | Qt plugin packages (added to `QT_PLUGIN_PATH`) |
| `gui.desktopEntry.enable` | bool | `false` | Generate XDG .desktop file for app launchers |
| `gui.desktopEntry.name` | str | `""` | Display name (falls back to `cl-<name>`) |
| `gui.desktopEntry.execArgs` | str | `""` | Extra arguments appended after the sandbox binary path (e.g. `%U`) |
| `gui.desktopEntry.icon` | str | `""` | Icon name or path |
| `gui.desktopEntry.categories` | list of str | `[]` | XDG categories |
| `gui.desktopEntry.mimeType` | list of str | `[]` | MIME types handled |
| `gui.desktopEntry.terminal` | bool | `false` | Run in terminal |
| `gui.desktopEntry.genericName` | str | `""` | Generic name (e.g. "Web Browser") |
| `gui.desktopEntry.comment` | str | `""` | Tooltip/comment |
| `gui.desktopEntry.startupNotify` | bool | `false` | Startup notification support |
| `sandbox.seccomp.enable` | bool | `true` | Apply seccomp-bpf filter blocking dangerous syscalls |
| `sandbox.seccomp.allowChromiumSandbox` | bool | `false` | Allow Chromium/Electron internal sandbox syscalls (chroot, namespaces) |
| `ssh.enable` | bool | `false` | Forward SSH agent socket |
| `ssh.allowFingerprints` | list of str | `[]` | Restrict visible SSH keys to these fingerprints |
| `ssh.filterTimeoutSeconds` | unsigned int | `60` | SSH filter read/write timeout; set `0` to disable |
| `git.enable` | bool | `false` | Bind `.gitconfig` and `.config/git/config` read-only |
| `dbus.enable` | bool | `false` | Per-launch D-Bus proxy |
| `dbus.log` | bool | `false` | Enable xdg-dbus-proxy logging |
| `dbus.portal.fileChooser` | bool | `false` | Enable portal file chooser via D-Bus; adds `.flatpak-info`, `GTK_USE_PORTAL`, and optional binds for `/run/flatpak/doc` and `$XDG_RUNTIME_DIR/doc` from the per-app document portal subtree when it already exists; this improves file chooser integration but is not a host-path privacy boundary |
| `dbus.portal.openUri` | bool | `false` | Allow the OpenURI portal |
| `dbus.portal.screencast` | bool | `false` | Allow the ScreenCast portal |
| `dbus.portal.camera` | bool | `false` | Allow the Camera portal |
| `dbus.portal.notifications` | bool | `false` | Allow native desktop notifications via `org.freedesktop.Notifications` |
| `dbus.rawPolicies.talk` | list of str | `[]` | Raw D-Bus TALK allowlist |
| `dbus.rawPolicies.own` | list of str | `[]` | Raw D-Bus OWN allowlist |
| `dbus.rawPolicies.see` | list of str | `[]` | Raw D-Bus SEE allowlist |
| `dbus.rawPolicies.call` | attrsOf (list of str) | `{}` | Raw per-name call rules |
| `dbus.rawPolicies.broadcast` | attrsOf (list of str) | `{}` | Raw per-name broadcast rules |
| `audio.pipewire.enable` | bool | `false` | Enable filtered PipeWire-backed audio |
| `audio.pipewire.pulseOnly` | bool | `false` | Expose only a filtered PulseAudio-compatible proxy socket while keeping PipeWire hidden from the sandbox |
| `audio.pipewire.filters.enable` | bool | `false`* | Enable PipeWire filtering (*auto-enabled by `audio.pipewire.enable`) |
| `audio.pipewire.filters.audioOut` | bool | `true` | Allow playback to speakers/sinks when filtering is enabled |
| `audio.pipewire.filters.audioIn` | bool | `false` | Allow microphone access when filtering is enabled |
| `audio.pipewire.filters.videoIn` | bool | `false` | Allow camera nodes when filtering is enabled |
| `audio.pipewire.filters.control` | bool | `false` | Allow volume and mute changes on visible nodes |
| `audio.pipewire.filters.routing` | bool | `false` | Allow default-device and stream-routing changes |
| `audio.pipewire.dbus.enable` | bool | `true` | Let sandboxed PipeWire clients use D-Bus support when a filtered bus is available |
| `video.enable` | bool | `false` | Bind /dev/video* devices for webcam/camera access |
| `printing.enable` | bool | `false` | Forward CUPS printing socket |
| `fido2.enable` | bool | `false` | Bind /dev/hidraw\* devices for FIDO2/U2F security key access |
| `sandbox.devBinds` | list of str | `[]` | Additional device paths for `--dev-bind` passthrough |
| `registry.aliases` | attrsOf str | `{}` | Shell aliases |
| `registry.functions` | attrsOf lines | `{}` | Shell functions |
| `registry.commands` | list of str | `[]` | Commands to wrap outside sandbox |
| `registry.interactiveCommands` | list of str | `[]` | Commands to wrap outside sandbox via `cl-<name> -i ...` |
| `registry.noWrap` | list of str | `[]` | Names to exclude from wrapping |
| `init.text` | lines | `""` | Shell snippet sourced inside the sandbox |
