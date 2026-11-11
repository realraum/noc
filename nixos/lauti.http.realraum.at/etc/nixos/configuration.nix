{ config, lib, pkgs, ... }:

let
  mobilizonCalendarMirror = {
    user = "calendarbot";
    group = "calendarbot";
    home = "/home/calendarbot";
    repoDir = "/home/calendarbot/lauti-to-mobilizon";
    repository = "https://github.com/realraum/grical-to-mobilizon.git";
    branch = "lauti-to-mobilizon";
    fallbackBranch = "master";
  };

  nodejs = pkgs.nodejs_22;
  # pnpm_10 is flagged as insecure in nixpkgs 26.05; pnpm_10_latest is the
  # patched 10.x release and still understands the project's lockfile (9.0).
  pnpm = pkgs.pnpm_10_latest;

  # Pre-built node_modules for grical-to-mobilizon.
  #
  # Dependencies are fetched by a fixed-output derivation (fetchPnpmDeps), which
  # is the only way to get network access inside the Nix sandbox. The native
  # node-libcurl binding is then compiled offline against nixpkgs' curl, so no
  # vcpkg bootstrap (which would need network + writable $HOME) ever runs.
  #
  # When the branch moves, refresh both hashes:
  #   nix-prefetch-github --owner realraum --repo grical-to-mobilizon --rev lauti-to-mobilizon
  #   (then set pnpmDeps.hash = "" and read the "got:" value from the build error)
  grical-to-mobilizon-deps = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "grical-to-mobilizon-deps";
    version = "1.0";

    src = pkgs.fetchFromGitHub {
      owner = "realraum";
      repo = "grical-to-mobilizon";
      rev = mobilizonCalendarMirror.branch;
      sha256 = "sha256-lm9GVInuqQT6P85mWD/71Sm22padhCf0s1xNpmwiYKI=";
    };

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      inherit pnpm;
      fetcherVersion = 4;
      hash = "sha256-NNe3vTqrNVHLzOatU1mhABorSE8dEaUE7UH0SCKU9oQ=";
    };

    nativeBuildInputs = [
      nodejs
      pnpm
      pkgs.pnpmConfigHook
      pkgs.pkg-config
      pkgs.python3
      pkgs.curl.dev # provides curl-config, used by binding.gyp
    ];

    buildInputs = [
      pkgs.curl.out
      pkgs.openssl
      pkgs.zlib
    ];

    buildPhase = ''
      runHook preBuild

      export npm_config_nodedir=${nodejs}
      export HOME=$(mktemp -d)

      libcurlDir=$(echo node_modules/.pnpm/node-libcurl@*/node_modules/node-libcurl)
      echo "Building native node-libcurl binding in $libcurlDir"
      pushd "$libcurlDir"
        ./node_modules/.bin/node-pre-gyp configure --nodedir=${nodejs}
        ./node_modules/.bin/node-pre-gyp build --nodedir=${nodejs}
      popd

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules $out/
      runHook postInstall
    '';
  });

  mobilizonCalendarMirrorConfig = {
    usernames = [ "realraum" ];
    defaultPicture = "5d5efceb-8c08-436b-a906-8172c5008366";
    addressID = "91";
    mobilizon = "https://events.graz.social/api";
    lauti = "https://r3.at/public_events.ics";
    lautiHosts = [ "laut.realraum.at" ];
    maxFutureDuration = {
      months = 4;
    };
    _predefinedHint = "Can contain: { organizer, summary, picture: { mediaUuid }, title, tags (added to lauti tags) }";
    predefined = [
      [
        "Mitgliedertreffen"
        {
          title = "realraum Mitgliedertreffen";
          summary = "<p><strong>Worum geht’s?</strong></p><p>Der realraum ist ein Treffpunkt zum Basteln, Experimentieren und vielem mehr – ein Hackerspace für die Bereiche Software, Hardware, Computer und Elektronik, Molekularbiologie und Chemie. <a target=\"_blank\" rel=\"noopener noreferrer ugc\" href=\"https://wp.realraum.at/realraum/\">Lies mehr über uns</a></p>";
        }
      ]
      [
        "Funkfeuer"
        {
          organizer = "funkfeuer";
          summary = "<p>Funkfeuer Graz ist ein freies, experimentelles Funk-Netzwerk in Graz. Funkfeuer ist offen für Jeden und Jede, der/die Interesse hat und bereit ist mitzuarbeiten. Funkfeuer ist ein nicht reguliertes Netzwerk, das den digitalen Graben zwischen den sozialen Schichten überbrückt und Infrastruktur und Wissen zur Verfügung zu stellen.</p><p>Funkfeuer wird von computerbegeisterten Menschen mit unterschiedlicher Motivation und Interessen betrieben. Das Projekt verfolgt keine kommerziellen Interessen.</p><p>Funkfeuer ist auch ein Soziales Experiment denn es versucht Arbeitsweisen aus der Open Source Welt in einem gesellschaftlichen Kontext zu etablieren.</p><p>Es gibt keine Zentrale Institution, wir bauen uns unser Netzwerk selber!</p>";
        }
      ]
    ];
  };

  mobilizonCalendarMirrorConfigFile =
    pkgs.writeText "mobilizon-calendar-mirror-config.json"
      (builtins.toJSON mobilizonCalendarMirrorConfig);

  mobilizonCalendarMirrorUpdate = pkgs.writeShellApplication {
    name = "mobilizon-calendar-mirror-update";
    runtimeInputs = with pkgs; [
      cacert
      coreutils
      git
    ];
    text = ''
      set -euo pipefail

      repoDir=${lib.escapeShellArg mobilizonCalendarMirror.repoDir}
      repository=${lib.escapeShellArg mobilizonCalendarMirror.repository}
      branch=${lib.escapeShellArg mobilizonCalendarMirror.branch}
      fallbackBranch=${lib.escapeShellArg mobilizonCalendarMirror.fallbackBranch}

      export HOME=${lib.escapeShellArg mobilizonCalendarMirror.home}
      export SSL_CERT_FILE=${lib.escapeShellArg "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"}
      export GIT_SSL_CAINFO="$SSL_CERT_FILE"

      mkdir -p "$repoDir"

      # session.json is ignored upstream, but protect the live credentials from a
      # forced checkout in case upstream ever starts tracking a file with that
      # name. If it does not exist, no session file is created here.
      sessionFile="$repoDir/session.json"
      sessionBackup=
      if [ -f "$sessionFile" ]; then
        sessionBackup=$(mktemp "$repoDir/.session.json.backup.XXXXXX")
        cp -p "$sessionFile" "$sessionBackup"
      fi

      restoreSession() {
        if [ -n "$sessionBackup" ] && [ -f "$sessionBackup" ]; then
          mv -f "$sessionBackup" "$sessionFile"
        fi
      }
      trap restoreSession EXIT

      if [ ! -d "$repoDir/.git" ]; then
        git -C "$repoDir" init -q
        git -C "$repoDir" remote add origin "$repository"
      else
        git -C "$repoDir" remote set-url origin "$repository"
      fi

      if git ls-remote --exit-code --heads "$repository" "refs/heads/$branch" >/dev/null 2>&1; then
        selectedBranch="$branch"
      else
        echo "Branch '$branch' no longer exists upstream; falling back to '$fallbackBranch'." >&2
        selectedBranch="$fallbackBranch"
      fi

      git -C "$repoDir" fetch --prune --force origin "+refs/heads/*:refs/remotes/origin/*"
      git -C "$repoDir" checkout -f -B "$selectedBranch" "origin/$selectedBranch"
      git -C "$repoDir" reset --hard "origin/$selectedBranch"

      restoreSession
      trap - EXIT

      # config.json is generated from this NixOS configuration. session.json is
      # intentionally left alone: it is created once (pnpm new-session) and is
      # refreshed/rewritten by the application itself.
      install -m 0640 ${mobilizonCalendarMirrorConfigFile} "$repoDir/config.json"

      # node_modules (including the compiled node-libcurl binding) comes from
      # the Nix store. Symlinking keeps it in sync with the configuration and
      # avoids running pnpm install at runtime, which cannot work here: the
      # node-libcurl preinstall script bootstraps vcpkg and needs network
      # access plus writable non-store paths.
      rm -rf "$repoDir/node_modules"
      ln -sfn ${grical-to-mobilizon-deps}/node_modules "$repoDir/node_modules"
    '';
  };
