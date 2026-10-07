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
| **neovim/**             | Stowable Neovim config ([nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules)): `flake.nix` + lua + `module.nix` under `.config/nvim` (`stow neovim` → `~/.config/nvim`). NixOS takes `neovim/.config/nvim` as the `nvim-config` input and installs via `getInstallModule`. `wrappers.neovim.liveLua` (default `true`) loads Lua from `~/.config/nvim` without rebuilds; set `liveLua = false` to bake the tree into the store. HPC profile: `module-hpc.nix`. |
| **[hpc/](hpc/README.md)** | Apptainer pipeline: Nix → OCI → SIF under `$PROJECT/hpc-env`, plus `sync.sh` / `jp-nvim` / `jp-tmux`. No Nix on the cluster. See the [HPC guide](hpc/README.md). |
| **emacs/**             | My Doom Emacs configuration, setup for python, julia, and nix development.                                                                                                                      |
| **claude/**            | The whole `~/.claude` folder (`stow claude` → `~/.claude` symlink). `.gitignore` whitelists config only (settings, agents, hooks, themes, `skills/ask`); credentials, transcripts and caches stay local. Includes a read-only **Ask mode**: run `ask` (fish alias) for `claude --agent ask`, with Bash restricted by `hooks/ask-readonly-bash.py`; or `/ask <question>` mid-session. |
| **fish/**              | Fish config (`stow fish` → `~/.config/fish/config.fish`): aliases, Oxocarbon colors, zoxide + starship init. Sources Home Manager's `hm-session-vars.sh` via `babelfish` when present, so it also works on non-NixOS hosts. |
| **starship/**          | [Starship](https://starship.rs) prompt (`stow starship` → `~/.config/starship.toml`): Oxocarbon powerline with OS icon, user, host, directory, git and language segments. |
| **ghostty/**           | [Ghostty](https://ghostty.org) config (`stow ghostty` → `~/.config/ghostty/config`). Oxocarbon theme; DMS-generated `themes/` stay untracked. |
| **bin/**               | Shell scripts, includes onedrive-sync commands.                                                                                                                                                 |
