{
  flake.modules.nixos.common =
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
        sshfs
        #networkmanagerapplet
      ];

    };

  flake.modules.nixos.workstation =
    {
      pkgs,
      ...
    }:

    {
      # ── System-wide packages ─────────────────────────────────────────────────
      environment.systemPackages = with pkgs; [
        gcc
        gparted
        kdePackages.partitionmanager
      ];

    };
}
