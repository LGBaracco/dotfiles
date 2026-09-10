# Dotfiles

NixOS-based personal dotfiles.

## Layout

| Directory              | Description                                                                                                                                                                                     |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **nixos/**             | Main part of the repo: a flake-based, full NixOS configuration. Host-agnostic setup with two flakes for two hosts (`nixdesktop`, `nixlaptop`) that share common modules and home configuration. |
| **niri/**              | Config for [niri](https://github.com/YaLTeR/niri), my Wayland compositor of choice.                                                                                                             |
| **mango/**             | Config for [mango](https://github.com/mangowm/mango) (mangowc), a dwl-based Wayland compositor selectable alongside niri in the DMS greeter.                                                    |
| **noctalia/**          | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) shell config used with niri.                                                                                                         |
| **DankMaterialShell/** | [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) shell config used with niri/mango.                                                                                        |
| **julia/**             | Simple Julia startup script enabling [Revise](https://github.com/timholy/Revise.jl) and [OhMyREPL](https://github.com/KristofferC/OhMyREPL.jl).                                                 |
| **[onedrive-sync/](onedrive-sync/README.md)** | Dotfiles to make OneDrive work seamlessly on Linux over WebDAV. Auth tokens are fetched from Firefox; a few bash scripts handle sync. See the [usage guide](onedrive-sync/README.md). |
| **neovim/**             | Stowable Neovim config flake ([nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules)): lua + `module.nix` under `.config/nvim` (`stow neovim` → `~/.config/nvim`). NixOS takes it as the `nvim-config` input and installs via `getInstallModule`. `wrappers.neovim.liveLua` (default `true`) loads Lua from `~/.config/nvim` without rebuilds; set `liveLua = false` to bake the tree into the store. |
| **emacs/**             | My Doom Emacs configuration, setup for python, julia, and nix development.                                                                                                                      |
| **bin/**               | Shell scripts, includes onedrive-sync commands.                                                                                                                                                 |
