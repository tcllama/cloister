{
  checks,
  hm,
  pkgs,
  ...
}:
let
  managedXdgSource = pkgs.writeText "managed-config-toml" "[app]\nenabled = true\n";
  managedHmConfigSource = pkgs.writeText "managed-home-manager-ini" "value = 1\n";
  managedHomeSource = pkgs.writeText "managed-home-file" "node_modules\n";

  eval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        sandbox = {
          extraBinds.perDir."/ephemeral" = [ ".cache/nvim" ];
          copyFiles = [
            {
              src = "/host/source/app.conf";
              dest = "/home/tester/.config/app.conf";
              overwrite = true;
            }
          ];
        };
      };
    };
  };

  bindMatrixEval = hm {
    xdg.configFile."app/config.toml".source = managedXdgSource;
    home.file."/home/tester/.config/hm/app.ini".source = managedHmConfigSource;
    home.file.".gitignore".source = managedHomeSource;

    cloister = {
      enable = true;
      sandboxes.dev = {
        shell.hostConfig = false;
        sandbox.extraBinds = {
          required.ro = [ ".bashrc" ];
          optional.ro = [ ".zshrc" ];
          required.rw = [ ".cache/app" ];
          optional.rw = [ ".local/share/app" ];
          managedFile = [
            "app/config.toml"
            "hm/app.ini"
            ".gitignore"
          ];
        };
      };
    };
  };

  persistentStateEval = hm {
    xdg.configFile."app/dir/settings.json".source = managedXdgSource;

    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds = {
        dir."/persist" = [
          ".cache/app"
          ".config/app"
        ];
        file."/persist" = [ ".local/state/app/history" ];
        managedFile = [ "app/dir/settings.json" ];
      };
    };
  };

  perDirManagedFileEval = hm {
    xdg.configFile."opencode/tui.json".source = managedXdgSource;
    xdg.configFile."opencode/opencode.json".source = managedHmConfigSource;

    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds = {
        perDir."/ephemeral" = [ ".config/opencode" ];
        managedFile = [
          "opencode/tui.json"
          "opencode/opencode.json"
        ];
      };
    };
  };

  explicitManagedFileBindEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds = {
        perDir."/ephemeral" = [ ".config/opencode" ];
        managedFileBind = [
          {
            src = managedXdgSource;
            dest = ".config/opencode/tui.json";
          }
          {
            src = managedHmConfigSource;
            dest = ".config/opencode/opencode.json";
          }
        ];
      };
    };
  };

  managedPrefixEval = hm {
    xdg.configFile."app/exact".source = managedXdgSource;
    xdg.configFile."app/prefix/alpha.toml".source = managedXdgSource;
    home.file."/home/tester/.config/hm-only/beta.ini".source = managedHmConfigSource;
    home.file."notes/todo.txt".source = managedHomeSource;

    cloister = {
      enable = true;
      sandboxes.dev = {
        shell.hostConfig = false;
        sandbox.extraBinds.managedFile = [
          "app/exact"
          "app/prefix"
          "hm-only"
          "notes"
        ];
      };
    };
  };

  managedExactWinsEval = hm {
    xdg.configFile."app".source = managedXdgSource;
    xdg.configFile."app/child.toml".source = managedHmConfigSource;

    cloister = {
      enable = true;
      sandboxes.dev = {
        shell.hostConfig = false;
        sandbox.extraBinds.managedFile = [ "app" ];
      };
    };
  };

  multiPerDirEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox = {
        copyFileBase = "/var/lib/cloister-copy";
        extraBinds.perDir = {
          "/var/lib/cloister-per-dir" = [ ".cache/custom" ];
          "/var/lib/cloister-worktrees" = [ ".local/worktrees/project" ];
        };
        copyFiles = [
          {
            src = "/host/source/custom.conf";
            dest = "/home/tester/.config/custom.conf";
          }
        ];
      };
    };
  };

  strictHomePolicyEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox = {
        enforceStrictHomePolicy = false;
        disallowedPaths = [
          "/"
          "/tmp/deny"
        ];
      };
    };
  };

  missingManagedFile = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds.managedFile = [ "missing/path" ];
    };
  };

  invalidPerDir = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox = {
        bindWorkingDirectory = false;
        extraBinds.perDir."/ephemeral" = [ ".cache/nvim" ];
      };
    };
  };

  emptyPerDirBucketEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox = {
        bindWorkingDirectory = false;
        extraBinds.perDir."/ephemeral" = [ ];
      };
    };
  };

  duplicatePerDirDest = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds.perDir = {
        "/ephemeral" = [ ".cache/shared" ];
        "/local/worktrees" = [ ".cache/shared" ];
      };
    };
  };

  invalidCopyMode = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.copyFiles = [
        {
          src = "/host/source/app.conf";
          dest = "/home/tester/.config/app.conf";
          mode = "64x";
        }
      ];
    };
  };

  dirTmpfsOverlapEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox = {
        dirs = [ "/shared" ];
        tmpfs = [ "/shared" ];
      };
    };
  };

  gitEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.git.enable = true;
    };
  };

  duplicateBindDest = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.binds.ro = [
        {
          src = "/host/one";
          dest = "/sandbox/shared";
          try = false;
        }
        {
          src = "/host/two";
          dest = "/sandbox/shared";
          try = false;
        }
      ];
    };
  };

  duplicateSymlink = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.symlinks = [
        {
          target = "/target/one";
          link = "/shared-link";
        }
        {
          target = "/target/two";
          link = "/shared-link";
        }
      ];
    };
  };

  duplicateManagedFile = hm {
    xdg.configFile."app/config.toml".source = managedXdgSource;

    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds.managedFile = [
        "app/config.toml"
        "app/config.toml"
      ];
    };
  };

  duplicateManagedFileBindDest = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds.managedFileBind = [
        {
          src = managedXdgSource;
          dest = ".config/app/config.toml";
        }
        {
          src = managedHmConfigSource;
          dest = ".config/app/config.toml";
        }
      ];
    };
  };

  pathOverride = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.env.PATH = "/tmp/bin";
    };
  };

  unsafePath = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.extraBinds.required.ro = [ "$(pwd)" ];
    };
  };

  blockedPassthrough = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        dbus.enable = true;
        sandbox.passthroughEnv = [
          "PATH"
          "DBUS_SESSION_BUS_ADDRESS"
          "bad-name!"
        ];
      };
    };
  };

  copyOutsideHome = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.copyFiles = [
        {
          src = "/host/source/app.conf";
          dest = "/etc/app.conf";
        }
      ];
    };
  };

  sandboxConfig = eval.config.cloister._internal.sandboxConfigs.dev;
  copySpec = builtins.head sandboxConfig.copy_files;
  bindMatrix = bindMatrixEval.config.cloister._internal.sandboxConfigs.dev.dynamic_binds;
  staticArgsJson = builtins.toJSON bindMatrixEval.config.cloister._internal.sandboxConfigs.dev.static_bwrap_args;
  persistentState = persistentStateEval.config.cloister._internal.sandboxConfigs.dev;
  persistentStateJson = builtins.toJSON persistentState;
  perDirManagedFileState = perDirManagedFileEval.config.cloister._internal.sandboxConfigs.dev;
  perDirManagedFileStateJson = builtins.toJSON perDirManagedFileState;
  explicitManagedFileBindState =
    explicitManagedFileBindEval.config.cloister._internal.sandboxConfigs.dev;
  explicitManagedFileBindStateJson = builtins.toJSON explicitManagedFileBindState;
  managedPrefixConfig = managedPrefixEval.config.cloister._internal.sandboxConfigs.dev;
  managedPrefixStaticArgs = builtins.toJSON managedPrefixConfig.static_bwrap_args;
  managedExactWinsConfig = managedExactWinsEval.config.cloister._internal.sandboxConfigs.dev;
  managedExactWinsStaticArgs = builtins.toJSON managedExactWinsConfig.static_bwrap_args;
  multiPerDirConfig = multiPerDirEval.config.cloister._internal.sandboxConfigs.dev;
  multiPerDirCopySpec = builtins.head multiPerDirConfig.copy_files;
  multiPerDirDynamicBinds = builtins.toJSON multiPerDirConfig.dynamic_binds;
  strictHomePolicyConfig = strictHomePolicyEval.config.cloister._internal.sandboxConfigs.dev;
  emptyPerDirBucketConfig = emptyPerDirBucketEval.config.cloister._internal.sandboxConfigs.dev;
  gitConfig = gitEval.config.cloister._internal.sandboxConfigs.dev;
  emptyPerDirBucketFailures = builtins.filter (a: !a.assertion) emptyPerDirBucketEval.assertions;

  getBind = src: builtins.head (builtins.filter (bind: bind.src == src) bindMatrix);

  requiredRoBind = getBind "$HOME/.bashrc";
  optionalRoBind = getBind "$HOME/.zshrc";
  requiredRwBind = getBind "$HOME/.cache/app";
  optionalRwBind = getBind "$HOME/.local/share/app";
