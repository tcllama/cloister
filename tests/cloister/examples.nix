{
  checks,
  hm,
  ...
}:
let
  developer = hm {
    cloister.enable = true;
    imports = [ ../../examples/developer.nix ];
  };

  gui = hm {
    cloister.enable = true;
    imports = [ ../../examples/gui.nix ];
  };

  hardened = hm {
    cloister.enable = true;
    imports = [ ../../examples/hardened.nix ];
  };

  untrusted = hm {
    cloister.enable = true;
    imports = [ ../../examples/untrusted.nix ];
  };

  shellCustomRc = hm {
    imports = [ ../../examples/shell-custom-rc.nix ];
  };

  nixdev = hm {
    cloister.enable = true;
    imports = [ ../../examples/nixdev.nix ];
  };

  imageStore = hm {
    cloister.enable = true;
    xdg.configFile."helix/languages.toml".text = "[[language]]\nname = \"nix\"\n";
    imports = [ ../../examples/image-store.nix ];
  };

  evince = hm {
    cloister.enable = true;
    imports = [ ../../examples/evince.nix ];
  };

  discord = hm {
    cloister.enable = true;
    imports = [ ../../examples/discord.nix ];
  };

  chromium = hm {
    cloister.enable = true;
    imports = [ ../../examples/chromium.nix ];
  };

  shellCustomRcConfig = shellCustomRc.config.cloister._internal.sandboxConfigs.dev;
  shellCustomRcStaticArgs = builtins.toJSON shellCustomRcConfig.static_bwrap_args;
in
checks.mkCheck "test-cloister-examples" [
  (checks.expectEq "developer example sets preset" "developer"
    developer.config.cloister.sandboxes.dev.preset
  )
  (checks.expectEq "gui example sets default command" [
    "evince"
  ] gui.config.cloister.sandboxes.evince.defaultCommand)
  (checks.expectEq "hardened example sets preset" "hardened"
    hardened.config.cloister.sandboxes.hardened.preset
  )
  (checks.expectEq "untrusted example sets hardened preset" "hardened"
    untrusted.config.cloister.sandboxes.untrusted.preset
  )
  (checks.expectContains "shell custom rc example binds dev zshenv" "dev.zshenv"
    shellCustomRcStaticArgs
  )
  (checks.expectContains "shell custom rc example binds dev zshrc" "dev.zshrc"
    shellCustomRcStaticArgs
  )
  (checks.expectEq "shell custom rc example disables host config for work sandbox" false
    shellCustomRc.config.cloister.sandboxes.work.shell.hostConfig
  )
  (checks.expectTrue "nixdev example enables ssh" nixdev.config.cloister.sandboxes.nixdev.ssh.enable)
  (checks.expectEq "image store example switches nix store mode" "image-store"
    imageStore.config.cloister.sandboxes.editor-dev.sandbox.nixStore.mode
  )
  (checks.expectEq "evince example disables network" false
    evince.config.cloister.sandboxes.evince.network.enable
  )
  (checks.expectEq "discord example enables camera portal" true
    discord.config.cloister.sandboxes.discord.dbus.portal.camera
  )
  (checks.expectEq "chromium example wraps chromium" [
    "chromium"
  ] chromium.config.cloister.sandboxes.chromium.registry.commands)
]
