{
  flake.modules.nixos.common =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # ── networking ────────────────────────────────────────────────────────────
      networking = {
        # L2TP/IPsec VPNs break with strict reverse-path filtering
        firewall.checkReversePath = "loose";
        networkmanager = {
          enable = true;
          # FZJ L2TP-over-IPsec (TKI-0387); profiles show up in Dux Shell → VPN
          plugins = with pkgs; [ networkmanager-l2tp ];
        };
      };

      # strongSwan 6 builds without IKEv1, which L2TP/IPsec needs. Overlay so
      # networkmanager-l2tp (which hardcodes its strongswan path) gets it too.
      nixpkgs.overlays = [
        (_final: prev: {
          strongswan = prev.strongswan.overrideAttrs (old: {
            configureFlags = old.configureFlags ++ [ "--enable-ikev1" ];
          });
        })
      ];

      # SSH client defaults (/etc/ssh/ssh_config; ~/.ssh/config still wins).
      # FZJ hosts by short name:
      #   `ssh medpc057`             → lbaracco@medpc057.ime.kfa-juelich.de
      #   `ssh jureca`/`ssh jrlogin01` → baracco1@<name>.fz-juelich.de
      # The VPN pushes no DNS search domain (and Tailscale owns resolv.conf),
      # so short names don't resolve. `!*.*` leaves full hostnames and IPs
      # untouched. IPv4 by default; `ssh -6` still forces IPv6 (CLI wins).
      programs.ssh.extraConfig = ''
        Host medpc* !*.*
          HostName %h.ime.kfa-juelich.de
          User lbaracco

        Host j* !*.*
          HostName %h.fz-juelich.de
          User baracco1

        Host *
          AddressFamily inet
      '';

      services.strongswan = {
        enable = true;
        secrets = [ "ipsec.d/ipsec.nm-l2tp.secrets" ];
      };
      # NM and strongswan modules both set this; force the nm-l2tp include.
      environment.etc."ipsec.secrets".text = lib.mkForce ''
        include ipsec.d/ipsec.nm-l2tp.secrets
      '';
      # nm-l2tp starts its own charon without STRONGSWAN_CONF; strongSwan 6
      # aborts ("integrity test of libstrongswan failed") if this is missing.
      environment.etc."strongswan.conf".text = ''
        charon {
          plugins {
            include /etc/strongswan.d/charon/*.conf
          }
        }
      '';
      # unity plugin breaks L2TP transport-mode (nm-l2tp known issue)
      environment.etc."strongswan.d/charon/unity.conf".text = ''
        unity {
          load = no
        }
      '';
      systemd.tmpfiles.rules = [
        "d /etc/ipsec.d 0755 root root -"
      ];
    };
}
