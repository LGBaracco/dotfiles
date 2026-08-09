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
    alsa-utils
    nvtopPackages.full # GPU monitor
    htop
    btop
    dgop
    efibootmgr
    gcc
    texliveMedium # For emacs' org mode

    stable.jetbrains.pycharm
  ];

  programs.partition-manager.enable = true;

}
