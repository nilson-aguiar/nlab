# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, meta, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
        inputs.sops-nix.nixosModules.sops
    ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = meta.hostname; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    #useXkbConfig = true; # use xkb.options in tty.
  };

  # Fixes for longhorn
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
  virtualisation.docker.logDriver = "json-file";

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = /var/lib/rancher/k3s/server/token;
    extraFlags = toString ([
	    "--write-kubeconfig-mode \"0644\""
	    "--cluster-init"
	    "--disable servicelb"
	    "--disable traefik"
	    "--disable local-storage"
    ] ++ (if meta.hostname == "homelab-0" then [] else [
	      "--server https://homelab-0:6443"
    ]));
    clusterInit = (meta.hostname == "homelab-0");
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2016-04.com.open-iscsi:${meta.hostname}";
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.naguiar = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
    ];
    # Created using mkpasswd
    hashedPassword = "$y$j9T$IFtoovbNSijwmdPlKKTOi.$0GAmL7I.KoZcZcB8HuGfR4I09nXz6AVLM9ZjOSHLNVA";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqGauw0wf8t7ThqgqDi7sJTBOPcm0egwuMPJV230j82 work"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4mwQ+Bh0GitBnPeEY44A5eZr4hRKqrvmfenEsW05h12Xtbl5SL5ucWr3ZP04yN1f2NjmLjUow4SK+LaKfL3JTMkiEFyQ14pkGgc5UNXDZ7PDaAWZ6RUo4SfY+veFn9rWs3kV1cSv5W9izbOB9qyYXeDARcbf+0AzdD1/WWNx7GcfiBJ6QDWccOb+YP2YrdPRffFoRtBeS2gIjVn2KP++H7wgsUvaCVwk024f/cZEyDjntlLnfI3WVmsrp7TdQLuP2Sk2cEYTJkKzC4CpAjEf2RNgJL4Zk1I//tikHKrpXOXo7EQAU9/mck2iOks2Npx4jwHKJC96kmGxZOW+nxFxVGEabnHArxHsWhN3xsd802YD93VX2fqTnJ3TpAOPyRyMP7T5rmJ44S/kKMogQisUjgF1aca4+WhiiGm5Rek31Qst7G6HEOcQzgkz47HhyUKCZBJsacCxMmcs0wjLwf/lPJ0CEUhSFO2VKhQ5Nzkfk/70/1fgi97ircIjaGI+Vdl3NplTkeMM7BXgM4yB0ShHs9vBZa7/TwN22gJi2IQUHk4Rb+Y2SJsl6tXTmS9azsGDVme+ECSZGANka4Xs3/C5ANA5N+eW3ijfnRZbKCaDoFZc0dzDGlFWN8IKDcCLUxq6qCXvI5ji3mjPD2eHdB2Z0V0vQpBTX27bSuS1jcKVX9Q== home"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
     neovim
     k3s
     cifs-utils
     nfs-utils
     git
     sops
     age
  ];

  environment.etc = {
      "cni" = {
        source = "/var/lib/rancher/k3s/agent/etc/cni";
      };
    };

  environment.shellAliases = {
    k = "kubectl";
    vim = "nvim";
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile ="/home/naguiar/.config/sops/age/keys.txt";

    secrets = {
      "k3s/token" = { };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ 80 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}
