{ ... }:

{
  imports = [
    ./boot
    ./hardware
  ];
  networking.hostName = "nixlaptop";
  system.stateVersion = "26.05";
  home-manager.users.lorenzo.imports = [ ./lorenzo.nix ];
}
