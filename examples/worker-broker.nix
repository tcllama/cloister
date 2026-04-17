{ lib, pkgs, ... }:
let
  sharedNodeTools = with pkgs; [
    neovim
    nodejs
    pnpm
    typescript-language-server
    eslint
    biome
  ];

  base = import ./developer.nix { inherit pkgs; };
  baseDevExtraPackages = base.cloister.sandboxes.dev.extraPackages or [ ];
in
lib.recursiveUpdate base {
  cloister.sandboxes = {
    dev = {
      extraPackages = baseDevExtraPackages ++ sharedNodeTools;

      dbus = {
        enable = true;
        portal.notifications = true;
      };

      workerBroker = {
        enable = true;
        spawnableProfiles = {
          overlay = {
            sandbox = "worker-overlay";
            workspace.mode = "project-overlay";
          };
          rw = {
            sandbox = "worker-rw";
            workspace.mode = "project-rw";
          };
        };
      };
    };

    worker-overlay = {
      preset = "hardened";
      extraPackages = sharedNodeTools;

      shell.hostConfig = false;
      validators.enable = false;
    };

    worker-rw = {
      preset = "hardened";
      extraPackages = sharedNodeTools;

      shell.hostConfig = false;
      validators.enable = false;
      ssh.enable = true;
      git.enable = true;
    };
  };
}
