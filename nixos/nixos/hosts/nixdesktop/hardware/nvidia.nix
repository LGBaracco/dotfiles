{
  config,
  ...
}:

{
  # ── NVIDIA ────────────────────────────────────────────────────────────────
  hardware.nvidia = {
    powerManagement = {
      enable = false;
      finegrained = false;
    };
    open = false; # proprietary driver (better Wayland support currently)
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
  nixpkgs.config.cudaForwardCompat = true;
}
