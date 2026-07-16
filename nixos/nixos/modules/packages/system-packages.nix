{
  pkgs,
  ...
}:

{
  # ── System-wide packages ───────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    coreutils
    pciutils # lspci — useful for GPU debugging
    usbutils
    nvtopPackages.full # GPU monitor
    htop
    btop
    dgop
    efibootmgr
    gcc
    xwayland-satellite
    #partition-manager # TODO upcoming experiment!
    # libgcc ???
    uv # TODO check if it can be pushed back in hm
  ];
  programs.partition-manager.enable = true;
}
