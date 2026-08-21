{ ... }:

{
  # ── NVIDIA ────────────────────────────────────────────────────────────────
  # Hybrid Intel/NVIDIA via PRIME offload (matches your envycontrol/PRIME setup)
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / 32-bit GL
  };

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
  };
  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.config.cudaSupport = true;
}
