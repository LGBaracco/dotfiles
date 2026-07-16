{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
              ./nvidia.nix
              ./hardware-configuration.nix];

}
