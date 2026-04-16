{ pkgs }:
let
  inherit (pkgs) lib;
  hm = import ../lib/eval-home-manager.nix { inherit lib pkgs; };

  hmUser = "tester";
  homeDir = "/home/${hmUser}";
  runtimeDir = "/tmp/cloister-worker-broker-runtime";
  projectDir = "${homeDir}/project";
  nestedProjectDir = "${projectDir}/other-project";
  devPackage = builtins.elemAt eval.config.home.packages 0;
  workerPackage = builtins.elemAt eval.config.home.packages 1;

  fixture = pkgs.writeShellScriptBin "cloister-worker-broker-fixture" ''
    set -eu

    worker_bin=${workerPackage}/bin/cl-worker

    case "$1" in
      child-project-rw-write)
        printf '%s\n' 'project-rw' > project-rw.txt
        ;;
      child-overlay-write)
        printf '%s\n' 'overlay-child' > overlay-only.txt
        printf '%s\n' 'overlay-mutated' > host.txt
        ;;
      parent-project-rw)
        env CLOISTER_BROKER_CHILD_PROFILE=project "$worker_bin" -c "$0" child-project-rw-write
        ;;
      parent-overlay)
        env CLOISTER_BROKER_CHILD_PROFILE=ephemeral "$worker_bin" -c "$0" child-overlay-write
        ;;
      parent-same-project)
        cd ${lib.escapeShellArg nestedProjectDir}
        env CLOISTER_BROKER_CHILD_PROFILE=project "$worker_bin" -c "$0" child-project-rw-write
        ;;
      *)
        printf 'unknown fixture command: %s\n' "$1" >&2
        exit 2
        ;;
    esac
  '';

  eval = hm {
    home.username = hmUser;
    home.homeDirectory = homeDir;
    xdg = {
      configHome = "${homeDir}/.config";
      stateHome = "${homeDir}/.local/state";
      cacheHome = "${homeDir}/.cache";
      dataHome = "${homeDir}/.local/share";
    };
    cloister = {
      enable = true;
      sandboxes.dev = {
        preset = "hardened";
        shell.name = "bash";
        shell.hostConfig = false;
        validators.enable = false;
        # Nested worker launches resolve their wrapper init bind source from the
        # outer sandbox filesystem, so the runtime fixture must expose the bash
        # config directory there as well.
        sandbox.binds.ro = [
          {
            src = "/etc/passwd";
            dest = "/etc/passwd";
          }
          {
            src = "/etc/group";
            dest = "/etc/group";
          }
          {
            src = "${homeDir}/.config/bash";
            dest = "${homeDir}/.config/bash";
          }
        ];
        workerBroker = {
          enable = true;
          spawnableProfiles = {
            ephemeral = {
              sandbox = "worker";
              workspace.mode = "project-overlay";
            };
            project = {
              sandbox = "worker";
              workspace.mode = "project-rw";
            };
          };
        };
      };
      sandboxes.worker = {
        preset = "hardened";
        shell.name = "bash";
        shell.hostConfig = false;
        validators.enable = false;
      };
    };
  };
