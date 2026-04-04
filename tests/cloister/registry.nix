{
  checks,
  hm,
  lib,
  pkgs,
  ...
}:
let
  zshEnvFile = pkgs.writeText "cloister-test-zshenv" ''
    export FROM_ZSHENV=1
  '';

  zshRcFile = pkgs.writeText "cloister-test-zshrc" ''
    export FROM_ZSHRC=1
  '';

  bashEnvFile = pkgs.writeText "cloister-test-bashenv" ''
    export FROM_BASHENV=1
  '';

  bashRcFile = pkgs.writeText "cloister-test-bashrc" ''
    export FROM_BASHRC=1
  '';

  profileFile = pkgs.writeText "cloister-test-profile" ''
    export FROM_PROFILE=1
  '';

  eval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        defaultCommand = [ "nvim" ];
        registry = {
          commands = [
            "nvim"
            "git"
          ];
          aliases.ll = "ls -l";
          functions.greet = ''
            printf '%s\\n' "hello"
          '';
          noWrap = [ "ll" ];
        };
      };
    };
  };

  multiArgDefaultEval = hm {
    cloister = {
      enable = true;
      sandboxes.browser = {
        defaultCommand = [
          "chromium"
          "--ozone-platform=wayland"
        ];
        registry.commands = [ "chromium" ];
      };
    };
  };

  multiShellEval = hm {
    cloister = {
      enable = true;
      sandboxes = {
        one = {
          shell.name = "zsh";
          registry.commands = [ "git" ];
        };
        two = {
          shell.name = "bash";
          registry.functions.hello = "printf hi\\n";
        };
      };
    };
  };

  aliasFunctionOverlap = hm {
    cloister = {
      enable = true;
      sandboxes.dev.registry = {
        aliases.same = "ls";
        functions.same = "printf hi\\n";
      };
    };
  };

  aliasCommandOverlap = hm {
    cloister = {
      enable = true;
      sandboxes.dev.registry = {
        aliases.git = "git status";
        commands = [ "git" ];
      };
    };
  };

  functionCommandOverlap = hm {
    cloister = {
      enable = true;
      sandboxes.dev.registry = {
        functions.git = "printf hi\\n";
        commands = [ "git" ];
      };
    };
  };

  invalidSandboxName = hm {
    cloister = {
      enable = true;
      sandboxes."bad;name" = { };
    };
  };

  invalidNames = hm {
    cloister = {
      enable = true;
      sandboxes.dev.registry = {
        aliases."1bad" = "ls";
        functions."bad-name" = "printf hi\\n";
        commands = [ "1cmd" ];
      };
    };
  };

  invalidWrappedAliasValue = hm {
    cloister = {
      enable = true;
      sandboxes.dev.registry.aliases.pipe = "printf hi | cat";
    };
  };

  collisionEval = hm {
    cloister = {
      enable = true;
      sandboxes = {
        one.registry.commands = [ "git" ];
        two.registry.commands = [ "git" ];
      };
    };
  };

  customRcZshEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        shell = {
          name = "zsh";
          customRcPath = {
            zshenv = zshEnvFile;
            zshrc = zshRcFile;
          };
        };
        init.text = ''
          export FROM_INIT=1
        '';
        registry = {
          aliases.afterInit = "printf after-init\\n";
          noWrap = [ "afterInit" ];
        };
      };
    };
  };

  customRcBashEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        shell = {
          name = "bash";
          customRcPath = {
            bashenv = bashEnvFile;
            bashrc = bashRcFile;
            profile = profileFile;
          };
        };
        init.text = ''
          export FROM_INIT=1
        '';
        registry = {
          aliases.afterInit = "printf after-init\\n";
          noWrap = [ "afterInit" ];
        };
      };
    };
  };

  bashNoHostConfigEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        shell = {
          name = "bash";
          hostConfig = false;
          customRcPath = {
            bashenv = bashEnvFile;
            bashrc = bashRcFile;
            profile = profileFile;
          };
        };
        init.text = ''
          export FROM_INIT=1
        '';
      };
    };
  };

  zshNoHostConfigEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        shell = {
          name = "zsh";
          hostConfig = false;
          customRcPath = {
            zshenv = zshEnvFile;
            zshrc = zshRcFile;
          };
        };
        init.text = ''
          export FROM_INIT=1
        '';
      };
    };
  };

  outsideZsh = eval.config.programs.zsh.initContent;
  outsideBash = multiShellEval.config.programs.bash.initExtra;
  multiArgOutsideZsh = multiArgDefaultEval.config.programs.zsh.initContent;
  insideRegistry = eval.config.cloister.sandboxes.dev.registry.rendered.inside;
  multiXdgFiles = multiShellEval.config.xdg.configFile;
  customRcZshInit = customRcZshEval.config.cloister.sandboxes.dev.init.rendered;
  customRcBashInit = customRcBashEval.config.cloister.sandboxes.dev.init.rendered;
  customRcZshConfig = customRcZshEval.config.xdg.configFile."zsh/cloister-dev.zsh".text;
  customRcBashConfig = customRcBashEval.config.xdg.configFile."bash/cloister-dev.bash".text;
  bashNoHostConfig = bashNoHostConfigEval.config.cloister._internal.sandboxConfigs.dev;
  zshNoHostConfig = zshNoHostConfigEval.config.cloister._internal.sandboxConfigs.dev;
  bashNoHostConfigArgs = builtins.toJSON bashNoHostConfig.static_bwrap_args;
  bashNoHostConfigDynamic = builtins.toJSON bashNoHostConfig.dynamic_binds;
  zshNoHostConfigArgs = builtins.toJSON zshNoHostConfig.static_bwrap_args;
  zshBeforeInit = builtins.head (lib.splitString "export FROM_INIT=1" customRcZshInit);
  bashBeforeInit = builtins.head (lib.splitString "export FROM_INIT=1" customRcBashInit);
  zshBeforeRegistry = builtins.head (
    lib.splitString "alias afterInit='printf after-init\\n'" customRcZshConfig
  );
  bashBeforeRegistry = builtins.head (
    lib.splitString "alias afterInit='printf after-init\\n'" customRcBashConfig
  );
