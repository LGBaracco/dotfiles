{ pkgs, ... }:

{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.hasklug
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      symbola
      helvetica-neue-lt-std

    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
    };
  };

}
