#!/usr/bin/env bash
# Claude Code status line: model │ effort │ context window bar │ rate-limit circles (5h, 7d).
# Reads the session JSON Claude Code pipes on stdin; see `statusLine` in settings.json.
# Colors are the terminal's bright ANSI red/yellow/green/magenta (ghostty gruvbox: #fb4934 #fabd2f #b8bb26 #d3869b).
# Not truecolor: Claude Code re-emits the line in 256 colours, which turns gruvbox green into a yellow.
# Bar and circles are Nerd Font glyphs (progress bar; Material Design circle-outline + circle-slice-1..8).
exec jq -rj '
  def esc(c): "\u001b[" + c + "m";
  # Yellow from $y%, red from $r%; color(p) is the default 50/80 split.
  def color(p; $y; $r): if p >= $r then esc("91") elif p >= $y then esc("93") else esc("92") end;
  def color(p): color(p; 50; 80);
  def dim(s): esc("2") + s + esc("0");
  def clamp(lo; hi): [[., lo] | max, hi] | min;
  # U+EE00..U+EE02 progress empty left/middle/right, U+EE03..U+EE05 filled. Kept in the
  # Nerd Font: ▰▱ fell back to DejaVu Sans, which Neovide draws off the cell grid.
  def cell($i; $full): [60928 + (if $i == 0 then 0 elif $i == 9 then 2 else 1 end)
    + (if $full then 3 else 0 end)] | implode;
  def bar(p): (p / 10 | round | clamp(0; 10)) as $n
    | color(p) + ([range(0; $n) | cell(.; true)] | add // "")
    + esc("2") + ([range($n; 10) | cell(.; false)] | add // "") + esc("0");
  # U+F0766 circle-outline, U+F0A9E..U+F0AA5 circle-slice-1..8
  def circle(p; c): (p / 12.5 | ceil | clamp(0; 8)) as $n
    | c + ([if $n == 0 then 984934 else 985757 + $n end] | implode) + esc("0");
  def pct(p; c): c + "\(p | round)%" + esc("0");
  def pct(p): pct(p; color(p));
  def tokens(n): if n >= 1000000 then "\(n / 1000000 * 10 | round / 10)M"
    elif n >= 1000 then "\(n / 1000 | round)k" else "\(n)" end;
  def reset(r): if r.resets_at == null then "" else " " + dim("↻" + (r.resets_at | strflocaltime(
    if r.resets_at - now > 86400 then "%a %H:%M" else "%H:%M" end))) end;
  def limit(name; r; $yellow; $red): if r.used_percentage == null then empty
    else color(r.used_percentage; $yellow; $red) as $c
      | dim(name) + " " + circle(r.used_percentage; $c) + " " + pct(r.used_percentage; $c) + reset(r) end;

  .context_window as $cw
  | .rate_limits as $rl
  | [
      esc("1") + (.model.display_name // "Claude") + esc("0"),
      (if .effort.level then dim("effort") + " " + esc("95") + .effort.level + esc("0") else empty end),
      dim("context") + " " + if $cw.used_percentage == null then dim("--")
        else bar($cw.used_percentage) + " " + pct($cw.used_percentage) + " "
          + dim("\(tokens($cw.total_input_tokens // 0))/\(tokens($cw.context_window_size // 0))") end,
      (if $rl.five_hour then limit("5h"; $rl.five_hour; 50; 80) else empty end),
      # 7d only from 50%, so it starts green there: yellow from 70%, red from 90%.
      (if ($rl.seven_day.used_percentage // 0) >= 50 then limit("7d"; $rl.seven_day; 70; 90) else empty end)
    ]
  | join(" " + dim("│") + " ")
'
