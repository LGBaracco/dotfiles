{ inputs, ... }:
{
  flake.modules.nixos.workstation =
    { pkgs, lib, ... }: {
      imports = [ inputs.chaotic.nixosModules.default ];

      boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

      specialisation.Cachy = {
        configuration = {
          boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
        };
      };
    };
}
