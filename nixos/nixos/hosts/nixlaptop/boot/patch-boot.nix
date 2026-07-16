{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{

  # ── Boot ──────────────────────────────────────────────────────────────────
   # Appends CachyOS entries from its own limine.conf
   system.activationScripts.patchLimineCachy = {
    supportsDryActivation = true;
    text = ''
        TARGET_CONF="/boot/limine/limine.conf"
        CACHY_CONF="/boot/limine.conf"

        if [ -f "$TARGET_CONF" ] && [ -f "$CACHY_CONF" ]; then
        # Check for your loop-prevention marker
        if ! grep -q "### CACHYOS_ENTRIES_START ###" "$TARGET_CONF"; then
            echo "Injecting CachyOS boot profiles synchronously..."
            echo -e "\n### CACHYOS_ENTRIES_START ###" >> "$TARGET_CONF"
            cat "$CACHY_CONF" >> "$TARGET_CONF"
            echo "### CACHYOS_ENTRIES_END ###" >> "$TARGET_CONF"
        fi
        fi
    '';
    };
}
