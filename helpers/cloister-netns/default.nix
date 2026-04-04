{
  lib,
  rustPlatform,
  allowedNamespaces ? [ ],
  enforceExecAllowlist ? true,
  allowedExecPaths ? [ ],
  requiredGroup ? "",
}:
let
  allowlist = builtins.concatStringsSep "\n" allowedNamespaces;
  allowedExecPathsStr = builtins.concatStringsSep "\n" allowedExecPaths;
in
rustPlatform.buildRustPackage {
  pname = "cloister-netns";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  CLOISTER_NETNS_ALLOWLIST = allowlist;
  CLOISTER_NETNS_ENFORCE_EXEC = if enforceExecAllowlist then "1" else "0";
  CLOISTER_NETNS_ALLOWED_EXEC_PATHS = allowedExecPathsStr;
  CLOISTER_NETNS_REQUIRED_GROUP = requiredGroup;

  meta = with lib; {
    description = "Network namespace helper for cloister sandbox";
    homepage = "https://github.com/tcllama/cloister";
    license = licenses.mit;
    mainProgram = "cloister-netns";
    platforms = platforms.linux;
  };
}
