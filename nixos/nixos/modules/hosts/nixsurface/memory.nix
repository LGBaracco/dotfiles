{
  flake.modules.nixos.nixsurface =
    { ... }:
    {
      # ── 2 GB RAM ──────────────────────────────────────────────────────────────
      # zram as large as RAM (zstd, ~3:1), tuned for swap that lives in memory (ArchWiki: Zram)
      zramSwap.memoryPercent = 100;
      boot.kernel.sysctl = {
        "vm.swappiness" = 180;
        "vm.watermark_boost_factor" = 0;
        "vm.watermark_scale_factor" = 125;
        "vm.page-cluster" = 0;
      };
      # zswap would compress pages before they reach zram
      boot.kernelParams = [ "zswap.enabled=0" ];

      # Kill the largest process before a full zram locks the system up
      services.earlyoom.enable = true;
    };
}
