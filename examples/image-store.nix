{ pkgs, ... }:
{
  cloister.sandboxes.editor-dev = {
    shell.name = "zsh";

    extraPackages = with pkgs; [
      helix
      git
      ripgrep
      fd
      jq
      nil
      lua-language-server
    ];

    git.enable = true;

    sandbox = {
      nixStore.mode = "image-store";

      extraBinds = {
        optional.rw = [
          ".local/share/helix"
          ".cache/helix"
        ];

        managedFile = [ "helix/languages.toml" ];
      };

      env = {
        EDITOR = "hx";
        VISUAL = "hx";
      };
    };

    registry.commands = [ "hx" ];
  };
}
