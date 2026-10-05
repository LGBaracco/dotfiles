# Ubuntu work machine: standalone Home Manager (not NixOS). Minimal: Neovim only.
{ ... }:
{
  home.username = "lbaracco";
  home.homeDirectory = "/home/lbaracco";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Neovim via nix-wrapper-modules (liveLua=true by default: ~/.config/nvim via stow)
  wrappers.neovim.enable = true;
}
