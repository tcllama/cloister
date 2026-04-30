{
  checks,
  hm,
  ...
}:
let
  emptyProfiles = hm {
    cloister = {
      enable = true;
      sandboxes.dev.workerBroker = {
        enable = true;
        spawnableProfiles = { };
      };
    };
  };

  missingSandbox = hm {
    cloister = {
      enable = true;
      sandboxes.dev.workerBroker = {
        enable = true;
        spawnableProfiles.ephemeral = {
          sandbox = "worker";
          workspace.mode = "project-overlay";
        };
      };
    };
  };

  missingDelegatedMount = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts = {
              ".cache/pre-commit" = "ro";
            };
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  workerBrokerWithoutBindWorkingDirectory = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        sandbox.bindWorkingDirectory = false;
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  dangerousDelegatedMountPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees.path = "/home/tester/.ssh";
        };
      };
      sandboxes.worker = { };
    };
  };

  unsafeDelegatedMountPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees.path = "$(pwd)";
        };
      };
      sandboxes.worker = { };
    };
  };

  relativeDelegatedMountPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees.path = "relative/base";
        };
      };
      sandboxes.worker = { };
    };
  };

  traversingDelegatedMountPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees.path = "/safe/base/../escape";
        };
      };
      sandboxes.worker = { };
    };
  };

  validAbsoluteHomeDelegatedMountPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees.path = "/home/tester/projects/worktrees";
        };
      };
      sandboxes.worker = { };
    };
  };

  dangerousDelegatedMountSubPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees = {
            path = "/home/tester";
            subPath = ".ssh";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  traversingDelegatedMountSubPath = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts.worktrees = "rw";
          };
          availableDelegatedPerDirMounts.worktrees = {
            path = "/safe/base";
            subPath = "../.ssh";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  absoluteAvailableDelegatedMountKey = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts."/etc" = "ro";
          };
          availableDelegatedPerDirMounts."/etc".path = "/safe/base";
        };
      };
      sandboxes.worker = { };
    };
  };

  traversingAvailableDelegatedMountKey = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts."../escape" = "ro";
          };
          availableDelegatedPerDirMounts."../escape".path = "/safe/base";
        };
      };
      sandboxes.worker = { };
    };
  };

  unsafeAvailableDelegatedMountKey = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts."$HOME/escape" = "ro";
          };
          availableDelegatedPerDirMounts."$HOME/escape".path = "/safe/base";
        };
      };
      sandboxes.worker = { };
    };
  };

  newlineReferencedDelegatedMountKey = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
            delegatedPerDirMounts."line\nescape" = "ro";
          };
          availableDelegatedPerDirMounts."line\nescape".path = "/safe/base";
        };
      };
      sandboxes.worker = { };
    };
  };

  aliasCollision = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        registry.aliases.clb-ephemeral = "echo existing";
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  functionCollision = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        registry.functions.clb-ephemeral = ''
          echo existing
        '';
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  commandCollision = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        registry.commands = [ "clb-ephemeral" ];
        workerBroker = {
          enable = true;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  disabledLauncherCollisionIgnored = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        registry.commands = [ "clb-ephemeral" ];
        workerBroker = {
          enable = false;
          spawnableProfiles.ephemeral = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker = { };
    };
  };

  crossSandboxGeneratedLauncherCollision = hm {
    cloister = {
      enable = true;
      sandboxes = {
        dev = {
          workerBroker = {
            enable = true;
            spawnableProfiles.ephemeral = {
              sandbox = "worker-a";
              workspace.mode = "project-overlay";
            };
          };
        };
        ops = {
          workerBroker = {
            enable = true;
            spawnableProfiles.ephemeral = {
              sandbox = "worker-b";
              workspace.mode = "project-overlay";
            };
          };
        };
        worker-a = { };
        worker-b = { };
      };
    };
  };

  unsafeProfileKey = hm {
    cloister = {
      enable = true;
      sandboxes.dev = {
        workerBroker = {
          enable = true;
          spawnableProfiles."bad/name" = {
            sandbox = "worker";
            workspace.mode = "project-overlay";
          };
        };
      };
      sandboxes.worker = { };
    };
  };
