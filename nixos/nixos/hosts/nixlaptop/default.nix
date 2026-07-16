{ ... }:

{
  imports = [
    ./boot
    ./hardware
  ];
  networking.hostName = "nixlorenzo";
  system.stateVersion = "26.05";
}
