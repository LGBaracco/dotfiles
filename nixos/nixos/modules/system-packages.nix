{
  pkgs,
  ...
}:

{
  # ── System-wide packages ───────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    curl
    wget
    coreutils
    pciutils # lspci — useful for GPU debugging
    usbutils
    efibootmgr
    gcc
  ];

  # kpmcore dbus/polkit backend for KDE Partition Manager (GUI in home.packages)
  services.dbus.packages = [ pkgs.kdePackages.partitionmanager.kpmcore ];

  services.flatpak.enable = true;
  services.flatpak.packages = [
    "com.jetbrains.PyCharm-Community"
  ];

}
