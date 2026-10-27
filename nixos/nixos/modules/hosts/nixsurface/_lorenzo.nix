{...}: {
  home.stateVersion = "26.11";

  # Surface-only niri settings, loaded by the optional include at the end of niri/config.kdl
  xdg.configFile."niri-host.kdl".source = ./niri-host.kdl;
}
