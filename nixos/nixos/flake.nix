{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    # strongSwan 5.9.14 (IKEv1) for FZJ L2TP; current nixpkgs is 6.x without IKEv1
    nixpkgs-strongswan5.url = "github:NixOS/nixpkgs/nixos-24.11";

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
      url = "github:LGBaracco/dms-sessionizer";
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
