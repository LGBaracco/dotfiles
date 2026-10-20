{
  flake.modules.nixos.common =
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
      # No global cudaSupport: it forces source builds (e.g. zotero -> firefox-esr ->
      # onnxruntime). Opt in per package instead (btop-cuda, ollama-cuda, ...).
      # uv/PyPI CUDA wheels only need the driver libs, provided via nix-ld.
    };
}
