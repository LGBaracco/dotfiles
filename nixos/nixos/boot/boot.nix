{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader = {
    limine = {
      enable = true;
      efiSupport = true;
      maxGenerations = 20;
      style = {
        interface.helpHidden = true;
        graphicalTerminal.palette = "232136;eb6f92;9ccfd8;f6c177;3e8fb0;c4a7e7;9ccfd8;e0def4";
        graphicalTerminal.brightPalette = "6e6a86;eb6f92;9ccfd8;f6c177;3e8fb0;c4a7e7;9ccfd8;e0def4";
        graphicalTerminal.background = "232136";
        graphicalTerminal.brightBackground = "6e6a86";
        graphicalTerminal.foreground = "e0def4";
        graphicalTerminal.brightForeground = "e0def4";
        wallpapers = [];
      };
      };
    efi.canTouchEfiVariables = true;
  };

   # Appends CachyOS entries from its own limine.conf
   system.activationScripts.patchLimineCachy = {
    supportsDryActivation = true;
    text = ''
        TARGET_CONF="/boot/limine/limine.conf"
        CACHY_CONF="/boot/limine.conf"

        if [ -f "$TARGET_CONF" ] && [ -f "$CACHY_CONF" ]; then
        # Check for your loop-prevention marker
        if ! grep -q "### CACHYOS_ENTRIES_START ###" "$TARGET_CONF"; then
            echo "Injecting CachyOS boot profiles synchronously..."
            echo -e "\n### CACHYOS_ENTRIES_START ###" >> "$TARGET_CONF"
            cat "$CACHY_CONF" >> "$TARGET_CONF"
            echo "### CACHYOS_ENTRIES_END ###" >> "$TARGET_CONF"
        fi
        fi
    '';
    };

  # Enable numlock early on boot
  boot.initrd.systemd = {
    storePaths = [
      "${pkgs.kbd}/bin/setleds"
    ];
    services.numlockon = {
      description = "Enable NumLock at startup";
      wantedBy = [ "initrd.target" ];
      before = [ "initrd-root-device.target" ];
      unitConfig = {
        DefaultDependencies = false;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.kbd}/bin/setleds -D +num";
        StandardInput = "tty";
        TTYPath = "/dev/tty0";
      };
    };
  };
}
