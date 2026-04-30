{
  checks,
  hm,
  lib,
  pkgs,
  ...
}:
let
  eval = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        defaultCommand = [ "firefox" ];
        gui = {
          wayland.enable = true;
          scaleFactor = 1.5;
          gtk = {
            enable = true;
            theme = "Graphite-Light";
            iconTheme = "Papirus-Light";
          };
          qt = {
            enable = true;
            style = "fusion";
            packages = [ pkgs.qt6.qtbase ];
          };
          desktopEntry = {
            enable = true;
            execArgs = "%U";
            icon = "firefox";
            categories = [ "Network" ];
            mimeType = [ "x-scheme-handler/https" ];
            terminal = true;
            genericName = "Web Browser";
            comment = "Sandboxed browser";
            startupNotify = true;
          };
        };
        dbus = {
          enable = true;
          log = true;
          portal.openUri = true;
          policies = {
            talk = [ "org.example.Service" ];
            own = [ "org.example.Owner" ];
            see = [ "org.example.Observer" ];
            call."org.example.Calls" = [ "Method@/org/example" ];
            broadcast."org.example.Signals" = [ "Signal@/org/example" ];
          };
        };
        audio.pipewire = {
          enable = true;
          filters = {
            enable = true;
            audioIn = true;
            videoIn = true;
            control = true;
            routing = true;
          };
        };
      };
    };
  };

  guiOffEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        gui.wayland.enable = false;
      };
    };
  };

  rawWaylandEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser.gui = {
        wayland.enable = true;
        wayland.securityContext.enable = false;
      };
    };
  };

  invalidScale = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        gui.wayland.enable = true;
        gui.scaleFactor = 0.0;
      };
    };
  };

  guiEnvOverride = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        gui.wayland.enable = true;
        sandbox.env.FONTCONFIG_FILE = "/tmp/fonts.conf";
      };
    };
  };

  dbusEnvOverride = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        dbus.enable = true;
        sandbox.env.DBUS_SESSION_BUS_ADDRESS = "unix:path=/tmp/bus";
      };
    };
  };

  xdgRuntimeDirPassthrough = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        gui.wayland.enable = true;
        sandbox.passthroughEnv = [ "XDG_RUNTIME_DIR" ];
      };
    };
  };

  allPortalsEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        gui.wayland.enable = true;
        dbus = {
          enable = true;
          portal = {
            fileChooser = true;
            openUri = true;
            screencast = true;
            camera = true;
            notifications = true;
          };
        };
      };
    };
  };

  sshOnlyEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser.ssh.enable = true;
    };
  };

  dbusDisabledEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser.dbus.enable = false;
    };
  };

  pipewireDisabledEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser.audio.pipewire.enable = false;
    };
  };

  portalWithoutDbus = hm {
    cloister = {
      enable = true;
      sandboxes.browser.dbus.portal.openUri = true;
    };
  };

  desktopWithoutCommand = hm {
    cloister = {
      enable = true;
      sandboxes.browser.gui = {
        wayland.enable = true;
        desktopEntry.enable = true;
      };
    };
  };

  anonymizeNativePipewire = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        sandbox.anonymize.enable = true;
        audio.pipewire.enable = true;
      };
    };
  };

  pulseOnlyEval = hm {
    cloister = {
      enable = true;
      sandboxes.listener = {
        sandbox.anonymize.enable = true;
        dbus.enable = true;
        audio.pipewire = {
          enable = true;
          pulseOnly = true;
          filters.enable = true;
        };
      };
    };
  };

  pulseOnlyWithoutFilters = hm {
    cloister = {
      enable = true;
      sandboxes.listener.audio.pipewire = {
        enable = true;
        pulseOnly = true;
        filters.enable = false;
      };
    };
  };

  pulseCompatEval = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio.pipewire.enable = true;
    };
  };

  pulseaudioEval = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio.pulseaudio.enable = true;
    };
  };

  pulseaudioConflict = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio = {
        pulseaudio.enable = true;
        pipewire = {
          enable = true;
          pulseCompat.enable = true;
        };
      };
    };
  };

  pulseOnlyPulseaudioConflict = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio = {
        pulseaudio.enable = true;
        pipewire = {
          enable = true;
          pulseOnly = true;
          filters.enable = true;
        };
      };
    };
  };

  pulseOnlyPulseCompatConflict = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio.pipewire = {
        enable = true;
        pulseOnly = true;
        pulseCompat.enable = true;
        filters.enable = true;
      };
    };
  };

  pulseOnlyAlsaConflict = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio.pipewire = {
        enable = true;
        pulseOnly = true;
        filters.enable = true;
        alsa.enable = true;
      };
    };
  };

  pulseOnlyVideoConflict = hm {
    cloister = {
      enable = true;
      sandboxes.player.audio.pipewire = {
        enable = true;
        pulseOnly = true;
        filters = {
          enable = true;
          videoIn = true;
        };
      };
    };
  };

  invalidDesktopExecArgs = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        defaultCommand = [ "firefox" ];
        gui = {
          wayland.enable = true;
          desktopEntry = {
            enable = true;
            execArgs = "%U; touch /tmp/pwned";
          };
        };
      };
    };
  };

  alsaEval = hm {
    cloister = {
      enable = true;
      sandboxes.mixer.audio.pipewire = {
        enable = true;
        alsa.enable = true;
      };
    };
  };

  pulseOnlyNoDbusEval = hm {
    cloister = {
      enable = true;
      sandboxes.listener = {
        dbus.enable = false;
        audio.pipewire = {
          enable = true;
          pulseOnly = true;
          filters.enable = true;
        };
      };
    };
  };

  invalidDbusName = hm {
    cloister = {
      enable = true;
      sandboxes.browser.dbus = {
        enable = true;
        policies.talk = [ "invalid" ];
      };
    };
  };

  invalidDbusWildcard = hm {
    cloister = {
      enable = true;
      sandboxes.browser.dbus = {
        enable = true;
        policies.talk = [ "org.freedesktop.*.Desktop" ];
      };
    };
  };

  portalEnvOverride = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        dbus = {
          enable = true;
          portal.fileChooser = true;
        };
        sandbox.env.GTK_USE_PORTAL = "0";
      };
    };
  };

  multiPipewireEval = hm {
    cloister = {
      enable = true;
      sandboxes = {
        alpha.audio.pipewire = {
          enable = true;
          filters.enable = true;
        };
        beta.audio.pipewire = {
          enable = true;
          filters.enable = true;
        };
      };
    };
  };

  inherit (eval.config.cloister.sandboxes) browser;
  desktop = eval.config.xdg.desktopEntries."cl-browser";
  sandboxConfig = eval.config.cloister._internal.sandboxConfigs.browser;
  pulseOnlyConfig = pulseOnlyEval.config.cloister._internal.sandboxConfigs.listener;
  pulseOnlyInternal = pulseOnlyEval.config.cloister._internal.sandboxInternals.listener;
  pulseCompatConfig = pulseCompatEval.config.cloister._internal.sandboxConfigs.player;
  pulseCompatInternal = pulseCompatEval.config.cloister._internal.sandboxInternals.player;
  pulseaudioConfig = pulseaudioEval.config.cloister._internal.sandboxConfigs.player;
  alsaConfig = alsaEval.config.cloister._internal.sandboxConfigs.mixer;
  pulseOnlyNoDbusInternal = pulseOnlyNoDbusEval.config.cloister._internal.sandboxInternals.listener;
  alphaConfig = multiPipewireEval.config.cloister._internal.sandboxConfigs.alpha;
  betaConfig = multiPipewireEval.config.cloister._internal.sandboxConfigs.beta;
  browserStaticArgs = builtins.toJSON sandboxConfig.static_bwrap_args;
  browserDynamicBinds = builtins.toJSON sandboxConfig.dynamic_binds;
  rawWaylandStaticArgs = builtins.toJSON rawWaylandConfig.static_bwrap_args;
  pipewireConf = eval.config.xdg.configFile."pipewire/pipewire.conf.d/99-cloister.conf".text;
  wireplumberConf =
    eval.config.xdg.configFile."wireplumber/wireplumber.conf.d/99-cloister-browser.conf".text;
  guiOffConfig = guiOffEval.config.cloister._internal.sandboxConfigs.browser;
  rawWaylandConfig = rawWaylandEval.config.cloister._internal.sandboxConfigs.browser;
  allPortalsConfig = allPortalsEval.config.cloister._internal.sandboxConfigs.browser;
  sshOnlyConfig = sshOnlyEval.config.cloister._internal.sandboxConfigs.browser;
  dbusDisabledConfig = dbusDisabledEval.config.cloister._internal.sandboxConfigs.browser;
  pipewireDisabledConfig = pipewireDisabledEval.config.cloister._internal.sandboxConfigs.browser;

  dbusProxyPath = sandboxConfig.dbus_proxy_path;
  allPortalsProxyPath = allPortalsConfig.dbus_proxy_path;
  dbusProxyScriptPath =
    eval.config.systemd.user.services.cloister-dbus-proxy-browser.Service.ExecStart;
  allPortalsProxyScriptPath =
    allPortalsEval.config.systemd.user.services.cloister-dbus-proxy-browser.Service.ExecStart;
  wireplumberLuaPath =
    let
      lines = lib.splitString "\n" wireplumberConf;
      matched = builtins.filter (
        line:
        builtins.match ".*name = /nix/store/.*-access-cloister-browser\\.lua, type = script/lua" line
        != null
      ) lines;
      line = if matched == [ ] then null else builtins.head matched;
    in
    if line == null then
      throw "failed to locate generated WirePlumber Lua script path"
    else
      builtins.elemAt (lib.splitString ", type = script/lua" (builtins.elemAt (lib.splitString "name = " line) 1)) 0;

  staticAssertions = [
    (checks.expectTrue "openUri adds portal call policy" (
      browser.dbus.policies.call ? "org.freedesktop.portal.Desktop"
    ))
    (checks.expectContains "desktop entry exec uses wrapper" "/bin/cl-browser" desktop.exec)
    (checks.expectContains "desktop entry exec args rendered" "%U" desktop.exec)
    (checks.expectEq "desktop entry icon rendered" "firefox" desktop.icon)
    (checks.expectEq "desktop entry category rendered" [ "Network" ] desktop.categories)
    (checks.expectEq "desktop entry mime type rendered" [ "x-scheme-handler/https" ] desktop.mimeType)
    (checks.expectEq "desktop entry terminal rendered" true desktop.terminal)
    (checks.expectEq "desktop entry generic name rendered" "Web Browser" desktop.genericName)
    (checks.expectEq "desktop entry comment rendered" "Sandboxed browser" desktop.comment)
    (checks.expectEq "desktop entry startup notify rendered" true desktop.startupNotify)
    (checks.expectEq "dbus enable renders" true sandboxConfig.dbus_enable)
    (checks.expectEq "dbus disable renders" false dbusDisabledConfig.dbus_enable)
    (checks.expectContains "dbus proxy wrapper path renders" "cloister-dbus-proxy-browser"
      dbusProxyPath
    )
    (checks.expectContains "gtk theme renders" ''"GTK_THEME","Graphite-Light"'' browserStaticArgs)
    (checks.expectContains "gtk default theme renders" ''"GTK_THEME","Graphite-Light"''
      rawWaylandStaticArgs
    )
    (checks.expectContains "gtk settings gtk3 bind renders"
      ''"dest":"$HOME/.config/gtk-3.0/settings.ini"''
      browserDynamicBinds
    )
    (checks.expectContains "gtk settings gtk4 bind renders"
      ''"dest":"$HOME/.config/gtk-4.0/settings.ini"''
      browserDynamicBinds
    )
    (checks.expectContains "qt style renders" ''"QT_STYLE_OVERRIDE","fusion"'' browserStaticArgs)
    (checks.expectContains "fontconfig file renders" ''"FONTCONFIG_FILE"'' browserStaticArgs)
    (checks.expectContains "xdg data dirs render" ''"XDG_DATA_DIRS"'' browserStaticArgs)
    (checks.expectContains "scale factor renders GDK scale" ''"GDK_SCALE","2"'' browserStaticArgs)
    (checks.expectContains "scale factor renders QT scale" ''"QT_SCALE_FACTOR","1.500000"''
      browserStaticArgs
    )
    (checks.expectNotContains "ssh alone does not force xdg runtime passthrough" ''"XDG_RUNTIME_DIR"'' (
      builtins.toJSON sshOnlyConfig.passthrough_env
    ))
    (checks.expectNotContains "xdg runtime dir is absent without gui/dbus/audio" ''"XDG_RUNTIME_DIR"'' (
      builtins.toJSON guiOffConfig.passthrough_env
    ))
    (checks.expectNotContains "gui dbus audio no longer passthroughs xdg runtime dir"
      ''"XDG_RUNTIME_DIR"''
      (builtins.toJSON sandboxConfig.passthrough_env)
    )
    (checks.expectEq "wayland toggle renders" true sandboxConfig.wayland_enable)
    (checks.expectEq "wayland security context defaults on" true sandboxConfig.wayland_security_context)
    (checks.expectEq "wayland security context can be disabled" false
      rawWaylandConfig.wayland_security_context
    )
    (checks.expectEq "gpu auto-enables with gui" true sandboxConfig.gpu_enable)
    (checks.expectEq "gpu shared memory defaults on" true sandboxConfig.gpu_shm)
    (checks.expectContains "portal flatpak marker bind renders" "/.flatpak-info" browserDynamicBinds)
    (checks.expectContains "portal runtime flatpak info bind renders" "$XDG_RUNTIME_DIR/flatpak-info"
      browserDynamicBinds
    )
    (checks.expectEq "portal flatpak app id renders" "dev.cloister.browser"
      allPortalsConfig.flatpak_app_id
    )
    (checks.expectContains "file chooser doc bind renders" "/run/flatpak/doc" (
      builtins.toJSON allPortalsConfig.dynamic_binds
    ))
    (checks.expectContains "file chooser runtime doc bind renders" "$XDG_RUNTIME_DIR/doc" (
      builtins.toJSON allPortalsConfig.dynamic_binds
    ))
    (checks.expectContains "portal wrapper path renders" "cloister-dbus-proxy-browser"
      allPortalsProxyPath
    )
    (checks.expectContains "GTK_USE_PORTAL is set for file chooser" ''"GTK_USE_PORTAL","1"'' (
      builtins.toJSON allPortalsConfig.static_bwrap_args
    ))
    (checks.expectEq "pipewire socket rendered" "cloister/pipewire/browser"
      sandboxConfig.pipewire_socket_name
    )
    (checks.expectEq "pipewire can be disabled" null pipewireDisabledConfig.pipewire_socket_name)
    (checks.expectContains "pipewire config declares per-sandbox socket" "cloister/pipewire/browser"
      pipewireConf
    )
    (checks.expectContains "wireplumber baseline permissions are restrictive"
      ''default_permissions = "l"''
      wireplumberConf
    )
    (checks.expectContains "wireplumber policy references sandbox access label"
      ''access = "cloister-browser"''
      wireplumberConf
    )
    (checks.expectContains "wireplumber policy installs custom script"
      "custom.access-cloister-browser = required"
      wireplumberConf
    )
    (checks.expectContains "pipewire config preserves unfiltered manager socket"
      ''pipewire-0-manager = "unrestricted"''
      pipewireConf
    )
    (checks.expectEq "pulse-only keeps backend socket distinct" "cloister/pipewire/listener"
      pulseOnlyConfig.pipewire_backend_socket_name
    )
    (checks.expectEq "pulse-only hides native pipewire socket" null
      pulseOnlyConfig.pipewire_socket_name
    )
    (checks.expectContains "pulse-only config blocks recording by default" "block-record-stream"
      pulseOnlyInternal.pipewirePulseOnlyConfText
    )
    (checks.expectContains "pulse-only config blocks volume control by default" "block-sink-volume"
      pulseOnlyInternal.pipewirePulseOnlyConfText
    )
    (checks.expectContains "pulse-only anonymize rewrites identity" ''"context.user-name" = "ubuntu"''
      pulseOnlyInternal.pipewirePulseOnlyConfText
    )
    (checks.expectContains "pulse-only disables dbus support when dbus is off" "support.dbus = false"
      pulseOnlyNoDbusInternal.pipewirePulseOnlyConfText
    )
    (checks.expectContains "pulseCompat wrapper path is rendered"
      "cloister-pipewire-pulse-wrapper-player"
      pulseCompatConfig.pipewire_pulse_wrapper_path
    )
    (checks.expectContains "pulseCompat wrapper starts target in a new session" ''/bin/setsid "$@" &''
      pulseCompatInternal.pipewirePulseWrapperText
    )
    (checks.expectContains "pulseCompat wrapper forwards signals to the child process group"
      ''kill "-$signal" -- "-$child_pid"''
      pulseCompatInternal.pipewirePulseWrapperText
    )
    (checks.expectEq "pulseCompat keeps native pipewire socket" "pipewire-0"
      pulseCompatConfig.pipewire_socket_name
    )
    (checks.expectEq "pulseaudio socket name is rendered" "pulse/native"
      pulseaudioConfig.pulseaudio_socket_name
    )
    (checks.expectContains "alsa sets plugin dir" ''"ALSA_PLUGIN_DIR"'' (
      builtins.toJSON alsaConfig.static_bwrap_args
    ))
    (checks.expectContains "alsa adds compat config dir" "/etc/alsa/conf.d" (
      builtins.toJSON alsaConfig.static_bwrap_args
    ))
    (checks.expectContains "alsa links pipewire compatibility config"
      "/etc/alsa/conf.d/50-pipewire.conf"
      (builtins.toJSON alsaConfig.static_bwrap_args)
    )
    (checks.expectEq "pipewire filter socket names stay per-sandbox" "cloister/pipewire/alpha"
      alphaConfig.pipewire_socket_name
    )
    (checks.expectEq "pipewire filter socket names differ across sandboxes" "cloister/pipewire/beta"
      betaConfig.pipewire_socket_name
    )
    (checks.expectAssertionMessage "portal requires dbus" portalWithoutDbus.assertions
      "dbus.portal.* requires dbus.enable = true"
    )
    (checks.expectAssertionMessage "desktop entry requires default command"
      desktopWithoutCommand.assertions
      "gui.desktopEntry.enable requires defaultCommand to be set"
    )
    (checks.expectAssertionMessage "anonymize rejects native pipewire"
      anonymizeNativePipewire.assertions
      "it is not possible to anonymize a PipeWire socket"
    )
    (checks.expectAssertionMessage "pulseOnly requires filters" pulseOnlyWithoutFilters.assertions
      "audio.pipewire.pulseOnly requires audio.pipewire.filters.enable = true"
    )
    (checks.expectAssertionMessage "desktop entry execArgs rejects metacharacters"
      invalidDesktopExecArgs.assertions
      "gui.desktopEntry.execArgs must not contain shell metacharacters"
    )
    (checks.expectAssertionMessage "pulseCompat rejects pulseaudio passthrough"
      pulseaudioConflict.assertions
      "audio.pipewire.pulseCompat.enable and audio.pulseaudio.enable are mutually exclusive"
    )
    (checks.expectAssertionMessage "pulseOnly rejects pulseaudio passthrough"
      pulseOnlyPulseaudioConflict.assertions
      "audio.pipewire.pulseOnly and audio.pulseaudio.enable are mutually exclusive"
    )
    (checks.expectAssertionMessage "pulseOnly rejects pulseCompat"
      pulseOnlyPulseCompatConflict.assertions
      "audio.pipewire.pulseOnly and audio.pipewire.pulseCompat.enable are mutually exclusive"
    )
    (checks.expectAssertionMessage "pulseOnly rejects alsa" pulseOnlyAlsaConflict.assertions
      "audio.pipewire.pulseOnly cannot be combined with audio.pipewire.alsa.enable"
    )
    (checks.expectAssertionMessage "pulseOnly rejects video input" pulseOnlyVideoConflict.assertions
      "audio.pipewire.pulseOnly is audio-only and does not support audio.pipewire.filters.videoIn"
    )
    (checks.expectAssertionMessage "scale factor validation rejects zero" invalidScale.assertions
      "gui.scaleFactor must be a positive value in 0.25 increments"
    )
    (checks.expectAssertionMessage "gui managed fontconfig cannot be overridden"
      guiEnvOverride.assertions
      "managed by gui"
    )
    (checks.expectAssertionMessage "dbus managed env cannot be overridden" dbusEnvOverride.assertions
      "managed by dbus"
    )
    (checks.expectAssertionMessage "xdg runtime dir passthrough is blocked"
      xdgRuntimeDirPassthrough.assertions
      "sandbox.passthroughEnv cannot include computed/managed keys: XDG_RUNTIME_DIR"
    )
    (checks.expectAssertionMessage "D-Bus names need dotted form" invalidDbusName.assertions
      "D-Bus policy names are invalid"
    )
    (checks.expectAssertionMessage "D-Bus wildcard position stays restricted"
      invalidDbusWildcard.assertions
      "D-Bus policy names are invalid"
    )
    (checks.expectAssertionMessage "portal-managed GTK_USE_PORTAL cannot be overridden"
      portalEnvOverride.assertions
      "managed by dbus.portal"
    )
  ];
