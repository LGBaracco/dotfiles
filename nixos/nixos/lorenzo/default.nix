{ ... }: {
  imports = [
    ./editors.nix
    ./misc.nix
    ./git.nix
    ./home-packages.nix
    ./chromium.nix
    ./theming/gtk-qt.nix
    ./dcal.nix
    ./davmail.nix
    ./desktop-entries.nix
  ];
}
