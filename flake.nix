{
  description = "Bubblewrap namespace sandbox as a home-manager module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            mdformat.enable = true;
            nixfmt = {
              enable = true;
              package = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
            };
            rustfmt.enable = true;
            statix.enable = true;
            toml-sort.enable = true;
          };
        }
      );

    in
    {
      homeManagerModules.cloister = import ./modules/cloister;
      homeManagerModules.default = self.homeManagerModules.cloister;

      nixosModules.cloister-netns = import ./modules/cloister-netns;
      nixosModules.cloister-image-store = import ./modules/cloister-image-store;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          bubblewrap-subset-pid = pkgs.callPackage ./pkgs/bubblewrap-subset-pid { };
          inherit (pkgs) cargo-audit;
          cloister-netns = pkgs.callPackage ./helpers/cloister-netns { };
          cloister-wayland-validate = pkgs.callPackage ./helpers/cloister-wayland-validate { };
          cloister-dbus-validate = pkgs.callPackage ./helpers/cloister-dbus-validate { };
          cloister-pipewire-validate = pkgs.callPackage ./helpers/cloister-pipewire-validate { };
          cloister-seccomp-filter = pkgs.callPackage ./helpers/cloister-seccomp-filter { };
          cloister-seccomp-validate = pkgs.callPackage ./helpers/cloister-seccomp-validate { };
          cloister-sandbox = pkgs.callPackage ./helpers/cloister-sandbox { };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cargo
              rustc
              clippy
              clang
              pkg-config
            ];
            buildInputs = with pkgs; [
              libclang
              libseccomp
              pipewire
              wayland
            ];

            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testChecks = import ./tests {
            inherit pkgs;
            inherit (nixpkgs) lib;
          };
        in
        {
          treefmt = treefmtEval.${system}.config.build.check self;
        }
        // testChecks
      );

      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);
    };
}