in
builtins.deepSeq staticAssertions (
  pkgs.runCommand "test-cloister-gui-dbus-audio" { } ''
    grep -F -- '--log' '${dbusProxyScriptPath}'
    grep -F -- '--talk=org.example.Service' '${dbusProxyScriptPath}'
    grep -F -- '--own=org.example.Owner' '${dbusProxyScriptPath}'
    grep -F -- '--see=org.example.Observer' '${dbusProxyScriptPath}'
    grep -F -- '--call=org.example.Calls=Method@/org/example' '${dbusProxyScriptPath}'
    grep -F -- '--broadcast=org.example.Signals=Signal@/org/example' '${dbusProxyScriptPath}'

    grep -F -- 'CLOISTER_DBUS_PROXY_INSTANCE_ID' '${allPortalsProxyScriptPath}'
    grep -F -- '/.flatpak-info' '${allPortalsProxyScriptPath}'
    grep -F -- 'org.freedesktop.Notifications' '${allPortalsProxyScriptPath}'
    grep -F -- 'org.freedesktop.portal.Camera' '${allPortalsProxyScriptPath}'
    grep -F -- 'org.freedesktop.portal.ScreenCast' '${allPortalsProxyScriptPath}'
    grep -F -- 'org.freedesktop.portal.OpenURI' '${allPortalsProxyScriptPath}'

    grep -F -- 'permissions[node_id] = "rxlw"' '${wireplumberLuaPath}'
    grep -F -- 'permissions[metadata_id] = "rxwm"' '${wireplumberLuaPath}'
    grep -F -- '"Audio/Source"' '${wireplumberLuaPath}'
    grep -F -- '"Video/Source"' '${wireplumberLuaPath}'

    touch "$out"
  ''
)