in
{
  # System basics
  imports = [
    ./hardware-configuration.nix
  ];

 # Boot loader
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.loader.grub.extraConfig = "
   serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
   terminal_input serial
   terminal_output serial
  ";

  # Disable the upstream getty module's automatic configuration for serial-getty@
  # This prevents conflicts with our custom configuration
  systemd.services."serial-getty@" = {
    enable = false;
  };

  # Configure our own serial-getty@ttyS0 service
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    after = [ "systemd-user-sessions.service" ];
    wants = [ "systemd-user-sessions.service" ];
    serviceConfig = {
      Type = "idle";
      Restart = "always";
      Environment = "TERM=vt220";
      ExecStart = "${pkgs.util-linux}/bin/agetty --login-program ${pkgs.shadow}/bin/login --noclear --keep-baud ttyS0 115200,57600,38400,9600 vt220";
      UtmpIdentifier = "ttyS0";
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/ttyS0";
      TTYReset = "yes";
      TTYVHangup = "yes";
      IgnoreSIGPIPE = "no";
      SendSIGHUP = "yes";
    };
  };

  # Match interfaces to MACs via systemd-network link files
  systemd.network.links = {
    "10-mgmt-cloud-init-iface" = {
      matchConfig.MACAddress = "BC:24:11:0C:C6:0D";
      linkConfig.Name = "eth0";
    };
    "10-http-iface" = {
      matchConfig.MACAddress = "BC:24:11:0C:C6:0E";
      linkConfig.Name = "eth1http";
    };
  };

  # Networking
  networking = {
    hostName = "lauti";
    useDHCP = false;  # Disable DHCP, let cloud-init handle it
    interfaces = {
	"eth0" = {
    	    useDHCP = false;  # Disable DHCP, let cloud-init handle it
	};
	"eth1http" = {
    	    useDHCP = false;  # Disable DHCP, let cloud-init handle it
	    ipv4.addresses = [
              {
                 address = "192.168.34.66";
                 prefixLength = 24;  # Adjust subnet mask as needed
              }
            ];
	};
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 3333 ];
    };
  };
  services.cloud-init.enable = true;
  services.cloud-init.network.enable = true;

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = false;
      Domains = [ "~." ];
      FallbackDNS = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
      DNSOverTLS = false;
    };
  };

  # Add lauti package
  environment.systemPackages = [
    pkgs.httpie
    pkgs.lauti
    pkgs.grml-zsh-config
    pkgs.zsh
    pkgs.zsh-z
    pkgs.neovim
    pkgs.vimPlugins.vim-suda
    pkgs.tmux
    pkgs.vimPlugins.comment-nvim
    nodejs
    pnpm
    pkgs.git
  ];

  # Time zone and locale
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "de";
  };

  # Zsh as default shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Mount /dev/sdb1 on /srv
  fileSystems."/srv" = {
    device = "/dev/disk/by-label/lautidata";
    fsType = "ext4";  # Adjust to your filesystem type
    options = [ "defaults" ];
  };

  # Create lauti data directory structure
  systemd.tmpfiles.rules = [
    "d /srv/lauti 0755 root root -"
    "d /srv/lauti/media 0777 root root -"
    "d /srv/lauti/themes 0777 root root -"
    "d /srv/lauti/osm 0777 root root -"
    "d /srv/lauti/data 0777 root root -"
    "d /home/calendarbot/.cache 0755 calendarbot calendarbot -"
  ];

  # Lauti service configuration with custom data path
  # Configure lauti service
  services.qemuGuest.enable = true;
  # services.eintopf was renamed to services.lauti in NixOS 26.05.
  services.lauti = {
    enable = true;
    dataDir = "/srv/lauti";
    # Persistent admin password; read by systemd before privileges are dropped.
    secrets = [ "/srv/lauti/env" ];

    settings = {
      LAUTI_ADMIN_EMAIL = "noc@r3.at";
      LAUTI_BASE_URL = "https://laut.realraum.at";
      LAUTI_ADDR = "192.168.34.66:3333";
      LAUTI_SQLITE_DB = "/srv/lauti/data/lauti.db";
      LAUTI_MEDIA_PATH = "/srv/lauti/media";
      LAUTI_THEMES_PATH = "/srv/lauti/themes";
      LAUTI_THEME = "realraum";
      LAUTI_OSM_TILE_CACHE_DIR = "/srv/lauti/osm";
      LAUTI_AUTH_KEY_PATH = "/srv/lauti/data/auth-key";
      LAUTI_SEARCH_INDEX_PATH = "/srv/lauti/data/index.bleve";
      LAUTI_OSM_TILE_SERVER = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
      LAUTI_TIMEZONE = "Europe/Vienna";
      LAUTI_LOCALE = "de_DE";
      LAUTI_MAIL_SMTP_HOST = "";
      LAUTI_MAIL_SMTP_PASSWORD = "";
      LAUTI_MAIL_SMTP_USER = "";
      LAUTI_MAIL_SMTP_SECURE = "StartTLS";
    };
  };

  # Bind mount for lauti service to use /srv/lauti
  systemd.services.lauti = {
    after = [ "srv.mount" ];
    requires = [ "srv.mount" ];
    serviceConfig = {
      ReadWritePaths = [ "/srv/lauti" ];
    };
  };


  # Mobilizon calendar mirror (grical-to-mobilizon).
  #
  # The application is checked out at runtime so the lauti-to-mobilizon branch
  # can be followed and automatically falls back to master once that branch is
  # deleted. session.json is expected to exist in the checkout; it is never
  # created or overwritten here, because the application refreshes and rewrites
  # it after every successful login.
  users.groups.calendarbot = { };

  users.users.calendarbot = {
    isSystemUser = true;
    group = mobilizonCalendarMirror.group;
    home = mobilizonCalendarMirror.home;
    homeMode = "0750";
    createHome = true;
    shell = "${pkgs.shadow}/bin/nologin";
  };

  systemd.services.mobilizon-calendar-mirror-update = {
    description = "Clone/update grical-to-mobilizon and link pre-built dependencies";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = with pkgs; [
      cacert
      coreutils
      git
    ];
    environment = {
      HOME = mobilizonCalendarMirror.home;
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    serviceConfig = {
      Type = "oneshot";
      User = mobilizonCalendarMirror.user;
      Group = mobilizonCalendarMirror.group;
      WorkingDirectory = mobilizonCalendarMirror.home;
      ExecStart = "${mobilizonCalendarMirrorUpdate}/bin/mobilizon-calendar-mirror-update";

      # Only a git fetch plus a symlink; no builds happen here anymore.
      TimeoutStartSec = "5min";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ mobilizonCalendarMirror.home ];
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallFilter = [ "@system-service" ];
      SystemCallArchitectures = "native";
    };
  };

  systemd.services.mobilizon-calendar-mirror = {
    description = "Mobilizon calendar mirror (grical-to-mobilizon)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ nodejs pkgs.coreutils ];
    environment = {
      HOME = mobilizonCalendarMirror.home;
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    serviceConfig = {
      Type = "oneshot";
      User = mobilizonCalendarMirror.user;
      Group = mobilizonCalendarMirror.group;
      WorkingDirectory = mobilizonCalendarMirror.repoDir;

      # Best-effort report first, then the actual sync. A failing report must
      # not prevent the sync from running. These invoke node directly (the
      # package.json "report"/"start" scripts) so that pnpm never needs a
      # writable store or home directory at runtime.
      ExecStart = [
        "-${nodejs}/bin/node --experimental-json-modules --experimental-loader node-esm-loader report-foreign-events.js --autoremove-deleted"
        "${nodejs}/bin/node --experimental-json-modules --experimental-loader node-esm-loader index.js"
      ];

      # Type=oneshot: TimeoutStartSec doubles as the runtime limit.
      TimeoutStartSec = "10min";
      MemoryMax = "512M";
      MemoryHigh = "384M";
      TasksMax = 256;
      UMask = "0077";

      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ mobilizonCalendarMirror.repoDir mobilizonCalendarMirror.home ];
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RemoveIPC = true;
      SystemCallFilter = [ "@system-service" ];
      SystemCallArchitectures = "native";
    };
  };

  systemd.timers.mobilizon-calendar-mirror = {
    description = "Run the Mobilizon calendar mirror every 8 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00/8:00:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
      Unit = "mobilizon-calendar-mirror.service";
    };
  };

  # SSH access
  services.openssh = {
    enable = true;

#    listenAddresses = [
#      { addr = "192.168.32.66"; port = 22; }
#    ];

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  # User account
  users.users.bernhard = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFVU78kh0cC0uHMnWeJnbOpNVoHD+8/b162laGytaCnr xro@realraum.at"
    ];
  };

  # System state version
  system.stateVersion = "25.11";
}

