{config, lib, pkgs, ...}: {
  # ── NVIDIA ────────────────────────────────────────────────────────────────
  hardware.nvidia = {
    powerManagement = {
      enable = true;
      finegrained = true; # RTD3 suspend for dGPU when idle
    };
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Hybrid Intel/NVIDIA via PRIME offload
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # `nvidia-offload` helper
      };
      # lspci
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
    };
  };

  # Nyx-cached driver built for the Cachy kernel (nixpkgs stable isn't cached for it)
  specialisation.Cachy.configuration.hardware.nvidia.package = lib.mkForce pkgs.nvidia_cachyos;
}
