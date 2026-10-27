{ inputs, ... }:
{
  flake.modules.homeManager.workstation =
    { ... }: {
      imports = [ inputs.dankcalendar.homeModules.dank-calendar ];

      programs.dank-calendar = {
        enable = true;
        systemd = {
          enable = true;
          target = "niri.service";
        };
      };

      systemd.user.services.dcal.Install.WantedBy = [ "mango-session.target" ];
    };
}
