{ inputs, ... }:
{
  flake.modules.homeManager.lorenzo = { pkgs, ... }: {
    imports = [ inputs.dankcalendar.homeModules.dank-calendar ];

    programs.dank-calendar = {
      enable = true;
      systemd.enable = true;
      # The flake input's build is broken (stale vendorHash, missing dux-go);
      # nixpkgs' dux-calendar is the same 2.0.0 release and substitutable.
      package = pkgs.dux-calendar;
    };

    systemd.user.services.dcal.Install.WantedBy = [ "mango-session.target" ];
  };
}
