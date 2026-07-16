{
  config,
  pkgs,
  inputs,
  lib,
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

  # These are probably useless
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  boot.blacklistedKernelModules = [ "nouveau i915 amdgpu" ];
}
