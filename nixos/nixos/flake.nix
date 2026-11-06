{
  description = "My NixOS configurations";

  # Base = stable; pkgs.unstable.<pkg> only where it pays off (policy: modules/overlays.nix).
  # Until 26.11 exists, nixpkgs is still unstable and nixpkgs-unstable follows it.
  #
  # 26.11 switch checklist:
  #   1. Both branches exist:
  #        git ls-remote https://github.com/NixOS/nixpkgs refs/heads/nixos-26.11
  #        git ls-remote https://github.com/nix-community/home-manager refs/heads/release-26.11
  #   2. nixpkgs.url          -> "github:NixOS/nixpkgs/nixos-26.11"
  #   3. nixpkgs-unstable     -> replace the follows with url = "github:NixOS/nixpkgs/nixos-unstable";
  #   4. home-manager.url     -> "github:nix-community/home-manager/release-26.11"
  #   5. Delete the nixpkgs-stable input and the `stable` overlay (modules/overlays.nix);
  #      stable.zotero -> zotero (modules/apps/home-packages.nix)
  #   6. nfu; nix build --no-link --print-out-paths .#nixosConfigurations.$hostname.config.system.build.toplevel;
  #      nvd diff /run/current-system <out>; nrt
  #   7. Check: greeter + niri login, Dux Shell bar/plugins, Plasma login (fallback), Cachy entry boots,
  #      L2TP VPN, `nix shell unstable#hello -c hello`,
  #      journalctl --user -u dms -b | grep -iE 'incompatible qt|cannot load|gbm|egl'   (expect nothing)
  #   8. nrs. If a Dux flake input (dms-plugin-registry, dms-sessionizer, dankcalendar) fails to
  #      evaluate against stable, switch its follows to "nixpkgs-unstable".
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.follows = "nixpkgs";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-config = {
      url = "path:../../neovim/.config/nvim";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-sessionizer = {
      url = "github:leonardofranco01/dms-sessionizer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # CachyOS kernels. Do not override nixpkgs — nyx cache is built against its own rev.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
