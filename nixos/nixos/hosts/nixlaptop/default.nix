{ ... }:

{
  imports = [
    ./boot
    ./hardware
    ./desktop-environment.nix
  ];
  networking.hostName = "nixlaptop";
  system.stateVersion = "26.05";
  home-manager.users.lorenzo.imports = [ ./lorenzo.nix ];
}
