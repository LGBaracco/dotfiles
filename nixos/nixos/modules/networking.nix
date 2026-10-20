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
      # FZJ L2TP-over-IPsec (TKI-0387); profiles show up in DMS → VPN
      # Overlay pins strongswan 5.9.14 (IKEv1); see overlays.nix
      plugins = with pkgs; [ networkmanager-l2tp ];
    };
  };

  services.strongswan = {
    enable = true;
    secrets = [ "ipsec.d/ipsec.nm-l2tp.secrets" ];
  };
  # NM and strongswan modules both set this; force the nm-l2tp include.
  environment.etc."ipsec.secrets".text = lib.mkForce ''
    include ipsec.d/ipsec.nm-l2tp.secrets
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
}
