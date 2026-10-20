{
  flake.modules.homeManager.lorenzo =
    { pkgs, ... }:
    let
      # The JDK's bundled cacerts lacks HARICA TLS RSA Root CA 2021 (root of FZJ's
      # GEANT cert), so build a truststore from the system CA bundle instead.
      truststore = pkgs.runCommand "davmail-cacerts" { } ''
        ${pkgs.jre-generate-cacerts} ${pkgs.jdk}/bin/keytool ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        mv cacerts $out
      '';
    in
    {
      # DavMail: Exchange (EWS) → CalDAV gateway on localhost:1080, consumed by dcal.
      # Credentials are entered in dcal's CalDAV account (keyring), never here.
      services.davmail = {
        enable = true;
        settings = {
          "davmail.mode" = "EWS";
          "davmail.url" = "https://webmail.fz-juelich.de/EWS/Exchange.asmx";
          # Only CalDAV is needed; empty port disables the listener
          "davmail.imapPort" = "";
          "davmail.smtpPort" = "";
          "davmail.popPort" = "";
          "davmail.ldapPort" = "";
          "davmail.allowRemote" = false;
          "davmail.caldavPastDelay" = 90;
        };
      };

      # Replaces the wrapper's default JAVA_OPTS (kept below); quoted so systemd
      # does not split the value on spaces
      systemd.user.services.davmail.Service.Environment = [
        "\"JAVA_OPTS=-Xmx512M -Dsun.net.inetaddr.ttl=60 -Djavax.net.ssl.trustStore=${truststore} -Djavax.net.ssl.trustStorePassword=changeit\""
      ];

      systemd.user.services.davmail.Install.WantedBy = [ "mango-session.target" ];
    };
}
