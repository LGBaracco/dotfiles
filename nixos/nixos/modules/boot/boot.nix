{ pkgs, ... }: {
  # ── Boot ──────────────────────────────────────────────────────────────────
  boot = {
    loader = {
      limine = {
        enable = true;
        efiSupport = true;
        maxGenerations = 10;
        style = {
          # Catpuccin palette, maybe will change one day
          interface.helpHidden = true;
          graphicalTerminal.palette = "232136;eb6f92;9ccfd8;f6c177;3e8fb0;c4a7e7;9ccfd8;e0def4";
          graphicalTerminal.brightPalette = "6e6a86;eb6f92;9ccfd8;f6c177;3e8fb0;c4a7e7;9ccfd8;e0def4";
          graphicalTerminal.background = "232136";
          graphicalTerminal.brightBackground = "6e6a86";
          graphicalTerminal.foreground = "e0def4";
          graphicalTerminal.brightForeground = "e0def4";
          wallpapers = [ ];
        };
      };
      efi.canTouchEfiVariables = true;
    };

    plymouth.enable = true;
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];
    # # Enable numlock early on boot
    initrd.systemd = {
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
  };
}
