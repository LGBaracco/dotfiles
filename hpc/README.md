# HPC Neovim (Apptainer)

Full Neovim + tmux + Quarto/Molten stack for FZ Jülich clusters, built from Nix
locally and run as an Apptainer SIF under `$PROJECT` (no Nix on the cluster).

Local Neovim over SSHFS is fine for one-off file tweaks; it is **not** VS Code
Remote (Neovim has no UI/extension-host split). For real cluster work, run the
editor on the remote inside this image.

## Layout on the cluster

```
$PROJECT/hpc-env/          # or $HPC_ENV
  nvim-hpc.sif             # symlink → versioned .sif
  config/nvim/             # stowed Lua (live; no image rebuild)
  config/tmux/
  uv-tools/                # UV_TOOL_DIR (pynvim, ruff, ty, …)
  bin/jp-nvim
  bin/jp-tmux
```

Caches prefer `$SCRATCH` when set (`XDG_CACHE_HOME`, `UV_CACHE_DIR`).

## What is trimmed vs desktop

See [`module-hpc.nix`](../neovim/.config/nvim/module-hpc.nix): curated treesitter
grammars; no qmlls/fish-lsp/docker-ls/jdt/nil/nixfmt; no `texliveFull` (use a
site TeX module to compile). Quarto, Molten, jupytext, ImageMagick, julia-bin,
clangd, and the literate plugin set stay.

## Ghostty + tmux graphics

Use Ghostty → SSH → **`jp-tmux`** (tmux **inside** the image) → `nvim`.

Your tmux config already enables Kitty graphics passthrough:

- `allow-passthrough on`
- `focus-events on`

That is required for snacks.image / Molten plots over SSH. Do not nest a second
tmux on the host around `jp-nvim` unless you also enable passthrough there.

## Pipeline

| You changed | Run (on your laptop) |
|-------------|----------------------|
| Lua / tmux.conf | `HPC_HOST=… ./hpc/sync.sh config` |
| `module-hpc.nix` / flake.lock / tools in image | `HPC_HOST=… ./hpc/sync.sh image` |
| ruff / ty / pynvim / debugpy versions | `HPC_HOST=… ./hpc/sync.sh tools` |
| Everything | `HPC_HOST=… ./hpc/sync.sh all` |

```bash
export HPC_HOST=juwels   # your SSH Host alias
# On the cluster, PROJECT (and ideally SCRATCH) must be set in the login env.

./hpc/sync.sh config     # seconds
./hpc/sync.sh image      # nix build + SIF + rsync (minutes)
./hpc/sync.sh tools      # uv tool install inside the SIF
```

If Apptainer is not installed locally, `image` rsyncs the docker-archive and
builds the SIF on the cluster (`module load Apptainer` / `apptainer` / `Singularity`).

Build only (no sync):

```bash
cd hpc
nix build .#hpc-devbox-oci   # ~2GB docker-archive (.tar.gz); Quarto pulls R/JDK
nix build .#neovim-hpc
nix build .#hpc-devbox
```

The OCI is large because Quarto’s closure includes R and related tooling. That is
expected for the full literate stack; Lua-only updates never rebuild it.
## Day-to-day on a login node

```bash
module load Apptainer    # name varies by system
export PATH="$PROJECT/hpc-env/bin:$PATH"

jp-tmux                  # tmux new -A -s main inside the SIF
# inside tmux:
nvim                     # image PATH already has nvim
```

GPU kernels: `HPC_NV=1 jp-tmux` (passes `--nv`).

Molten’s Python host should be the project uv tool:

`$PROJECT/hpc-env/uv-tools/pynvim/bin/python`

`jp-nvim` sets `NVIM_PYTHON3_HOST_PROG` when that binary exists; your Lua also
resolves the usual uv tools path under `XDG` / home — keep tools under
`$HPC_ENV/uv-tools` so `$HOME` quota stays small.

## Bind mounts

Wrappers set `APPTAINER_BINDPATH` to `$HOME`, `$PROJECT`, `$SCRATCH`, `$WORK`
(when they exist) plus `$HPC_ENV`. Add more with:

```bash
export APPTAINER_BINDPATH="$APPTAINER_BINDPATH,/path/to/extra"
```

Site MPI/CUDA modules are for **job scripts** on the host. The editor image
carries its own clangd/uv/julia; do not expect host `module load` compilers
inside `--cleanenv` unless you bind and extend PATH yourself.

## SSH tip

Keep a Host entry that loads your environment (so `PROJECT` is set for rsync
targets):

```
Host juwels
  HostName juwels-*.fz-juelich.de
  User YOUR_ID
  ForwardAgent no
```

Exact hostnames differ by system (JUWELS, JURECA, JUSUF, …).
