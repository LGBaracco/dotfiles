{
  pkgs,
  ...
}:

let
  # PyCharm 2026 WLToolkit software-renders by default → enable Vulkan GPU path.
  # (XToolkit looked worse on this machine; keep native Wayland.)
  pycharm =
    let
      base = pkgs.jetbrains.pycharm;
      vmopts = pkgs.runCommand "pycharm64.vmoptions" { } ''
        cat ${base}/pycharm/bin/pycharm64.vmoptions > $out
        echo '-Dsun.java2d.vulkan=true' >> $out
      '';
    in
    pkgs.symlinkJoin {
      name = "pycharm";
      paths = [ base ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/pycharm \
          --set-default PYCHARM_VM_OPTIONS ${vmopts}
      '';
    };
in
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
    pycharm
  ];

}
