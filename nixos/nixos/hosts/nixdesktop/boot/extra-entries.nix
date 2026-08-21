{ ... }: {
  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.limine.extraEntries = ''
    /Windows Boot Manager
    protocol: efi_chainload
    image_path: guid(E19EC432-052D-11F1-8E68-3303300995F0):/efi/Microsoft/Boot/bootmgfw.efi

    /EFI fallback
    comment: Default EFI loader
    comment: order-priority=10
    protocol: efi
    path: boot():/EFI/BOOT/BOOTX64.EFI
  '';
}
