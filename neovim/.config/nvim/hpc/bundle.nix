{
  lib,
  runCommand,
  fetchurl,
  binutils,
  pkgsStatic,
  neovim-unwrapped,
  nvim-hpc, # wrapped module-hpc.nix: provides nvim-packdir
  configSrc, # neovim/.config/nvim (flake input nvim-config)
}:
# Self-contained HPC (JSC) Neovim: official nvim + Quarto releases, the Nix-built
# plugin pack, the Lua config and static CLI tools in one nvim-hpc.tar.gz.
# Layout and launcher: hpc/nvim. Built and pushed by neovim/scripts/nvim-hpc-sync.
let
  # Official release binaries (no /nix/store at runtime). The plugin pack is built
  # against nixpkgs neovim, so only patch-level drift is allowed; on a minor bump,
  # update version + hash: nix store prefetch-file <url>
  nvimRelease = {
    version = "0.12.6";
    hash = "sha256-R0Qw1T5iZPbW3RjbQtbcnfOhtWyp6IoyW7+GDhqBHYc=";
  };
  quartoRelease = {
    version = "1.10.18";
    hash = "sha256-r60HG1vSLALy0wBpV0MYnTZQ4FN6Uwc+ZUtjDP8rDHM=";
  };

  # Rocky 9 (glibc 2.34, GCC 11 libstdc++); the nvim release itself needs 2.34.
  maxGlibc = "2.34";
  maxGlibcxx = "3.4.29";

  nvimTarball = fetchurl {
    url = "https://github.com/neovim/neovim/releases/download/v${nvimRelease.version}/nvim-linux-x86_64.tar.gz";
    inherit (nvimRelease) hash;
  };
  quartoTarball = fetchurl {
    url = "https://github.com/quarto-dev/quarto-cli/releases/download/v${quartoRelease.version}/quarto-${quartoRelease.version}-linux-amd64.tar.gz";
    inherit (quartoRelease) hash;
  };

  tools = with pkgsStatic; [
    ripgrep
    fd
    stylua
    shfmt
    taplo
  ];
in
assert lib.assertMsg
  (lib.versions.majorMinor nvimRelease.version == lib.versions.majorMinor neovim-unwrapped.version)
  "hpc/bundle.nix: nixpkgs neovim is ${neovim-unwrapped.version}, the pinned release ${nvimRelease.version}; bump nvimRelease";
runCommand "nvim-hpc-bundle-${nvimRelease.version}"
  {
    nativeBuildInputs = [ binutils ];
  }
  ''
    root=$PWD/nvim-hpc
    app=$root/app
    mkdir -p $root/bin $app/site/pack/hpc $app/lua/share $app/lua/lib $app/tools/bin

    tar -xzf ${nvimTarball} -C $app && mv $app/nvim-linux-x86_64 $app/nvim
    tar -xzf ${quartoTarball} -C $app && mv $app/quarto-${quartoRelease.version} $app/quarto

    # Plugins + collated treesitter parsers, dereferenced out of the store
    cp -rL --no-preserve=ownership ${nvim-hpc}/nvim-packdir/pack/myNeovimPackages/. $app/site/pack/hpc/
    chmod -R u+w $app/site
    rm -rf $app/site/pack/hpc/start/nix-info
    find $app/site -name nix-support -prune -exec rm -rf {} +

    # Lua rocks the wrapper puts on LUA_PATH/LUA_CPATH (symlinkScript.nix: _addToLuaPath)
    source ${neovim-unwrapped.lua}/nix-support/utils.sh
    LUA_PATH= LUA_CPATH=
    _addToLuaPath ${nvim-hpc}/nvim-packdir
    for d in $(printf '%s;%s' "$LUA_PATH" "$LUA_CPATH" | tr ';' '\n' | sed -n 's#/\(share\|lib\)/lua/5\.1/.*##p' | sort -u); do
      case $d in ${neovim-unwrapped.lua} | ${nvim-hpc}/*) continue ;; esac
      if [ -d $d/share/lua/5.1 ]; then cp -rL --no-preserve=ownership $d/share/lua/5.1/. $app/lua/share/; fi
      if [ -d $d/lib/lua/5.1 ]; then cp -rL --no-preserve=ownership $d/lib/lua/5.1/. $app/lua/lib/; fi
      chmod -R u+w $app/lua
    done

    # Lua config snapshot, without the Nix side
    mkdir -p $app/config
    cp -r --no-preserve=ownership ${configSrc}/. $app/config/
    chmod -R u+w $app/config
    rm -rf $app/config/hpc $app/config/*.nix $app/config/flake.lock

    for t in ${lib.concatMapStringsSep " " (t: "${lib.getBin t}/bin/*") tools}; do
      cp -L $t $app/tools/bin/
    done

    cp ${./bootstrap.lua} $app/bootstrap.lua
    cp ${./nvim} $root/bin/nvim
    chmod -R u+w $root
    chmod 755 $root/bin/nvim
    printf 'nvim %s\nquarto %s\nconfig %s\n' \
      ${nvimRelease.version} ${quartoRelease.version} ${baseNameOf configSrc} > $app/VERSION

    # --- Checks: nothing may depend on /nix/store or a glibc newer than the cluster's
    fail=0
    # Real store paths (hash-prefixed); first-line shebangs of dev scripts are never run
    refs=$(grep -rnIE --include='*.lua' --include='*.vim' '/nix/store/[0-9a-z]{32}-' $app/site $app/lua $app/config \
      | grep -vE '^[^:]+:1:#!' || true)
    if [ -n "$refs" ]; then
      echo "runtime files reference /nix/store:"; echo "$refs"; fail=1
    fi

    newer() { [ -n "$1" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" != "$2" ]; }
    while IFS= read -r -d "" f; do
      [ "$(head -c 4 "$f")" = "$(printf '\177ELF')" ] || continue
      syms=$(objdump -T "$f" 2>/dev/null || true)
      g=$( (grep -o 'GLIBC_[0-9.]*' <<<"$syms" || true) | sed 's/^GLIBC_//' | sort -V | tail -1)
      x=$( (grep -o 'GLIBCXX_[0-9.]*' <<<"$syms" || true) | sed 's/^GLIBCXX_//' | sort -V | tail -1)
      if newer "$g" ${maxGlibc} || newer "$x" ${maxGlibcxx}; then
        echo "too new for the cluster (GLIBC_$g GLIBCXX_$x): ''${f#$root/}"; fail=1
      fi
    done < <(find $app/site $app/lua $app/nvim $app/quarto -type f -print0)

    for f in $app/tools/bin/*; do
      if readelf -l "$f" 2>/dev/null | grep -q 'program interpreter'; then
        echo "not static: ''${f#$root/}"; fail=1
      fi
    done
    [ $fail = 0 ] || exit 1

    mkdir -p $out
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@1 -C $PWD -cf - nvim-hpc \
      | gzip -n -6 --rsyncable > $out/nvim-hpc.tar.gz
    cp $app/VERSION $out/VERSION
  ''
