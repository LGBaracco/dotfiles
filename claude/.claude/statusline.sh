#!/usr/bin/env bash
# Claude Code status line: model │ effort │ context window bar │ rate-limit circles (5h, 7d).
# Reads the session JSON Claude Code pipes on stdin; see `statusLine` in settings.json.
# Colors are the terminal's bright ANSI red/yellow/green/magenta (ghostty gruvbox: #fb4934 #fabd2f #b8bb26 #d3869b).
# Not truecolor: Claude Code re-emits the line in 256 colours, which turns gruvbox green into a yellow.
# Circles are Nerd Font glyphs (Material Design circle-outline + circle-slice-1..8).
exec jq -rj '
  def esc(c): "\u001b[" + c + "m";
  def color(p): if p >= 80 then esc("91") elif p >= 50 then esc("93") else esc("92") end;
  def dim(s): esc("2") + s + esc("0");
  def rep(s; n): if n > 0 then s * n else "" end;
  def clamp(lo; hi): [[., lo] | max, hi] | min;
  def bar(p): (p / 10 | round | clamp(0; 10)) as $n
    | color(p) + rep("▰"; $n) + esc("2") + rep("▱"; 10 - $n) + esc("0");
  # U+F0766 circle-outline, U+F0A9E..U+F0AA5 circle-slice-1..8
  def circle(p): (p / 12.5 | ceil | clamp(0; 8)) as $n
    | color(p) + ([if $n == 0 then 984934 else 985757 + $n end] | implode) + esc("0");
  def pct(p): color(p) + "\(p | round)%" + esc("0");
  def tokens(n): if n >= 1000000 then "\(n / 1000000 * 10 | round / 10)M"
    elif n >= 1000 then "\(n / 1000 | round)k" else "\(n)" end;
  def reset(r): if r.resets_at == null then "" else " " + dim("↻" + (r.resets_at | strflocaltime(
    if r.resets_at - now > 86400 then "%a %H:%M" else "%H:%M" end))) end;
  def limit(name; r): if r.used_percentage == null then empty
    else dim(name) + " " + circle(r.used_percentage) + " " + pct(r.used_percentage) + reset(r) end;

  .context_window as $cw
  | .rate_limits as $rl
  | [
      esc("1") + (.model.display_name // "Claude") + esc("0"),
      (if .effort.level then dim("effort") + " " + esc("95") + .effort.level + esc("0") else empty end),
      dim("context") + " " + if $cw.used_percentage == null then dim("--")
        else bar($cw.used_percentage) + " " + pct($cw.used_percentage) + " "
          + dim("\(tokens($cw.total_input_tokens // 0))/\(tokens($cw.context_window_size // 0))") end,
      (if $rl.five_hour then limit("5h"; $rl.five_hour) else empty end),
      (if $rl.seven_day then limit("7d"; $rl.seven_day) else empty end)
    ]
  | join(" " + dim("│") + " ")
'
