{
  flake.modules.nixos.workstation =
    {pkgs, ...}: {
      programs.steam = {
        enable = true;
        #gamescopeSession.enable = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };
    };
}
