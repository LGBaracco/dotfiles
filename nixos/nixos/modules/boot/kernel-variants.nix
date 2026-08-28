{ pkgs, lib, ... }: {
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

  specialisation.Cachy = {
    configuration = {
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-latest;
    };
  };
}
