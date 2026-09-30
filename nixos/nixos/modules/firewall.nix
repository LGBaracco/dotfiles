{ ... }:
{
  networking.firewall.enable = true;

  # SSH / SCP. Password auth left on until an authorizedKeys entry exists
  # (none on this machine yet); switch to key-only after adding a pubkey.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # Phone pairing (opens TCP/UDP 1714–1764)
  programs.kdeconnect.enable = true;

  # Nearby file transfer (package + TCP/UDP 53317)
  programs.localsend.enable = true;

  # Printer / mDNS discovery (UDP 5353)
  services.avahi.openFirewall = true;
}
