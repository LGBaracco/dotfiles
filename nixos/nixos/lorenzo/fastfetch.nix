{ ... }:
let
  # E-style dual columns (key | value) with C rounded corners, D color sections.
  # Value right border uses ANSI save/restore + fixed column move (preset-24 idea).
  keyInner = 11; # pad labels to this (fits "Compositor")
  valInner = 42; # content width before right │
  # Nix has no \x escapes; produce ESC via JSON.
  esc = builtins.fromJSON ''"\u001b"'';

  padRight =
    n: s:
    let
      len = builtins.stringLength s;
      pad = if len >= n then 0 else n - len;
    in
    s + builtins.concatStringsSep "" (builtins.genList (_: " ") pad);

  dashes = n: builtins.concatStringsSep "" (builtins.genList (_: "─") n);

  # Left cell total width: "│ " + keyInner + " │" = keyInner + 4
  keyWidth = keyInner + 4;
  # Value cell: "│ " + valInner cols + "│" = valInner + 3
  valWidth = valInner + 3;

  keyTop = "╭${dashes (keyWidth - 2)}╮";
  keyBot = "╰${dashes (keyWidth - 2)}╯";
  # Title sits in the wider value-column top border
  valTop =
    title:
    let
      # "╭─ " + title + " " + dashes + "╮" = 5 + title + dashes
      d = valWidth - 5 - builtins.stringLength title;
    in
    "╭─ ${title} ${dashes d}╮";
  valBot = "╰${dashes (valWidth - 2)}╯";

  sectionOpen = color: title: {
    type = "custom";
    key = "{#${color}}${keyTop}";
    format = "{#${color}}${valTop title}";
  };

  sectionClose = color: {
    type = "custom";
    key = "{#${color}}${keyBot}";
    format = "{#${color}}${valBot}";
  };

  # Borders keep section color; value body is white so percent/status colors can show.
  item =
    color: type: key: valueFormat: extra:
    {
      inherit type;
      key = "{#${color}}│ ${padRight keyInner key} │";
      format = "{#${color}}│ {#white}${esc}[s${valueFormat}${esc}[u${esc}[${toString valInner}C{#${color}}│";
    }
    // extra;
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "none";
      };

      display = {
        separator = "";
        color = {
          output = "white";
        };
        # Colored percentage numbers (memory / disk / battery).
        percent = {
          type = 9;
        };
      };

      modules = [
        # ── system ──────────────────────────────────────────
        (sectionOpen "cyan" "system")
        (item "cyan" "title" "User" "{user-name}" { })
        (item "cyan" "title" "Hostname" "{host-name}" { })
        (item "cyan" "os" "OS" "{pretty-name} {arch}" { })
        (item "cyan" "host" "Host" "{name} ({version})" { })
        (item "cyan" "kernel" "Kernel" "{sysname} {release}" { })
        (item "cyan" "shell" "Shell" "{pretty-name} {version}" { })
        (sectionClose "cyan")

        # ── desktop ─────────────────────────────────────────
        (sectionOpen "magenta" "desktop")
        (item "magenta" "display" "Display"
          "{width}x{height} @ {scale-factor}x in {inch}\", {refresh-rate} Hz"
          { }
        )
        (item "magenta" "wm" "Compositor" "{pretty-name} {version}" { })
        # Icons: native field always appends [GTK…]; read theme name instead.
        (item "magenta" "command" "Icons" "{result}" {
          text = ''(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo "'breeze-dark'") | tr -d "'"''
          ;
        })
        (item "magenta" "font" "Font" "{font2}" { })
        (item "magenta" "cursor" "Cursor" "{theme} ({size})" { })
        (sectionClose "magenta")

        # ── hardware ────────────────────────────────────────
        (sectionOpen "green" "hardware")
        (item "green" "cpu" "CPU" "{name}" { })
        (item "green" "gpu" "GPU" "{name}" { hideType = "integrated"; })
        (item "green" "memory" "Memory" "{used} / {total} ({percentage})" { })
        (item "green" "disk" "Disk" "{size-used} / {size-total} ({size-percentage}) - {filesystem}" {
          folders = [ "/" ];
        })
        # {capacity} already includes a % sign
        (item "green" "battery" "Battery" "{capacity} [{status}]" { })
        (sectionClose "green")

        # ── miscellaneous ───────────────────────────────────
        (sectionOpen "yellow" "miscellaneous")
        (item "yellow" "localip" "Local IP" "{ipv4}" { })
        (item "yellow" "poweradapter" "Adapter" "{name}" { })
        (item "yellow" "uptime" "Uptime" "{formatted}" { })
        (sectionClose "yellow")

        "break"
        {
          type = "colors";
          symbol = "circle";
          paddingLeft = 2;
        }
      ];
    };
  };
}
