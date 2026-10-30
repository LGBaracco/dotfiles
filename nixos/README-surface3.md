# Surface 3 (non-Pro) — notes for a NixOS host

Hardware findings and fixes from running Ubuntu 26.04 (kernel 7.0) on this device, to be
ported into a NixOS host in `nixos/nixos/modules/hosts/`. Everything below works on the **stock
kernel**; no linux-surface kernel, patches or compilation are needed.

## Hardware

| Part | Detail |
|---|---|
| CPU | Intel Atom x7-Z8700 (Cherry Trail). **x86-64-v2 only** (no AVX/AVX2) |
| RAM | 2 GB |
| Storage | 58 GB eMMC (`mmcblk1`), microSD slot (`mmcblk0`) |
| Wi-Fi/BT | Marvell 88W8897 (`11ab:2b38`, `mwifiex_pcie`) |
| Touch / pen | `surface3_spi` (mainline) |
| Audio | `sof-bytcht rt5645` (SOF firmware) |
| Firmware | UEFI 1.51116.238 (2015). Secure Boot off |

## Status on the stock kernel

Works on the stock kernel: Wi-Fi, Bluetooth, Type Cover, touch, pen and eraser, speakers and mic, backlight, battery (`surface3_power`),
buttons (`surfacepro3_button`, `surface3_wmi`), and the IIO accelerometer.

Doesn't work on any kernel, linux-surface included:
- **Cameras.** They depend on the atomisp driver, which doesn't work on this device.
- **Deep sleep (S3).** The firmware only declares `ACPI: PM: (supports S0 S5)`, and `mem_sleep` only offers `[s2idle]`.
  There's no hibernate either. Use s2idle, and shut down for longer storage.

Harmless boot log noise: ACPI `UOTG._CRS` errors, `cherryview-pinctrl ... -61`, and
`i915 ... Failed to xfer payload` with i2c_designware timeouts around modeset and resume.

## Required fixes

### 1. Suspend loop from the ACPI lid switch (critical)

The ACPI lid switch (`PNP0C0D`) is stuck reporting **closed**, so logind has `LidClosed=true` and
suspends the machine about every 30 s. After each wake-up it re-checks the lid and suspends again.
On X, LXQt hid this by taking over lid handling. Under niri and on a TTY, the tablet is unusable
without this fix. The `surface3-wmi` lid switch reports correctly, so drop the ACPI one from logind:

```nix
services.udev.extraRules = ''
  # Surface 3: ACPI lid stuck "closed" -> logind suspend loop; logind uses the surface3-wmi lid instead
  SUBSYSTEM=="input", KERNEL=="event*", ATTRS{phys}=="PNP0C0D/button/input0", TAG-="power-switch"
'';
```

Verified on Ubuntu: zero spurious suspends after the fix. To check the result, `busctl get-property org.freedesktop.login1
/org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed` prints `b false`, and
`journalctl -b -u systemd-logind | grep 'Watching.*Lid'` lists only the surface3-wmi device.

### 2. Wi-Fi stability (Marvell 88W8897)

The linux-surface wiki ("Marvell 88W8897 quirks", Surface 3 section) says that ASPM L1 and its
substates cause random firmware crashes. Power save is also flaky with mwifiex. Neither fix was tested on this device.

```nix
services.udev.extraRules = ''
  ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x11ab", ATTR{device}=="0x2b38", ATTR{link/l1_aspm}="0"
'';
networking.networkmanager.wifi.powersave = false;
```

### 3. Firmware and sensors

```nix
hardware.enableRedistributableFirmware = true;  # Marvell Wi-Fi/BT, SOF audio (check sof-firmware is included)
hardware.sensor.iio.enable = true;              # iio-sensor-proxy, for auto-rotation
```

## Low-RAM tuning (recommended)

With 2 GB of RAM, a browser alone pushed the system into swap.

```nix
zramSwap = { enable = true; algorithm = "zstd"; memoryPercent = 100; };
boot.kernel.sysctl = {
  "vm.swappiness" = 180;  # swapping to zram is cheap
  "vm.page-cluster" = 0;
};
```

Also worth doing:
- Keep the session light.
- Disable ModemManager, since the device has no modem.
- Leave CUPS and Avahi off unless you need them.

## Things to avoid

- **nixos-hardware `microsoft/surface/*` modules.** They switch to the linux-surface kernel, which
  isn't in the binary cache, so it would compile on every bump. The only extra it brings for the Surface 3 is hibernate, which this device doesn't support anyway.
- **`iptsd`** is only for IPTS devices (Surface Pro 4 and newer), and **`libwacom-surface`** isn't needed. Don't add either.
- **The `Cachy` specialisation from `nixos/nixos/modules/boot/kernel-variants.nix` (`common`).** Check that the
  CachyOS kernel variant runs on **x86-64-v2**. This CPU has no AVX, so a v3 build won't boot.
  The specialisation also doubles the kernel closure on a small eMMC. It's probably best to
  disable it for this host (`specialisation = lib.mkForce { }`).
- **`nixos-rebuild` on the device itself.** Evaluation needs too much RAM for 2 GB. Build elsewhere
  and deploy with `nixos-rebuild switch --target-host`, or use a remote builder.

Also set `nix.gc.automatic` and limit the number of boot entries (`boot.loader.*.configurationLimit`),
because of the 58 GB eMMC and the 300 MB ESP.

## Related

- `niri-surface/`: niri overrides for this device (Noctalia shell, wvkbd on-screen keyboard).
- Auto-rotation isn't set up yet. The accelerometer works (`monitor-sensor`). You'd need a small
  daemon that maps orientation to `niri msg output <name> transform ...`.
