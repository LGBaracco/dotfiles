{
  flake.modules.homeManager.lorenzo =
    { pkgs, ... }: {
      # Neovim via nix-wrapper-modules (liveLua=true by default: ~/.config/nvim via stow)
      wrappers.neovim = {
        enable = true;
        # liveLua = false;  # uncomment to force rebuild after lua edits
      };

      programs.emacs = {
        enable = true;
        package = pkgs.emacs-pgtk; # emacs30-pgtk
        #extraPackages = epkgs: [ epkgs.vterm ]; # currently using ghostel
      };
    };
}
