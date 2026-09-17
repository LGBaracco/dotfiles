{ ... }: {
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

    '';

    shellAliases = {
      ll = "eza";
      ls = "eza -lah --icons auto";
      tree = "eza --tree --icons";
      cd = "z"; # zoxide
      gs = "git status";
      vi = "nvim";
      vim = "nvim";
      neovim = "nvim";
      # Rebuild shortcut
      nfu = "cd ~/nixos && nix flake update --commit-lock-file";
      nrs = "nh os switch $HOME/nixos#$hostname";
      nrt = "nh os test $HOME/nixos#$hostname";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;

      format = builtins.concatStringsSep "" [
        "$username"
        "[](fg:#42be65 bg:#3ddbd9)"
        "$directory"
        "[](fg:#3ddbd9 bg:#78a9ff)"
        "$git_branch"
        "$git_status"
        "[](fg:#78a9ff bg:#be95ff)"
        "$c"
        "$cpp"
        "$fennel"
        "$golang"
        "$java"
        "$julia"
        "$lua"
        "$nodejs"
        "$python"
        "$rlang"
        "$rust"
        "$typst"
        "$zig"
        "[](fg:#be95ff)"
        "$line_break"
        "$character"
      ];

      username = {
        show_always = true;
        style_user = "fg:#161616 bg:#42be65";
        style_root = "fg:#161616 bg:#ee5396";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:#161616 bg:#3ddbd9";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "fg:#161616 bg:#78a9ff";
        format = "[ $symbol$branch ]($style)";
      };

      git_status = {
        style = "fg:#161616 bg:#78a9ff";
        format = "[$all_status$ahead_behind]($style)";
      };

      c = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      cpp = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      fennel = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      golang = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      java = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      julia = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      lua = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      nodejs = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      python = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      rlang = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      rust = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      typst = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };
      zig = {
        style = "fg:#161616 bg:#be95ff";
        format = "[ $symbol ]($style)";
      };

      character = {
        success_symbol = "[➜](bold #33b1ff)";
        error_symbol = "[➜](bold #ee5396)";
        vimcmd_symbol = "[➜](bold #be95ff)";
      };
    };
  };
}
