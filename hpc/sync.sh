#!/usr/bin/env bash
# hpc-sync — push local Neovim/tmux updates into $PROJECT/hpc-env on the cluster.
#
# Usage:
#   hpc-sync config              # lua + tmux.conf (fast)
#   hpc-sync image               # rebuild OCI → SIF, rsync image (slow)
#   hpc-sync tools               # uv tool install inside remote image
#   hpc-sync all                 # config + image + tools
#   hpc-sync wrappers            # only jp-nvim / jp-tmux
#
# Env:
#   HPC_HOST      SSH host (required for remote sync), e.g. juwels
#   HPC_ENV       Remote env root (default: \$PROJECT/hpc-env — expanded on remote)
#   HPC_ENV_LOCAL Local build/staging dir (default: ./build under this repo's hpc/)
#   HPC_NV        unused here; set on cluster when exec'ing with GPU
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$ROOT/.." && pwd)"
HPC_ENV_LOCAL="${HPC_ENV_LOCAL:-$ROOT/build}"

die() { echo "hpc-sync: $*" >&2; exit 1; }

need_host() {
  [[ -n "${HPC_HOST:-}" ]] || die "set HPC_HOST (SSH destination, e.g. export HPC_HOST=juwels)"
}

remote() {
  need_host
  # shellcheck disable=SC2029
  ssh "$HPC_HOST" "$@"
}

remote_env() {
  # Expand on the remote (PROJECT / HPC_ENV from login env).
  remote 'bash -lc "echo \"\${HPC_ENV:-\$PROJECT/hpc-env}\""'
}

rsync_to() {
  need_host
  local src="$1" dest="$2"
  rsync -a --info=progress2 "$src" "$HPC_HOST:$dest"
}

cmd_wrappers() {
  need_host
  local dest
  dest="$(remote_env)"
  [[ -n "$dest" ]] || die "remote HPC_ENV empty; export PROJECT (or HPC_ENV) on $HPC_HOST"
  remote "bash -lc 'mkdir -p \"$dest/bin\"'"
  rsync_to "$ROOT/wrappers/jp-nvim" "$dest/bin/jp-nvim"
  rsync_to "$ROOT/wrappers/jp-tmux" "$dest/bin/jp-tmux"
  remote "bash -lc 'chmod +x \"$dest/bin/jp-nvim\" \"$dest/bin/jp-tmux\"'"
  echo "wrappers → $dest/bin (add to PATH)"
}

cmd_config() {
  need_host
  local dest
  dest="$(remote_env)"
  [[ -n "$dest" ]] || die "remote HPC_ENV empty; export PROJECT (or HPC_ENV) on $HPC_HOST"
  remote "bash -lc 'mkdir -p \"$dest/config/nvim\" \"$dest/config/tmux\"'"

  rsync -a --delete --info=progress2 \
    --exclude flake.lock \
    --exclude .git \
    --exclude '*.md' \
    "$DOTFILES/neovim/.config/nvim/" \
    "$HPC_HOST:$dest/config/nvim/"

  rsync -a --delete --info=progress2 \
    "$DOTFILES/tmux/.config/tmux/" \
    "$HPC_HOST:$dest/config/tmux/"

  cmd_wrappers
  echo "config → $dest/config"
}

cmd_image() {
  need_host
  local dest stamp sif_local oci tar
  dest="$(remote_env)"
  [[ -n "$dest" ]] || die "remote HPC_ENV empty; export PROJECT (or HPC_ENV) on $HPC_HOST"
  mkdir -p "$HPC_ENV_LOCAL"
  stamp="$(date +%Y%m%d-%H%M%S)"
  sif_local="$HPC_ENV_LOCAL/nvim-hpc-$stamp.sif"

  echo "Building OCI image (nix)…"
  oci="$(nix build --no-link --print-out-paths "$ROOT#hpc-devbox-oci")"
  if [[ -f "$oci" ]]; then
    tar="$oci"
  else
    tar="$(find "$oci" -maxdepth 1 \( -name '*.tar' -o -name '*.tar.gz' -o -name 'image.tar*' \) | head -1 || true)"
    [[ -n "$tar" ]] || die "no docker-archive under $oci"
  fi
  echo "OCI archive: $tar"

  if command -v apptainer >/dev/null 2>&1; then
    echo "Converting with local apptainer…"
    apptainer build --force "$sif_local" "docker-archive:$tar"
  elif command -v singularity >/dev/null 2>&1; then
    echo "Converting with local singularity…"
    singularity build --force "$sif_local" "docker-archive:$tar"
  else
    echo "No local apptainer; staging archive for remote conversion…"
    local remote_tar="$dest/nvim-hpc-$stamp.tar.gz"
    if [[ "$tar" == *.gz ]]; then
      rsync_to "$tar" "$remote_tar"
    else
      gzip -c "$tar" >"$HPC_ENV_LOCAL/nvim-hpc-$stamp.tar.gz"
      rsync_to "$HPC_ENV_LOCAL/nvim-hpc-$stamp.tar.gz" "$remote_tar"
    fi
    remote "bash -lc '
      set -euo pipefail
      dest=\"$dest\"
      module load Apptainer 2>/dev/null || module load apptainer 2>/dev/null || module load Singularity 2>/dev/null || true
      cd \"\$dest\"
      apptainer build --force \"nvim-hpc-$stamp.sif\" \"docker-archive:nvim-hpc-$stamp.tar.gz\" \
        || singularity build --force \"nvim-hpc-$stamp.sif\" \"docker-archive:nvim-hpc-$stamp.tar.gz\"
      ln -sfn \"nvim-hpc-$stamp.sif\" nvim-hpc.sif
      rm -f \"nvim-hpc-$stamp.tar.gz\"
    '"
    cmd_wrappers
    echo "image → $dest/nvim-hpc.sif (built on remote)"
    return 0
  fi

  remote "bash -lc 'mkdir -p \"$dest\"'"
  rsync_to "$sif_local" "$dest/nvim-hpc-$stamp.sif"
  remote "bash -lc 'ln -sfn \"nvim-hpc-$stamp.sif\" \"$dest/nvim-hpc.sif\"'"
  cmd_wrappers
  echo "image → $dest/nvim-hpc.sif"
}

