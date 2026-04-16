{
  checks,
  hm,
  pkgs,
  ...
}:
let
  eval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        defaultCommand = [
          "nvim"
          "--clean"
        ];
        shell.name = "bash";
        network.namespace = "vpn";
        dbus.enable = true;
        sandbox.env = {
          DOLLAR_VAR = "$HOME/literal";
          PROMPT_VAR = "$" + "{PS1@P}";
        };
        sandbox = {
          anonymize = {
            enable = true;
            username = "guest";
          };
          extraBinds.optional.ro = [ ".gitconfig" ];
        };
      };
    };
  };

  hostConfigOffEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.shell = {
        name = "zsh";
        hostConfig = false;
      };
    };
  };

  localeOverrideEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.env.LOCALE_ARCHIVE = "/custom/locale-archive";
    };
  };

  plainEval = hm {
    cloister = {
      enable = true;
      sandboxes.plain = { };
    };
  };

  workdirDisabledEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.bindWorkingDirectory = false;
    };
  };

  featuresEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        ssh = {
          enable = true;
          allowFingerprints = [ "SHA256:test-fingerprint" ];
          filterTimeoutSeconds = 7;
        };
        fido2.enable = true;
        video.enable = true;
        printing.enable = true;
        git.enable = true;
        sandbox.devBinds = [ "/dev/input/js0" ];
      };
    };
  };

  noNetworkEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.network.enable = false;
    };
  };

  workerBrokerNoNetworkEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        network.enable = false;
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker.preset = "hardened";
    };
  };

  seccompDisabledEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.seccomp.enable = false;
    };
  };

  chromiumSeccompEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.sandbox.seccomp.allowChromiumSandbox = true;
    };
  };

  imageStoreEval = hm {
    _module.args.osConfig = {
      cloister.imageStore = {
        base = "/var/lib/cloister/images";
        mountBase = "/run/cloister/images";
      };
    };

    cloister = {
      enable = true;
      sandboxes.dev.sandbox.nixStore.mode = "image-store";
    };
  };

  missingSharedNet = hm {
    cloister = {
      enable = true;
      sandboxes.dev.network = {
        enable = false;
        namespace = "vpn";
      };
    };
  };

  defaultBashEval = hm {
    cloister = {
      enable = true;
      defaultShell = "bash";
      sandboxes.dev = { };
    };
  };

  validatorsEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev.validators.enable = true;
    };
  };

  packagesEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        packages = [ pkgs.hello ];
        extraPackages = [ pkgs.jq ];
      };
    };
  };

  workerBrokerEval = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles = {
            ephemeral = {
              sandbox = "worker";
              workspace.mode = "project-overlay";
              delegatedPerDirMounts = {
                ".cache/pre-commit" = "ro";
              };
            };
            project = {
              sandbox = "worker";
              workspace.mode = "project-rw";
              delegatedPerDirMounts = {
                "worktrees" = "rw";
                ".cache/pre-commit" = "ro";
              };
            };
          };
          availableDelegatedPerDirMounts = {
            "worktrees".path = "/local/worktrees/dev";
            ".cache/pre-commit" = {
              path = "/local/ephemeral/dev";
              subPath = ".cache/pre-commit";
            };
          };
        };
      };
      sandboxes.worker.preset = "hardened";
    };
  };

  sandboxConfig = eval.config.cloister._internal.sandboxConfigs.dev;
  plainConfig = plainEval.config.cloister._internal.sandboxConfigs.plain;
  hostConfigOff = hostConfigOffEval.config.cloister._internal.sandboxConfigs.dev;
  localeOverride = localeOverrideEval.config.cloister._internal.sandboxConfigs.dev;
  workdirDisabled = workdirDisabledEval.config.cloister._internal.sandboxConfigs.dev;
  featuresConfig = featuresEval.config.cloister._internal.sandboxConfigs.dev;
  noNetworkConfig = noNetworkEval.config.cloister._internal.sandboxConfigs.dev;
  workerBrokerNoNetworkConfig =
    workerBrokerNoNetworkEval.config.cloister._internal.sandboxConfigs.dev;
  seccompDisabled = seccompDisabledEval.config.cloister._internal.sandboxConfigs.dev;
  chromiumSeccomp = chromiumSeccompEval.config.cloister._internal.sandboxConfigs.dev;
  imageStoreConfig = imageStoreEval.config.cloister._internal.sandboxConfigs.dev;
  defaultBashConfig = defaultBashEval.config.cloister._internal.sandboxConfigs.dev;
  validatorsConfig = validatorsEval.config.cloister._internal.sandboxConfigs.dev;
  validatorsRegistry = validatorsEval.config.cloister.sandboxes.dev.registry.rendered.outside.zsh;
  packagesConfig = packagesEval.config.cloister._internal.sandboxConfigs.dev;
  packagesStaticArgs = builtins.toJSON packagesConfig.static_bwrap_args;
  workerBrokerConfig = workerBrokerEval.config.cloister._internal.sandboxConfigs.dev;

  plainStaticArgs = builtins.toJSON plainConfig.static_bwrap_args;
  plainDynamicBinds = builtins.toJSON plainConfig.dynamic_binds;
  hostConfigOffStaticArgs = builtins.toJSON hostConfigOff.static_bwrap_args;
  sandboxConfigJson = builtins.toJSON sandboxConfig;
  localeOverrideStaticArgs = builtins.toJSON localeOverride.static_bwrap_args;
