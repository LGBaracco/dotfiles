{pkgs, ...}: {
  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "LGBaracco";
    userEmail = "lorenzobaracco01@gmail.com";
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
    gitCredentialHelper = {
      enable = true;
    };
  };
}
