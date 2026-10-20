{
  flake.modules.homeManager.lorenzo =
    { ... }: {
      # Let Home Manager manage itself
      programs.home-manager.enable = true;

      home.sessionPath = [
        "$HOME/.config/emacs/bin" # Doom emacs
        "$HOME/.local/bin"
      ];

      # ── Environment variables ────────────────────────────────────────────────
      #home.sessionVariables = {
      #};

    };
}
