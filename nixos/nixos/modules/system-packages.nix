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
    kdePackages.partitionmanager # system profile so kpmcore polkit/dbus are registered
    gparted # system profile so org.gnome.gparted polkit (allow_gui) is registered
    # system profile: avoids HM activation flakiness; binary pkg (Community discontinued)
    jetbrains.pycharm
  ];

}
