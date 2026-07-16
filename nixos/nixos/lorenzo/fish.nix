{ pkgs, ... }:

{
  # ── Fish shell ────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      zoxide init fish | source
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set fish_greeting

      function fish_prompt
        echo \n
        echo (set_color blue)(prompt_pwd)
        echo -n (set_color green)"> "
      end

    '';

    shellAliases = {
      ll = "eza";
      ls = "eza -lah --icons";
      tree = "eza --tree --icons";
      #cat  = "bat";
      cd = "z"; # zoxide
      gs = "git status";
      lg = "lazygit";
      vi = "nvim";
      vim = "nvim";
      # Rebuild shortcut
      nrs = "sudo nixos-rebuild switch --flake $HOME/nixos#$hostname";
    };
  };
}
