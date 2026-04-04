{
  checks,
  lib,
  pkgs,
  ...
}:
let
  bwrapLib = import ../../modules/cloister/_bwrap.nix { inherit lib; };
  subsetPidPackage = pkgs.callPackage ../../pkgs/bubblewrap-subset-pid { };

  emptyArgs = bwrapLib.mkBwrapArgs { };

  renderedArgs = bwrapLib.mkBwrapArgs {
    dirs = [ "/sandbox" ];
    tmpfs = [ "/tmp" ];
    symlinks = [
      {
        target = "/nix/store/source";
        link = "/link";
      }
    ];
    binds = {
      rw = [
        {
          src = "/rw-src";
          dest = "/rw-dest";
          try = false;
        }
        {
          src = "/rw-optional";
          dest = null;
          try = true;
        }
      ];
      ro = [
        {
          src = ''/path\with\slashes'';
          dest = "/dest\"quote";
          try = false;
        }
        {
          src = "/ro-optional";
          dest = "/opt";
          try = true;
        }
      ];
    };
    env = {
      Z_VAR = "z";
      A_VAR = "a";
    };
  };

  subsetPidPatch = builtins.readFile ../../pkgs/bubblewrap-subset-pid/0001-mount-proc-with-subset-pid.patch;
  subsetPidPackagePatches =
    if subsetPidPackage ? drvAttrs && subsetPidPackage.drvAttrs ? patches then
      map toString subsetPidPackage.drvAttrs.patches
    else
      [ ];
in
checks.mkCheck "test-cloister-bwrap" [
  (checks.expectEq "empty args stay empty" [ ] emptyArgs)
  (checks.expectEq "bubblewrap args render in stable order" [
    "--dir"
    "/sandbox"
    "--tmpfs"
    "/tmp"
    "--symlink"
    "/nix/store/source"
    "/link"
    "--bind"
    "/rw-src"
    "/rw-dest"
    "--bind-try"
    "/rw-optional"
    "/rw-optional"
    "--ro-bind"
    ''/path\with\slashes''
    "/dest\"quote"
    "--ro-bind-try"
    "/ro-optional"
    "/opt"
    "--setenv"
    "A_VAR"
    "a"
    "--setenv"
    "Z_VAR"
    "z"
  ] renderedArgs)
  (checks.expectContains "subset=pid patch kept in source" "subset=pid" subsetPidPatch)
  (checks.expectContains "subset=pid patch applied to package" "0001-mount-proc-with-subset-pid.patch"
    (builtins.toJSON subsetPidPackagePatches)
  )
]