in
checks.mkCheck "test-cloister-rendered-config" [
  (checks.expectEq "sandbox name propagates into config" "dev" sandboxConfig.name)
  (checks.expectEq "anonymized sandbox home" "/home/guest" sandboxConfig.sandbox_home)
  (checks.expectContains "anonymized locale defaults to C.UTF-8" ''"LANG","C.UTF-8"''
    sandboxConfigJson
  )
  (checks.expectContains "anonymized lc_all defaults to C.UTF-8" ''"LC_ALL","C.UTF-8"''
    sandboxConfigJson
  )
  (checks.expectContains "anonymized timezone defaults to UTC" ''"TZ","UTC"'' sandboxConfigJson)
  (checks.expectNotContains "anonymized sandbox does not passthrough host locale vars"
    ''"passthrough_env":["LANG"''
    sandboxConfigJson
  )
  (checks.expectEq "default command renders in config" [
    "nvim"
    "--clean"
  ] sandboxConfig.default_command)
  (checks.expectContains "literal dollar env value is preserved" ''"$HOME/literal"''
    sandboxConfigJson
  )
  (checks.expectContains "literal prompt env value is preserved" (
    "\"$" + "{PS1@P}\""
  ) sandboxConfigJson)
  (checks.expectContains "anonymized sandbox uses patched bubblewrap" "bubblewrap-subset-pid"
    sandboxConfig.bwrap_path
  )
  (checks.expectNotContains "non-anonymized sandbox uses regular bubblewrap" "bubblewrap-subset-pid"
    plainConfig.bwrap_path
  )
  (checks.expectEq "network namespace helper path" "/run/wrappers/bin/cloister-netns"
    sandboxConfig.netns_helper_path
  )
  (checks.expectEq "dbus proxy socket name" "cloister/dbus/dev" sandboxConfig.dbus_proxy_socket_name)
  (checks.expectEq "bash shell selected" "bash" sandboxConfig.shell_name)
  (checks.expectEq "defaultShell propagates to sandboxes" "bash" defaultBashConfig.shell_name)
  (checks.expectTrue "build revision is populated" (sandboxConfig.build_revision != null))
  (checks.expectTrue "plain sandbox defaults to host store" (plainConfig.store_mode == "host"))
  (checks.expectTrue "bind working directory defaults true" plainConfig.bind_working_directory)
  (checks.expectContains "bind working directory true adds sandbox dir" "$SANDBOX_DIR" (
    builtins.toJSON plainConfig.dynamic_binds
  ))
  (checks.expectContains "dynamic bind keeps HOME reference" "$HOME/.gitconfig" (
    builtins.toJSON sandboxConfig.dynamic_binds
  ))
  (checks.expectFalse "host config can be disabled" hostConfigOff.shell_host_config)
  (checks.expectContains "disabled host config sets ZDOTDIR" ''"ZDOTDIR"'' hostConfigOffStaticArgs)
  (checks.expectNotContains "disabled host config omits host zshrc" ''"$HOME/.zshrc"''
    hostConfigOffStaticArgs
  )
  (checks.expectContains "default host config keeps shell binds" ''"$HOME/.zshrc"'' plainDynamicBinds)
  (checks.expectEq "working directory binding can be disabled" false
    workdirDisabled.bind_working_directory
  )
  (checks.expectNotContains "disabled working directory omits sandbox dir" "$SANDBOX_DIR" (
    builtins.toJSON workdirDisabled.dynamic_binds
  ))
  (checks.expectContains "locale archive defaults to glibc locales" "locale-archive" plainStaticArgs)
  (checks.expectContains "locale archive override is preserved" "/custom/locale-archive"
    localeOverrideStaticArgs
  )
  (checks.expectEq "shared network defaults on" true plainConfig.network_enable)
  (checks.expectEq "shared network can be disabled" false noNetworkConfig.network_enable)
  (checks.expectContains "worker broker with disabled network uses nested-sandbox seccomp variant"
    "-chromium"
    workerBrokerNoNetworkConfig.seccomp_filter_path
  )
  (checks.expectFalse
    "worker broker with disabled network does not reuse plain no-network seccomp filter"
    (workerBrokerNoNetworkConfig.seccomp_filter_path == noNetworkConfig.seccomp_filter_path)
  )
  (checks.expectAssertionMessage "network namespace requires shared networking"
    missingSharedNet.assertions
    "network.namespace requires network.enable = true"
  )
  (checks.expectContains "netns resolv.conf bind renders" "/etc/netns/vpn/resolv.conf" (
    builtins.toJSON sandboxConfig.static_bwrap_args
  ))
  (checks.expectContains "anonymized sandbox keeps netns hosts source available"
    "/etc/netns/vpn/hosts"
    (builtins.toJSON sandboxConfig.static_bwrap_args)
  )
  (checks.expectContains "anonymized sandbox uses utc localtime" "/share/zoneinfo/UTC" (
    builtins.toJSON sandboxConfig.static_bwrap_args
  ))
  (checks.expectEq "ssh integration toggle renders" true featuresConfig.ssh_enable)
  (checks.expectEq "ssh fingerprints render" [
    "SHA256:test-fingerprint"
  ] featuresConfig.ssh_allow_fingerprints)
  (checks.expectEq "ssh timeout renders" 7 featuresConfig.ssh_filter_timeout_seconds)
  (checks.expectEq "fido2 integration toggle renders" true featuresConfig.fido2_enable)
  (checks.expectEq "video integration toggle renders" true featuresConfig.video_enable)
  (checks.expectEq "printing integration toggle renders" true featuresConfig.printing_enable)
  (checks.expectEq "git integration toggle renders" true featuresConfig.git_enable)
  (checks.expectEq "device binds render" [ "/dev/input/js0" ] featuresConfig.dev_binds)
  (checks.expectContains "custom packages are included in PATH" "hello" packagesStaticArgs)
  (checks.expectContains "extraPackages are included in PATH" "jq" packagesStaticArgs)
  (checks.expectContains "validators expose wrapped command outside sandbox"
    "alias cloister-wayland-validate='__cloister_run_dev -c cloister-wayland-validate'"
    validatorsRegistry
  )
  (checks.expectContains "validators add helper binaries to sandbox PATH" "cloister-dbus-validate" (
    builtins.toJSON validatorsConfig.static_bwrap_args
  ))
  (checks.expectEq "worker broker enable renders" true workerBrokerConfig.worker_broker.enable)
  (checks.expectEq "worker broker ephemeral sandbox renders" "worker"
    workerBrokerConfig.worker_broker.spawnable_profiles.ephemeral.sandbox
  )
  (checks.expectEq "worker broker project sandbox renders" "worker"
    workerBrokerConfig.worker_broker.spawnable_profiles.project.sandbox
  )
  (checks.expectEq "worker broker project mode renders" "project-rw"
    workerBrokerConfig.worker_broker.spawnable_profiles.project.workspace.mode
  )
  (checks.expectEq "worker broker delegated mount access renders" "rw"
    workerBrokerConfig.worker_broker.spawnable_profiles.project.delegated_per_dir_mounts.worktrees
  )
  (checks.expectEq "worker broker available worktrees path renders" "/local/worktrees/dev"
    workerBrokerConfig.worker_broker.available_delegated_per_dir_mounts.worktrees.path
  )
  (checks.expectEq "worker broker available worktrees subPath defaults null" null
    workerBrokerConfig.worker_broker.available_delegated_per_dir_mounts.worktrees.sub_path
  )
  (checks.expectEq "worker broker available pre-commit path renders" "/local/ephemeral/dev"
    workerBrokerConfig.worker_broker.available_delegated_per_dir_mounts.".cache/pre-commit".path
  )
  (checks.expectEq "worker broker available pre-commit subPath renders" ".cache/pre-commit"
    workerBrokerConfig.worker_broker.available_delegated_per_dir_mounts.".cache/pre-commit".sub_path
  )
  (checks.expectNotContains "worker broker rendered config does not imply env session authority"
    ''"parent_session"''
    (builtins.toJSON workerBrokerConfig.worker_broker)
  )
  (checks.expectEq "seccomp can be disabled" false seccompDisabled.seccomp_enable)
  (checks.expectContains "chromium seccomp uses chromium-named filter" "-chromium"
    chromiumSeccomp.seccomp_filter_path
  )
  (checks.expectEq "image-store mode renders" "image-store" imageStoreConfig.store_mode)
  (checks.expectContains "image-store path renders store id" ".squashfs"
    imageStoreConfig.store_image_path
  )
  (checks.expectContains "image-store mount path renders store id" "/run/cloister/images/"
    imageStoreConfig.store_mount_path
  )
]
