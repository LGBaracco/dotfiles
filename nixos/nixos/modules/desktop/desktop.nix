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
        ];
        config.niri = {
          "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        };
        config.common.default = "*";
      };

      # ── audio ─────────────────────────────────────────────────────────────────
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };

      hardware.bluetooth.enable = true;

      # ── printing ──────────────────────────────────────────────────────────────
      services.avahi = {
        enable = true;
        nssmdns4 = true;
      };

      # ── misc ──────────────────────────────────────────────────────────────────
      programs.dconf.enable = true; # needed by some gtk apps under kde
      services.gvfs.enable = true; # needed for trash bin and partition mounts with nautilus outside of kde
      environment.systemPackages = [ pkgs.gtk3 ]; # gtk-launch: niri binds start apps via their .desktop entries
    };

  flake.modules.nixos.workstation =
    {
      pkgs,
      ...
    }:
    {
      # ── xdg portals ───────────────────────────────────────────────────────────
      xdg.portal = {
        extraPortals = with pkgs; [
          kdePackages.xdg-desktop-portal-kde
        ];
        config.mango = {
          "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
        };
      };

      # ── x11 ─────────────────────────────────────────────────────────
      services.xserver.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];

      # ── audio ─────────────────────────────────────────────────────────────────
      services.pipewire = {
        alsa.support32Bit = true;
        jack.enable = true;
      };

      # ── printing ──────────────────────────────────────────────────────────────
      services.printing.enable = true;
    };
}
