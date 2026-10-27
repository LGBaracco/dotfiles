{ inputs, ... }:
{
  flake.modules.nixos.nixsurface =
    { pkgs, ... }:
    {
      imports = [
        # linux-surface kernel (built from source, no binary cache: build on another host),
        # firmware and iio sensors. On the Surface 3 its surface3-spi patch turns off DMA,
        # without which touch/pen input crashes after the first touch.
        # Its kernelParams (mem_sleep_default=deep) are mkDefault and lose to boot.nix;
        # fine, the Surface 3 only does s2idle.
        inputs.nixos-hardware.nixosModules.microsoft-surface-common
        inputs.nixos-hardware.nixosModules.common-pc-ssd # fstrim
      ];

      # Cherry Trail (Gen8) GPU: VA-API through the i965 driver
      hardware.graphics.extraPackages = [ pkgs.intel-vaapi-driver ];

      # Marvell 88W8897 WiFi drops connections with power saving on
      networking.networkmanager.wifi.powersave = false;
    };
}
