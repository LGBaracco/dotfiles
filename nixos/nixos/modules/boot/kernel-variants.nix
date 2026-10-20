{ pkgs, lib, ... }: {
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

  specialisation.Cachy = {
    configuration = {
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
    };
  };
}
