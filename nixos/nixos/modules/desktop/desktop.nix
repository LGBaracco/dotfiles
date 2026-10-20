{
  flake.modules.nixos.common =
    {
      pkgs,
      ...
    }:
    {
      # ── secrets / keyring ─────────────────────────────────────────────────────
      services.gnome.gnome-keyring.enable = true;
      security.pam.services.greetd.enableGnomeKeyring = true;

      security.polkit.enablePkexecWrapper = true;

      # ── xdg portals ───────────────────────────────────────────────────────────
      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gnome
          xdg-desktop-portal-gtk
          kdePackages.xdg-desktop-portal-kde
        ];
        config.niri = {
          "org.freedesktop.impl.portal.fileChooser" = [ "gnome" ];
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        };
        config.mango = {
          "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
        };
        config.common.default = "*";
      };

      # ── x11 ─────────────────────────────────────────────────────────
      services.xserver.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];

      # ── audio ─────────────────────────────────────────────────────────────────
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };

      hardware.bluetooth.enable = true;

      # ── printing ──────────────────────────────────────────────────────────────
      services.printing.enable = true;
      services.avahi = {
        enable = true;
        nssmdns4 = true;
      };

      # ── misc ──────────────────────────────────────────────────────────────────
      programs.dconf.enable = true; # needed by some gtk apps under kde
      services.gvfs.enable = true; # needed for trash bin and partition mounts with nautilus outside of kde
    };
}
