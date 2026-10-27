# PLACEHOLDER so nixsurface evaluates before the install.
# Replace with the output of `nixos-generate-config --root /mnt --show-hardware-config`
# run on the Surface itself.
{ ... }:

{
  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
}