in
checks.mkCheck "test-cloister-worker-broker" [
  (checks.expectAssertionMessage "worker broker requires at least one spawnable profile"
    emptyProfiles.assertions
    "workerBroker.enable requires at least one workerBroker.spawnableProfiles entry"
  )
  (checks.expectAssertionMessage "worker broker profiles require an existing sandbox"
    missingSandbox.assertions
    "workerBroker.spawnableProfiles.ephemeral.sandbox references unknown sandbox 'worker'"
  )
  (checks.expectAssertionMessage "worker broker delegated mounts must be declared"
    missingDelegatedMount.assertions
    "workerBroker.spawnableProfiles.ephemeral.delegatedPerDirMounts references unknown availableDelegatedPerDirMounts entry '.cache/pre-commit'"
  )
  (checks.expectAssertionMessage "worker broker requires bind working directory"
    workerBrokerWithoutBindWorkingDirectory.assertions
    "workerBroker.enable requires sandbox.bindWorkingDirectory = true"
  )
  (checks.expectAssertionMessage "worker broker delegated mount paths reuse dangerous path checks"
    dangerousDelegatedMountPath.assertions
    "contains paths that expose credentials or secrets"
  )
  (checks.expectAssertionMessage "worker broker delegated mount paths reject unsafe expansions"
    unsafeDelegatedMountPath.assertions
    "cannot contain variable expansions ($) or newlines"
  )
  (checks.expectAssertionMessage "worker broker delegated mount paths must be absolute host paths"
    relativeDelegatedMountPath.assertions
    "workerBroker.availableDelegatedPerDirMounts.worktrees.path must be an absolute traversal-free host path"
  )
  (checks.expectAssertionMessage "worker broker delegated mount paths reject traversal"
    traversingDelegatedMountPath.assertions
    "workerBroker.availableDelegatedPerDirMounts.worktrees.path must be an absolute traversal-free host path"
  )
  (checks.expectFalse "worker broker delegated mount paths allow valid absolute home paths" (
    builtins.any (assertion: !assertion.assertion) validAbsoluteHomeDelegatedMountPath.assertions
  ))
  (checks.expectAssertionMessage "worker broker delegated mount subpaths reuse dangerous path checks"
    dangerousDelegatedMountSubPath.assertions
    "contains paths that expose credentials or secrets"
  )
  (checks.expectAssertionMessage
    "worker broker delegated mount subpaths must stay relative descendants"
    traversingDelegatedMountSubPath.assertions
    "workerBroker.availableDelegatedPerDirMounts.worktrees.subPath must be a relative descendant path without traversal"
  )
  (checks.expectAssertionMessage
    "worker broker available delegated mount keys must stay sandbox-relative"
    absoluteAvailableDelegatedMountKey.assertions
    "workerBroker availableDelegatedPerDirMounts keys must be sandbox-relative descendant paths"
  )
  (checks.expectAssertionMessage "worker broker referenced delegated mount keys must reject traversal"
    traversingAvailableDelegatedMountKey.assertions
    "workerBroker availableDelegatedPerDirMounts keys must be sandbox-relative descendant paths"
  )
  (checks.expectAssertionMessage "worker broker delegated mount keys reject variable expansions"
    unsafeAvailableDelegatedMountKey.assertions
    "cannot contain variable expansions ($) or newlines"
  )
  (checks.expectAssertionMessage "worker broker delegated mount keys reject newlines"
    newlineReferencedDelegatedMountKey.assertions
    "cannot contain variable expansions ($) or newlines"
  )
  (checks.expectAssertionMessage "worker broker generated launchers cannot collide with aliases"
    aliasCollision.assertions
    "generated worker broker launcher names collide with registry.aliases: clb-ephemeral"
  )
  (checks.expectAssertionMessage "worker broker generated launchers cannot collide with functions"
    functionCollision.assertions
    "generated worker broker launcher names collide with registry.functions: clb-ephemeral"
  )
  (checks.expectAssertionMessage "worker broker generated launchers cannot collide with commands"
    commandCollision.assertions
    "generated worker broker launcher names collide with registry.commands: clb-ephemeral"
  )
  (checks.expectFalse "disabled worker broker ignores generated launcher collisions" (
    builtins.any (assertion: !assertion.assertion) disabledLauncherCollisionIgnored.assertions
  ))
  (checks.expectFalse "generated launcher names stay sandbox-local across sandboxes" (
    builtins.any (assertion: !assertion.assertion) crossSandboxGeneratedLauncherCollision.assertions
  ))
  (checks.expectAssertionMessage
    "worker broker profile keys must produce safe generated launcher names"
    unsafeProfileKey.assertions
    "workerBroker.spawnableProfiles keys must produce safe generated launcher names: bad/name"
  )
]
