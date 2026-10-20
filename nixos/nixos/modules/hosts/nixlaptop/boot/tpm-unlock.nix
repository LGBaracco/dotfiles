{
  flake.modules.nixos.nixlaptop =
    { ... }: {
      # Unlock LUKS root with the TPM instead of a passphrase.
      # Enroll once with:
      #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/disk/by-uuid/e767dbdd-8a5f-41f8-8194-58996f962ef0
      # The passphrase stays as a fallback.
      security.tpm2.enable = true;
      boot.initrd.systemd.enable = true;
      boot.initrd.luks.devices."luks-e767dbdd-8a5f-41f8-8194-58996f962ef0".crypttabExtraOpts = [
        "tpm2-device=auto"
      ];
    };
}
