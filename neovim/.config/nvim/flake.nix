{
  description = "Neovim config (nix-wrapper-modules module)";
  outputs = { self }: {
    homeModules.neovim = "${self}/module.nix";
  };
}
