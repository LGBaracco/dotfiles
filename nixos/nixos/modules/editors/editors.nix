{
  flake.modules.homeManager.lorenzo =
    { pkgs, lib, ... }: {
      # Neovim via nix-wrapper-modules (liveLua=true by default: ~/.config/nvim via stow)
      wrappers.neovim = {
        enable = true;
        # Plugins, LSPs and tools from unstable, close to plugin HEAD like the non-Nix setup.
        # mkForce: the install module already sets pkgs, and a pkgs set can't be merged.
        pkgs = lib.mkForce pkgs.unstable;
        # liveLua = false;  # uncomment to force rebuild after lua edits
      };

      programs.emacs = {
        enable = true;
        package = pkgs.emacs-pgtk; # emacs30-pgtk
        #extraPackages = epkgs: [ epkgs.vterm ]; # currently using ghostel
      };
    };
}
