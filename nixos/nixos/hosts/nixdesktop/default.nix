{ ... }:

{
  imports = [
    ./hardware
    ./boot
  ];
  networking.hostName = "nixdesktop";
  system.stateVersion = "26.05";

}
