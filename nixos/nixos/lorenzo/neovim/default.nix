# Neovim is configured under ~/dotfiles/neovim (lua + nix-wrapper-modules).
# Enable the wrapper module imported from the neovim flake.
{
  wrappers.neovim.enable = true;
}