cmd_tools() {
  need_host
  local dest
  dest="$(remote_env)"
  [[ -n "$dest" ]] || die "remote HPC_ENV empty; export PROJECT (or HPC_ENV) on $HPC_HOST"
  remote "bash -lc '
    set -euo pipefail
    dest=\"$dest\"
    export HPC_ENV=\"\$dest\"
    export PROJECT=\"\${PROJECT:-}\"
    export SCRATCH=\"\${SCRATCH:-}\"
    export UV_TOOL_DIR=\"\$dest/uv-tools\"
    export UV_CACHE_DIR=\"\${SCRATCH:-\$dest}/uv-cache\"
    export UV_TOOL_BIN_DIR=\"\$dest/uv-tools/bin\"
    mkdir -p \"\$UV_TOOL_DIR\" \"\$UV_CACHE_DIR\" \"\$UV_TOOL_BIN_DIR\"
    module load Apptainer 2>/dev/null || module load apptainer 2>/dev/null || module load Singularity 2>/dev/null || true
    SIF=\"\$dest/nvim-hpc.sif\"
    test -f \"\$SIF\" || { echo \"missing \$SIF — run hpc-sync image first\" >&2; exit 1; }
    BINDPATH=\"\${HOME},\${PROJECT},\${SCRATCH},\$dest\"
    export APPTAINER_BINDPATH=\"\$BINDPATH\"
    export SINGULARITY_BINDPATH=\"\$BINDPATH\"
    run() {
      if command -v apptainer >/dev/null; then
        apptainer exec --cleanenv \
          --env \"PATH=/bin\" \
          --env \"UV_TOOL_DIR=\$UV_TOOL_DIR\" \
          --env \"UV_CACHE_DIR=\$UV_CACHE_DIR\" \
          --env \"UV_TOOL_BIN_DIR=\$UV_TOOL_BIN_DIR\" \
          --env \"SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt\" \
          --env \"HOME=\${HOME}\" \
          \"\$SIF\" \"\$@\"
      else
        singularity exec --cleanenv \
          --env \"PATH=/bin\" \
          --env \"UV_TOOL_DIR=\$UV_TOOL_DIR\" \
          --env \"UV_CACHE_DIR=\$UV_CACHE_DIR\" \
          --env \"UV_TOOL_BIN_DIR=\$UV_TOOL_BIN_DIR\" \
          --env \"SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt\" \
          --env \"HOME=\${HOME}\" \
          \"\$SIF\" \"\$@\"
      fi
    }
    echo 'uv tool install pynvim (Molten host + plot deps)'
    run uv tool install --force --python 3.12 \
      --with jupyter_client --with pillow --with cairosvg --with nbformat \
      --with plotly --with kaleido --with pnglatex --with pyperclip \
      --with requests --with websocket-client \
      pynvim
    for pkg in ruff ty debugpy ipython jupyter; do
      echo \"uv tool install \$pkg\"
      run uv tool install --force \"\$pkg\"
    done
    echo \"uv tools → \$UV_TOOL_DIR\"
  '"
}

cmd_all() {
  cmd_config
  cmd_image
  cmd_tools
}

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \?//'
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    config) cmd_config "$@" ;;
    image) cmd_image "$@" ;;
    tools) cmd_tools "$@" ;;
    wrappers) cmd_wrappers "$@" ;;
    all) cmd_all "$@" ;;
    -h | --help | help | "") usage ;;
    *) die "unknown command: $cmd (try: config|image|tools|wrappers|all)" ;;
  esac
}

main "$@"
