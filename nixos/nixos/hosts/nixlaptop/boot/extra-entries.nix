{
  boot.loader.limine.extraEntries = ''
    /Windows
    comment: Windows Boot Manager
    comment: order-priority=20 
    protocol: efi

    /rEFInd
    comment: rEFInd bootloader
    comment: order-priority=20 
    protocol: efi
    path: boot():/EFI/refind/refind_x64.efipath: uuid(29e6ffaa-6a6b-4c30-b836-d55267db10e9):/EFI/Microsoft/Boot/bootmgfw.efi

    /EFI fallback
    comment: Default EFI loader
    comment: order-priority=10 
    protocol: efi
    path: boot():/EFI/BOOT/BOOTX64.EFI
  '';
}
