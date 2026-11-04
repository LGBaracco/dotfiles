{
  flake.modules.nixos.common =
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

      users.users.lorenzo.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8t0CH1IEEdEX/g8k+8NCz7p1Nc3NoEl7NfLmsPAnJN l.baracco@fz-juelich.de"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII6Q0+lLUKNLsrarxJqeXo4E03jZnVL417Fp495DCgGr u0_a529@localhost"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjKn1d+DMBiS4LwvX1BrIlqrNUbsqUS44HRiDT2x/gj l.baracco@fz-juelich.de"

      ];

      # Phone pairing (opens TCP/UDP 1714–1764)
      programs.kdeconnect.enable = true;

      # Nearby file transfer (package + TCP/UDP 53317)
      programs.localsend.enable = true;

      # Printer / mDNS discovery (UDP 5353)
      services.avahi.openFirewall = true;
    };
}
