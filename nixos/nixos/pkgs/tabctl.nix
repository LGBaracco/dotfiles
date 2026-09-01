{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

let
  version = "2.2.2";
in
buildGoModule rec {
  pname = "tabctl";
  inherit version;

  src = fetchFromGitHub {
    owner = "slastra";
    repo = "tabctl";
    rev = "v${version}";
    hash = "sha256-Z0tifgD8crAMDPy9/2vNrvoNa3lOp81wpi5mnl93mE4=";
  };

  vendorHash = "sha256-oSt9bwhTf4EBeWhgb6sXvGJK7B75MGya4Gp2nMPqgDM=";

  subPackages = [
    "cmd/tabctl"
    "cmd/tabctl-mediator"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/tabctl/tabctl/internal/config.Version=${version}"
  ];

  meta = with lib; {
    description = "Control browser tabs from the command line using D-Bus IPC";
    homepage = "https://github.com/slastra/tabctl";
    license = licenses.mit;
    mainProgram = "tabctl";
  };
}
