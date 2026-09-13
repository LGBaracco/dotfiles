{
  pkgs,
  ...
}:

{
  # ── System-wide packages ─────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    curl
    wget
    coreutils
    pciutils # lspci
    usbutils
    efibootmgr
    gcc
    gparted
    kdePackages.partitionmanager
  ];

}
