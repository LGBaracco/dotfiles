{pkgs, ...}: {
  # ── Fish shell ────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      zoxide init fish | source
      set -gx EDITOR nvim
      set -gx VISUAL nvim

      # Oxocarbon (base16-oxocarbon-dark)
      set -g fish_color_normal f2f4f8
      set -g fish_color_command 42be65
      set -g fish_color_keyword be95ff
      set -g fish_color_quote 33b1ff
      set -g fish_color_redirection ff7eb6
      set -g fish_color_end ee5396
      set -g fish_color_error ee5396 --bold
      set -g fish_color_param f2f4f8
      set -g fish_color_comment 525252
      set -g fish_color_operator ff7eb6
      set -g fish_color_escape 82cfff
      set -g fish_color_autosuggestion 525252
      set -g fish_color_cwd 42be65
      set -g fish_color_cwd_root ee5396
      set -g fish_color_option 78a9ff
      set -g fish_color_valid_path --underline
      set -g fish_color_selection --background=393939
      set -g fish_color_search_match --background=393939
      set -g fish_pager_color_prefix 42be65 --bold
      set -g fish_pager_color_completion f2f4f8
      set -g fish_pager_color_description 525252
      set -g fish_pager_color_progress ee5396 --bold

      set fish_greeting

      function fish_prompt
        echo \n
        echo (prompt_pwd)
        echo -n "> "
      end

    '';

    shellAliases = {
      ll = "eza";
      ls = "eza -lah --icons auto";
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
