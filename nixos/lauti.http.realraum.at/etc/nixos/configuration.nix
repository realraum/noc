{ config, lib, pkgs, ... }:

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
    "d /srv/lauti/media 0755 root root -"
    "d /srv/lauti/themes 0755 root root -"
    "d /srv/lauti/osm 0755 root root -"
    "d /srv/lauti/data 0755 root root -"
  ];

  # Lauti service configuration with custom data path
  # Configure lauti service
  services.qemuGuest.enable = true;
  services.eintopf = {
    enable = true;

    settings = {
      LAUTI_ADMIN_EMAIL = "noc@r3.at";
      LAUTI_BASE_URL = "http://lauti.realraum.at";
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
      LAUTI_ADMIN_PASSWORD = "Ns6y39je7d3eYhmup7FSFPP6u71wPvCusYc0q4d0Io58vW3IeRgjvFT3vJ7sqh1hHXVCsNB3";
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
      ReadWritePaths = [ "/srv/lauti" ];
    };
  };

#  # Secure admin password storage
#  environment.etc."lauti-secrets".text = ''
#    LAUTI_ADMIN_PASSWORD=Ns6y39je7d3eYhmup7FSFPP6u71wPvCusYc0q4d0Io58vW3IeRgjvFT3vJ7sqh1hHXVCsNB3
#   ''; 

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

