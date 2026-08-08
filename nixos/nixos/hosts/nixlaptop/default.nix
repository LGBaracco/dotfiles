{ ... }:

{
  imports = [
    ./boot
    ./hardware
  ];
  networking.hostName = "nixlaptop";
  system.stateVersion = "26.05";
}
