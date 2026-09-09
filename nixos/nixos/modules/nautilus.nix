{ ... }: {
  # Open Ghostty from Nautilus context menu (needs system install for extension paths).
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };
}
