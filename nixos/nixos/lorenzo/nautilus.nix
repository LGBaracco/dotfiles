{ pkgs, ... }: {
  home.packages = with pkgs; [
    nautilus
    sushi # Spacebar quick preview in Nautilus
  ];
}
