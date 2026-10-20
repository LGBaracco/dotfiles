{
  flake.modules.nixos.nixlaptop =
    { pkgs, ... }:
    # TAS2781 smart amps (4x, i2c TIAS2781:00) sound quiet/distorted with the stock
    # TIAS2781RCA4.bin. Its profiles write 0xD9 to book 0 page 0 reg 0x5C, which sets
    # CLK_PWRUD (amp auto power up/down on I2S clock start/stop) and DIS_CLK_HALT.
    # Patch every occurrence back to the chip's reset default 0x19 (TAS2781 datasheet
    # SLOSE86B, 8.9.53). The driver doesn't verify the RCA header checksum.
    {
      hardware.firmware = [
        (pkgs.runCommand "tas2781-rca4-clk-pwrud-fix" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          mkdir -p $out/lib/firmware
          python3 -I - ${pkgs.linux-firmware}/lib/firmware/ti/audio/tas2781/TIAS2781RCA4.bin \
            $out/lib/firmware/TIAS2781RCA4.bin <<'EOF'
          import sys
          data = open(sys.argv[1], "rb").read()
          old, new = bytes.fromhex("00005cd9"), bytes.fromhex("00005c19")
          n = data.count(old)
          if n != 8:
              sys.exit(f"expected 8 writes of reg 0x5C=0xD9, found {n}")
          open(sys.argv[2], "wb").write(data.replace(old, new))
          EOF
        '')
      ];
    };
}
