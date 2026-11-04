{
  flake.modules.nixos.common =
    { ... }:
    {
      # Remote SSH from anywhere: WireGuard mesh, no router port forwarding.
      # One-time per host: `sudo tailscale up`, then disable key expiry for
      # nixdesktop in the admin console (keys otherwise expire after 180 days).
      services.tailscale = {
        enable = true;
        openFirewall = true; # UDP 41641 for direct (non-relayed) connections
      };
    };
}