in
checks.mkCheck "test-cloister-registry" [
  (checks.expectContains "registry emits outside runner helper" "__cloister_run_dev()" outsideZsh)
  (checks.expectContains "registry wraps default command" "alias nvim='__cloister_run_dev -c nvim'"
    outsideZsh
  )
  (checks.expectContains "registry wraps normal command" "alias git='__cloister_run_dev -c git'"
    outsideZsh
  )
  (checks.expectContains "registry preserves multi-arg default command"
    "__cloister_run_browser -c chromium"
    multiArgOutsideZsh
  )
  (checks.expectContains "registry preserves multi-arg default command flag"
    "--ozone-platform=wayland"
    multiArgOutsideZsh
  )
  (checks.expectContains "registry renders outside function" "greet()" outsideZsh)
  (checks.expectNotContains "registry honors noWrap outside" "alias ll='__cloister_run_dev -c ls -l'"
    outsideZsh
  )
  (checks.expectContains "registry keeps noWrap inside" "alias ll='ls -l'" insideRegistry)
  (checks.expectContains "bash wrapper content renders for bash sandboxes" "hello()" outsideBash)
  (checks.expectTrue "multi-sandbox zsh init file exists" (multiXdgFiles ? "zsh/cloister-one.zsh"))
  (checks.expectTrue "multi-sandbox bash init file exists" (multiXdgFiles ? "bash/cloister-two.bash"))
  (checks.expectNotContains "multi-sandbox init files stay distinct" "hello()"
    multiXdgFiles."zsh/cloister-one.zsh".text
  )
  (checks.expectAssertionMessage "registry collision fails with message" collisionEval.assertions
    "cross-sandbox name collision"
  )
  (checks.expectAssertionMessage "alias and function overlap is rejected"
    aliasFunctionOverlap.assertions
    "names defined as both alias and function"
  )
  (checks.expectAssertionMessage "alias and command overlap is rejected"
    aliasCommandOverlap.assertions
    "names defined as both alias and command"
  )
  (checks.expectAssertionMessage "function and command overlap is rejected"
    functionCommandOverlap.assertions
    "names defined as both function and command"
  )
  (checks.expectAssertionMessage "invalid sandbox names are rejected" invalidSandboxName.assertions
    "sandbox names must match"
  )
  (checks.expectAssertionMessage "invalid alias names are rejected" invalidNames.assertions
    "alias names must match"
  )
  (checks.expectAssertionMessage "outside-wrapped aliases reject shell metacharacters"
    invalidWrappedAliasValue.assertions
    "aliases wrapped outside the sandbox must be argv-safe"
  )
  (checks.expectAssertionMessage "invalid function names are rejected" invalidNames.assertions
    "function names must match"
  )
  (checks.expectAssertionMessage "invalid command names are rejected" invalidNames.assertions
    "command names must match"
  )
  (checks.expectContains "zsh custom zshenv is sourced"
    "source \"$HOME/.config/cl-shell/dev/custom/zshenv\""
    customRcZshInit
  )
  (checks.expectContains "zsh custom zshrc is sourced"
    "source \"$HOME/.config/cl-shell/dev/custom/zshrc\""
    customRcZshInit
  )
  (checks.expectContains "bash custom bashenv is sourced"
    "source \"$HOME/.config/cl-shell/dev/custom/bashenv\""
    customRcBashInit
  )
  (checks.expectContains "bash custom bashrc is sourced"
    "source \"$HOME/.config/cl-shell/dev/custom/bashrc\""
    customRcBashInit
  )
  (checks.expectContains "bash custom profile is sourced"
    "source \"$HOME/.config/cl-shell/dev/custom/profile\""
    customRcBashInit
  )
  (checks.expectContains "zsh custom rc runs before init text" "custom/zshrc" zshBeforeInit)
  (checks.expectContains "bash custom rc runs before init text" "custom/profile" bashBeforeInit)
  (checks.expectContains "zsh registry content runs after init text" "export FROM_INIT=1"
    zshBeforeRegistry
  )
  (checks.expectContains "bash registry content runs after init text" "export FROM_INIT=1"
    bashBeforeRegistry
  )
  (checks.expectContains "bash hostConfig false still binds custom bashenv"
    "/home/tester/.config/cl-shell/dev/custom/bashenv"
    bashNoHostConfigArgs
  )
  (checks.expectContains "bash hostConfig false still binds custom profile"
    "/home/tester/.config/cl-shell/dev/custom/profile"
    bashNoHostConfigArgs
  )
  (checks.expectContains "bash hostConfig false installs minimal bash profile" "$HOME/.bash_profile"
    bashNoHostConfigDynamic
  )
  (checks.expectNotContains "bash hostConfig false omits host bashrc bind" "$HOME/.bashrc"
    bashNoHostConfigArgs
  )
  (checks.expectContains "zsh hostConfig false still binds custom zshenv"
    "/home/tester/.config/cl-shell/dev/custom/zshenv"
    zshNoHostConfigArgs
  )
  (checks.expectContains "zsh hostConfig false sets ZDOTDIR" ''"ZDOTDIR"'' zshNoHostConfigArgs)
  (checks.expectNotContains "zsh hostConfig false omits host zshrc bind" "$HOME/.zshrc"
    zshNoHostConfigArgs
  )
]
