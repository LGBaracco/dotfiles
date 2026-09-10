{
  pkgs,
  ...
}:

let
  # enable Vulkan GPU rendering.
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
    pciutils # lspci
    usbutils
    efibootmgr
    gcc
    gparted
    pycharm
    kdePackages.partitionmanager
  ];

}
