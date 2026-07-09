{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  # ── NVIDIA ────────────────────────────────────────────────────────────────
  # Hybrid Intel/NVIDIA via PRIME offload (matches your envycontrol/PRIME setup)
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / 32-bit GL
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      finegrained = true; # RTD3 suspend for dGPU when idle
    };
    open = false; # proprietary driver (better Wayland support currently)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # gives you `nvidia-offload` helper
      };
      # Fill in your actual PCI bus IDs from: nixos-generate-config or lspci
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
    };
  };
}
