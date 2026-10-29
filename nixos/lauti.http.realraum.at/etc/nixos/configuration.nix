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

  nodejs = pkgs.nodejs_22 or pkgs.nodejs;
  pnpm = pkgs.pnpm_10 or pkgs.pnpm;

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
      binutils
      cacert
      coreutils
      curl.dev
      gcc
      git
      gnumake
      nodejs
      openssl.dev
      pkg-config
      pnpm
      python3
      zlib.dev
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

      # Build native npm modules (node-libcurl) against Nix-provided libraries.
      export npm_config_nodedir=${lib.escapeShellArg "${nodejs}"}
      export npm_config_build_from_source=true
      export CFLAGS=${lib.escapeShellArg "-I${pkgs.curl.dev}/include"}
      export CXXFLAGS=${lib.escapeShellArg "-I${pkgs.curl.dev}/include"}
      export PKG_CONFIG_PATH=${lib.escapeShellArg "${pkgs.curl.dev}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig"}
      export NIX_CFLAGS_COMPILE=${lib.escapeShellArg "-I${pkgs.curl.dev}/include -I${pkgs.openssl.dev}/include -I${pkgs.zlib.dev}/include"}
      linkFlags=${lib.escapeShellArg "-L${pkgs.curl.out}/lib -L${pkgs.openssl.out}/lib -L${pkgs.zlib.out}/lib -Wl,-rpath,${pkgs.curl.out}/lib -Wl,-rpath,${pkgs.openssl.out}/lib -Wl,-rpath,${pkgs.zlib.out}/lib"}
      export NIX_LDFLAGS="$linkFlags"
      export LDFLAGS="$linkFlags"

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

      cd "$repoDir"
      pnpm install --frozen-lockfile
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
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
    dnsovertls = "false";
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
  ];

  # Lauti service configuration with custom data path
  # Configure lauti service
  services.qemuGuest.enable = true;
  services.eintopf = {
    enable = true;

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
  systemd.services.eintopf = {
    after = [ "srv.mount" ];
    requires = [ "srv.mount" ];
    serviceConfig = {
      EnvironmentFile= [ "/srv/lauti/env" ];  # store persistent admin pwd here
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
    description = "Clone/update grical-to-mobilizon and install its pnpm dependencies";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = mobilizonCalendarMirror.user;
      Group = mobilizonCalendarMirror.group;
      WorkingDirectory = mobilizonCalendarMirror.home;
      ExecStart = "${mobilizonCalendarMirrorUpdate}/bin/mobilizon-calendar-mirror-update";

      # Fetching and building native node modules needs more time than a run.
      TimeoutStartSec = "20min";
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
    requires = [ "mobilizon-calendar-mirror-update.service" ];
    after = [ "network-online.target" "mobilizon-calendar-mirror-update.service" ];
    path = [ nodejs pnpm pkgs.coreutils ];
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
      # not prevent the sync from running.
      ExecStart = [
        "-${pnpm}/bin/pnpm report --autoremove-deleted"
        "${pnpm}/bin/pnpm start"
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

