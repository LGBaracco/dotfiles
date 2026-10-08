# Ubuntu work machine: standalone Home Manager (not NixOS). Minimal: Neovim only.
{ ... }:
{
  home.username = "lbaracco";
  home.homeDirectory = "/home/lbaracco";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Neovim via nix-wrapper-modules (liveLua=true by default: ~/.config/nvim via stow)
  wrappers.neovim.enable = true;

  # Outside Nix (install manually). The wrapper already carries LSPs, formatters,
  # quarto, jupytext, texliveFull, zathura and wl-clipboard (module.nix).
  #   apt:      git curl python3 (+ kitty if not using Ghostty)
  #   upstream: uv (curl -LsSf https://astral.sh/uv/install.sh | sh)
  #             JetBrainsMono Nerd Font -> ~/.local/share/fonts, then fc-cache -f
  #             Ghostty (optional)
  #   uv tools: uv tool install ruff
  #             uv tool install ty
  #             uv tool install ipython
  #             uv tool install debugpy   # DAP fallback outside uv projects
  #             Molten host (pynvim): command in lua/plugins/repl/quarto.lua
  #   other:    stow neovim (~/.config/nvim); tmux needs allow-passthrough on
}
