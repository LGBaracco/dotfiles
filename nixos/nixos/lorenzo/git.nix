{ pkgs, ... }:

{
  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {

      user.email = "lorenzobaracco01@gmail.com";
      user.name = "LGBaracco";
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };
}