in
pkgs.testers.runNixOSTest (_: {
  name = "cloister-runtime-worker-broker";

  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation.cores = 2;

      environment.systemPackages = [
        fixture
        pkgs.bash
      ]
      ++ eval.config.home.packages;

      users.users.${hmUser} = {
        isNormalUser = true;
        createHome = true;
        extraGroups = [ ];
      };

      systemd.services.cloister-runtime-worker-broker-fixture = {
        description = "Cloister runtime worker broker fixture";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "cloister-runtime-worker-broker-fixture" ''
            set -eu

            install -d -m 0700 -o ${hmUser} -g users ${homeDir}
            install -d -m 0700 -o ${hmUser} -g users ${homeDir}/.config
            install -d -m 0700 -o ${hmUser} -g users ${homeDir}/.config/bash
            install -d -m 0700 -o ${hmUser} -g users ${homeDir}/.local/state
            install -d -m 0700 -o ${hmUser} -g users ${homeDir}/.cache
            install -d -m 0700 -o ${hmUser} -g users ${homeDir}/.local/share
            install -d -m 0700 -o ${hmUser} -g users ${runtimeDir}
            install -d -m 0700 -o ${hmUser} -g users ${projectDir}
            install -d -m 0700 -o ${hmUser} -g users ${nestedProjectDir}

            cat > ${homeDir}/.config/bash/cloister-dev.bash <<'EOF'
            ${eval.config.xdg.configFile."bash/cloister-dev.bash".text}
            EOF

            cat > ${homeDir}/.config/bash/cloister-worker.bash <<'EOF'
            ${eval.config.xdg.configFile."bash/cloister-worker.bash".text}
            EOF

            printf '%s\n' 'host-original' > ${projectDir}/host.txt
            chown ${hmUser}:users ${homeDir}/.config/bash/cloister-dev.bash
            chown ${hmUser}:users ${homeDir}/.config/bash/cloister-worker.bash
            chown ${hmUser}:users ${projectDir}/host.txt
          '';
        };
      };
    };

  testScript = ''
    start_all()

    machine.wait_for_unit("cloister-runtime-worker-broker-fixture.service")

    tester_shell = (
        "${pkgs.util-linux}/bin/runuser -u ${hmUser} -- env "
        + "HOME=${homeDir} USER=${hmUser} LOGNAME=${hmUser} "
        + "XDG_CONFIG_HOME=${homeDir}/.config "
        + "XDG_STATE_HOME=${homeDir}/.local/state "
        + "XDG_CACHE_HOME=${homeDir}/.cache "
        + "XDG_DATA_HOME=${homeDir}/.local/share "
        + "XDG_RUNTIME_DIR=${runtimeDir} "
        + "${pkgs.bash}/bin/bash -lc "
    )

    machine.succeed(
        tester_shell
        + "'cd ${projectDir} && rm -f project-rw.txt && ${devPackage}/bin/cl-dev -c ${fixture}/bin/cloister-worker-broker-fixture parent-project-rw'"
    )
    machine.succeed("grep -Fx 'project-rw' ${projectDir}/project-rw.txt")
    machine.fail(
        "${pkgs.bash}/bin/bash -lc 'set -- ${runtimeDir}/cloister/broker/sessions/*.json; test -e \"$1\"'"
    )

    machine.succeed(
        tester_shell
        + "'cd ${projectDir} && printf \"%s\\n\" host-original > host.txt && rm -f overlay-only.txt && ${devPackage}/bin/cl-dev -c ${fixture}/bin/cloister-worker-broker-fixture parent-overlay'"
    )
    machine.succeed("grep -Fx 'host-original' ${projectDir}/host.txt")
    machine.fail("test -e ${projectDir}/overlay-only.txt")

    machine.succeed(
        tester_shell
        + "'cd ${projectDir} && env CLOISTER_BROKER_CHILD_PROFILE=project CLOISTER_BROKER_PARENT_CAPABILITY='\"'\"'{\"token\":\"forged-token\"}'\"'\"' ${workerPackage}/bin/cl-worker -c ${fixture}/bin/cloister-worker-broker-fixture child-project-rw-write 2>&1 | grep -F \"trusted broker session record mount is unavailable\"'"
    )
    machine.succeed(
        tester_shell
        + "'cd ${projectDir} && env CLOISTER_BROKER_CHILD_PROFILE=project CLOISTER_BROKER_PARENT_CAPABILITY='\"'\"'{\"token\":\"forged-token\",\"project_root\":\"${projectDir}\",\"dir_hash\":\"forged\",\"spawnable_profiles\":{},\"available_delegated_per_dir_mounts\":{}}'\"'\"' ${workerPackage}/bin/cl-worker -c ${fixture}/bin/cloister-worker-broker-fixture child-project-rw-write 2>&1 | grep -E \"parse CLOISTER_BROKER_PARENT_CAPABILITY|unknown field\"'"
    )

    machine.succeed(
        tester_shell
        + "'cd ${projectDir} && ${devPackage}/bin/cl-dev -c ${fixture}/bin/cloister-worker-broker-fixture parent-same-project 2>&1 | grep -F \"broker project identity does not match\"'"
    )
  '';
})