in
checks.mkCheck "test-cloister-sandbox-core" [
  (checks.expectEq "per-dir mapping preserved" {
    "/ephemeral" = [ ".cache/nvim" ];
  } sandboxConfig.per_dir)
  (checks.expectContains "per-dir bind uses DIR_HASH" "$DIR_HASH/.cache/nvim" (
    builtins.toJSON sandboxConfig.dynamic_binds
  ))
  (checks.expectEq "copyFiles host dest rendered"
    "/home/tester/.local/state/cloister/cloister/dev/.config/app.conf"
    copySpec.host_dest
  )
  (checks.expectEq "required read-only bind renders as strict ro" "ro" requiredRoBind.mode)
  (checks.expectFalse "required read-only bind is not optional" requiredRoBind.try_bind)
  (checks.expectEq "optional read-only bind renders as ro" "ro" optionalRoBind.mode)
  (checks.expectTrue "optional read-only bind uses try mode" optionalRoBind.try_bind)
  (checks.expectEq "required read-write bind renders as rw" "rw" requiredRwBind.mode)
  (checks.expectFalse "required read-write bind is not optional" requiredRwBind.try_bind)
  (checks.expectEq "optional read-write bind renders as rw" "rw" optionalRwBind.mode)
  (checks.expectTrue "optional read-write bind uses try mode" optionalRwBind.try_bind)
  (checks.expectContains "managed XDG file resolves to config home"
    ''"/home/tester/.config/app/config.toml"''
    staticArgsJson
  )
  (checks.expectContains "managed Home Manager config file resolves to config home"
    ''"/home/tester/.config/hm/app.ini"''
    staticArgsJson
  )
  (checks.expectContains "managed direct home file resolves to home" ''"/home/tester/.gitignore"''
    staticArgsJson
  )
  (checks.expectContains "managedFile prefix resolves xdg children"
    ''"/home/tester/.config/app/prefix/alpha.toml"''
    managedPrefixStaticArgs
  )
  (checks.expectContains "managedFile prefix resolves home-manager config children"
    ''"/home/tester/.config/hm-only/beta.ini"''
    managedPrefixStaticArgs
  )
  (checks.expectContains "managedFile direct home prefix resolves to home"
    ''"/home/tester/notes/todo.txt"''
    managedPrefixStaticArgs
  )
  (checks.expectContains "managedFile exact key resolves direct config path"
    ''"/home/tester/.config/app"''
    managedExactWinsStaticArgs
  )
  (checks.expectNotContains "managedFile exact key wins over prefix expansion"
    ''"/home/tester/.config/app/child.toml"''
    managedExactWinsStaticArgs
  )
  (checks.expectContains "persistent dir bind renders host path" "/persist/cloister/dev/.cache/app"
    persistentStateJson
  )
  (checks.expectContains "persistent file bind renders host path"
    "/persist/cloister/dev/.local/state/app/history"
    persistentStateJson
  )
  (checks.expectContains "managed file overlap creates host mkdir path"
    "/persist/cloister/dev/.config/app"
    (builtins.toJSON persistentState.managed_file_host_mkdirs)
  )
  (checks.expectContains "per-dir managed file overlap creates hashed host mkdir path"
    "/ephemeral/$DIR_HASH/.config/opencode"
    (builtins.toJSON perDirManagedFileState.managed_file_host_mkdirs)
  )
  (checks.expectContains "per-dir managed file bind is rendered for tui.json"
    ''"/home/tester/.config/opencode/tui.json"''
    perDirManagedFileStateJson
  )
  (checks.expectContains "per-dir managed file bind is rendered for opencode.json"
    ''"/home/tester/.config/opencode/opencode.json"''
    perDirManagedFileStateJson
  )
  (checks.expectContains "explicit managed file bind overlap creates hashed host mkdir path"
    "/ephemeral/$DIR_HASH/.config/opencode"
    (builtins.toJSON explicitManagedFileBindState.managed_file_host_mkdirs)
  )
  (checks.expectContains "explicit managed file bind renders tui.json destination"
    ''"/home/tester/.config/opencode/tui.json"''
    explicitManagedFileBindStateJson
  )
  (checks.expectContains "explicit managed file bind renders store source"
    (builtins.unsafeDiscardStringContext (toString managedXdgSource))
    explicitManagedFileBindStateJson
  )
  (checks.expectEq "multi per-dir mapping is rendered" {
    "/var/lib/cloister-per-dir" = [ ".cache/custom" ];
    "/var/lib/cloister-worktrees" = [ ".local/worktrees/project" ];
  } multiPerDirConfig.per_dir)
  (checks.expectEq "custom copyFileBase is rendered" "/var/lib/cloister-copy"
    multiPerDirConfig.copy_file_base
  )
  (checks.expectContains "first per-dir base feeds dynamic bind source"
    "/var/lib/cloister-per-dir/$DIR_HASH/.cache/custom"
    multiPerDirDynamicBinds
  )
  (checks.expectContains "second per-dir base feeds dynamic bind source"
    "/var/lib/cloister-worktrees/$DIR_HASH/.local/worktrees/project"
    multiPerDirDynamicBinds
  )
  (checks.expectEq "custom copyFileBase feeds copy host destination"
    "/var/lib/cloister-copy/cloister/dev/.config/custom.conf"
    multiPerDirCopySpec.host_dest
  )
  (checks.expectEq "strict home policy toggle is rendered" false
    strictHomePolicyConfig.enforce_strict_home_policy
  )
  (checks.expectEq "custom disallowed paths are rendered" [
    "/"
    "/tmp/deny"
  ] strictHomePolicyConfig.disallowed_paths)
  (checks.expectContains "git enable binds xdg git config" "$HOME/.config/git/config" (
    builtins.toJSON gitConfig.dynamic_binds
  ))
  (checks.expectContains "git enable binds gitconfig" "$HOME/.gitconfig" (
    builtins.toJSON gitConfig.dynamic_binds
  ))
  (checks.expectNotContains "git enable does not bind git config directory" ''"$HOME/.config/git"'' (
    builtins.toJSON gitConfig.dynamic_binds
  ))
  (checks.expectAssertionMessage "per-dir requires bindWorkingDirectory" invalidPerDir.assertions
    "sandbox.bindWorkingDirectory = false is incompatible with sandbox.extraBinds.perDir"
  )
  (checks.expectEq "empty per-dir buckets are dropped from config" { }
    emptyPerDirBucketConfig.per_dir
  )
  (checks.expectEq "empty per-dir buckets do not require bindWorkingDirectory" [ ]
    emptyPerDirBucketFailures
  )
  (checks.expectAssertionMessage "duplicate per-dir destinations are rejected"
    duplicatePerDirDest.assertions
    "duplicate bind mount destinations"
  )
  (checks.expectAssertionMessage "copyFiles mode validation fails" invalidCopyMode.assertions
    "copyFiles contains invalid mode values"
  )
  (checks.expectAssertionMessage "dir and tmpfs overlap is rejected" dirTmpfsOverlapEval.assertions
    "paths appear in both sandbox dirs and tmpfs"
  )
  (checks.expectAssertionMessage "copyFiles destination must stay inside home"
    copyOutsideHome.assertions
    "all copyFiles dest paths must start with $HOME/"
  )
  (checks.expectAssertionMessage "duplicate bind destinations are rejected"
    duplicateBindDest.assertions
    "duplicate bind mount destinations"
  )
  (checks.expectAssertionMessage "duplicate symlinks are rejected" duplicateSymlink.assertions
    "duplicate symlink destinations"
  )
  (checks.expectAssertionMessage "duplicate managed files are rejected"
    duplicateManagedFile.assertions
    "duplicate managed file destinations"
  )
  (checks.expectAssertionMessage "duplicate explicit managed file destinations are rejected"
    duplicateManagedFileBindDest.assertions
    "duplicate managed file destinations"
  )
  (checks.expectAssertionMessage "PATH override is rejected" pathOverride.assertions
    "computed and cannot be overridden"
  )
  (checks.expectAssertionMessage "unsafe path expansion is rejected" unsafePath.assertions
    "cannot contain variable expansions ($) or newlines"
  )
  (checks.expectAssertionMessage "invalid passthrough env names are rejected"
    blockedPassthrough.assertions
    "contains invalid variable names"
  )
  (checks.expectAssertionMessage "managed passthrough env keys are blocked"
    blockedPassthrough.assertions
    "cannot include computed/managed keys"
  )
  (checks.expectFailure "missing managedFile entries fail evaluation" missingManagedFile.config.cloister._internal.sandboxConfigs.dev.static_bwrap_args)
]
