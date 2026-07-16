{ pkgs, ... }:
{
  hardware.firmware = [
    (pkgs.runCommand "Patch firmware" { } ''
      mkdir -p $out/lib/firmware
      cp ${./firmware}/* $out/lib/firmware
    '')
  ];
}
