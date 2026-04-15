{
  checks,
  lib,
  nixos,
  pkgs,
  ...
}:
let
  expectOrdered =
    label: first: second: text:
    let
      parts = lib.splitString first text;
      afterFirst = if builtins.length parts > 1 then lib.concatStringsSep first (lib.tail parts) else "";
    in
    if afterFirst != "" && lib.hasInfix second afterFirst then
      true
    else
      throw "${label}: expected ${builtins.toJSON first} to appear before ${builtins.toJSON second}";

  helperWithCustomExecPaths = pkgs.callPackage ../../helpers/cloister-netns {
    allowedNamespaces = [
      "vpn"
      "dev"
    ];
    enforceExecAllowlist = false;
    allowedExecPaths = [
      "/run/current-system/sw/bin/custom-launcher"
      "/opt/cloister/bin/helper"
    ];
    requiredGroup = "cloister-netns";
  };

  eval = nixos.netns {
    cloister-netns = {
      enable = true;
      expectedNamespaces = [
        "dev"
        "lan"
      ];
      networks = {
        dev.localhost.allowedPorts = [ 3000 ];
        lan.lan.allowedRanges = [ "192.168.1.0/24" ];
      };
    };
  };

  missingNamespace = nixos.netns {
    cloister-netns = {
      enable = true;
      allowedNamespaces = [ "vpn" ];
      expectedNamespaces = [ "missing" ];
    };
  };

  noNamespaces = nixos.netns {
    cloister-netns.enable = true;
  };

  customGroup = nixos.netns {
    cloister-netns = {
      enable = true;
      group = "sandboxers";
      allowedNamespaces = [ "vpn" ];
    };
  };

  invalidLocalhostPool = nixos.netns {
    cloister-netns = {
      enable = true;
      allowedNamespaces = [ "vpn" ];
      addressPools.localhost = "bad";
    };
  };

  localhostPoolExhausted = nixos.netns {
    cloister-netns = {
      enable = true;
      addressPools.localhost = "172.30.0.0/30";
      networks = {
        a.localhost = { };
        b.localhost = { };
      };
    };
  };

  invalidLanRange = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.lan.lan.allowedRanges = [ "not-a-cidr" ];
    };
  };

  ifnameTooLong = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.abcdefghijkl.localhost = { };
    };
  };

  isolatedNoDns = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.offline = {
        isolated = true;
        dns.nameservers = [ "1.1.1.1" ];
      };
    };
  };

  multipleTypes = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.mixed = {
        isolated = true;
        localhost = { };
      };
    };
  };

  wgInvalidAddress = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn.wireguard = {
        privateKeyFile = pkgs.writeText "wg-private-key" "private";
        address = [ "bad-address" ];
        peers = [
          {
            publicKey = "public";
            endpoint = "vpn.example:51820";
          }
        ];
      };
    };
  };

  lanPoolExhausted = nixos.netns {
    cloister-netns = {
      enable = true;
      addressPools.lan = "172.29.0.0/30";
      networks = {
        alpha.lan = { };
        beta.lan = { };
      };
    };
  };

  invalidLanPool = nixos.netns {
    cloister-netns = {
      enable = true;
      allowedNamespaces = [ "vpn" ];
      addressPools.lan = "bad";
    };
  };

  invalidLocalhostPoolPrefix = nixos.netns {
    cloister-netns = {
      enable = true;
      allowedNamespaces = [ "vpn" ];
      addressPools.localhost = "172.30.0.0/31";
    };
  };

  orderedPairsEval = nixos.netns {
    cloister-netns = {
      enable = true;
      networks = {
        zeta.localhost = { };
        alpha.localhost = { };
        gamma.lan = { };
        beta.lan = { };
      };
    };
  };

  dnsFile = pkgs.writeText "cloister-netns-dns" ''
    1.1.1.1, 8.8.8.8
    9.9.9.9
  '';

  wgAddressFile = pkgs.writeText "cloister-netns-wg-address" "10.23.0.2/32\n";
  wgPublicKeyFile = pkgs.writeText "cloister-netns-wg-pub" "public-from-file\n";
  wgEndpointFile = pkgs.writeText "cloister-netns-wg-endpoint" "vpn.example:51820\n";

  fileBackedInputsEval = nixos.netns {
    cloister-netns = {
      enable = true;
      firewall.autoOpenLocalhostPorts = false;
      enforceExecAllowlist = false;
      allowedExecPaths = [
        "/run/current-system/sw/bin/custom-launcher"
        "/opt/cloister/bin/helper"
      ];
      networks = {
        vpn = {
          wireguard = {
            privateKeyFile = pkgs.writeText "wg-private-key-file-backed" "private\n";
            addressFile = wgAddressFile;
            mtu = 1420;
            peers = [
              {
                publicKeyFile = wgPublicKeyFile;
                endpointFile = wgEndpointFile;
                persistentKeepalive = 21;
              }
            ];
          };
          dns.nameserversFile = dnsFile;
        };
        dev.localhost.allowedPorts = [ 4000 ];
      };
    };
  };

  isolatedEval = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.offline.isolated = true;
    };
  };

  wgAutoHostnameEval = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn = {
        wireguard = {
          privateKeyFile = pkgs.writeText "wg-private-key-auto-host" "private\n";
          address = [ "10.42.0.2/32" ];
          peers = [
            {
              publicKey = "public";
              endpoint = "vpn.example:51820";
            }
          ];
        };
      };
    };
  };

  wgAutoIpEval = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn = {
        wireguard = {
          privateKeyFile = pkgs.writeText "wg-private-key-auto-ip" "private\n";
          address = [ "10.43.0.2/32" ];
          peers = [
            {
              publicKey = "public";
              endpoint = "203.0.113.10:51820";
            }
          ];
        };
      };
    };
  };

  wgForcedWaitEval = nixos.netns {
    cloister-netns = {
      enable = true;
      startup.waitForNetworkOnline = true;
      networks.vpn = {
        wireguard = {
          privateKeyFile = pkgs.writeText "wg-private-key-force-wait" "private\n";
          address = [ "10.44.0.2/32" ];
          peers = [
            {
              publicKey = "public";
              endpoint = "203.0.113.11:51820";
            }
          ];
        };
      };
    };
  };

  wgForcedNoWaitEval = nixos.netns {
    cloister-netns = {
      enable = true;
      startup.waitForNetworkOnline = false;
      networks.vpn = {
        wireguard = {
          privateKeyFile = pkgs.writeText "wg-private-key-force-no-wait" "private\n";
          address = [ "10.45.0.2/32" ];
          peers = [
            {
              publicKey = "public";
              endpoint = "vpn.example:51820";
            }
          ];
        };
      };
    };
  };

  duplicateAddressEval = nixos.netns {
    cloister-netns = {
      enable = true;
      addressPools.localhost = "172.30.0.0/30";
      addressPools.lan = "172.30.0.0/30";
      networks = {
        alpha.localhost = { };
        beta.lan = { };
      };
    };
  };

  dnsConflict = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn = {
        wireguard = {
          privateKeyFile = pkgs.writeText "wg-private-key-dns-conflict" "private\n";
          address = [ "10.0.0.2/32" ];
          peers = [
            {
              publicKey = "public";
              endpoint = "vpn.example:51820";
            }
          ];
        };
        dns = {
          nameservers = [ "1.1.1.1" ];
          nameserversFile = dnsFile;
        };
      };
    };
  };

  wgAddressConflict = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn.wireguard = {
        privateKeyFile = pkgs.writeText "wg-private-key-address-conflict" "private\n";
        address = [ "10.0.0.2/32" ];
        addressFile = wgAddressFile;
        peers = [
          {
            publicKey = "public";
            endpoint = "vpn.example:51820";
          }
        ];
      };
    };
  };

  peerKeyConflict = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn.wireguard = {
        privateKeyFile = pkgs.writeText "wg-private-key-peer-conflict" "private\n";
        address = [ "10.0.0.2/32" ];
        peers = [
          {
            publicKey = "public";
            publicKeyFile = wgPublicKeyFile;
            endpoint = "vpn.example:51820";
          }
        ];
      };
    };
  };

  peerEndpointConflict = nixos.netns {
    cloister-netns = {
      enable = true;
      networks.vpn.wireguard = {
        privateKeyFile = pkgs.writeText "wg-private-key-endpoint-conflict" "private\n";
        address = [ "10.0.0.2/32" ];
        peers = [
          {
            publicKey = "public";
            endpoint = "vpn.example:51820";
            endpointFile = wgEndpointFile;
          }
        ];
      };
    };
  };

  orderedPairsServices = orderedPairsEval.config.systemd.services;
  orderedAlphaStart =
    builtins.readFile
      orderedPairsServices."cloister-netns-alpha".serviceConfig.ExecStart;
  orderedZetaStart =
    builtins.readFile
      orderedPairsServices."cloister-netns-zeta".serviceConfig.ExecStart;
  orderedBetaStart =
    builtins.readFile
      orderedPairsServices."cloister-netns-beta".serviceConfig.ExecStart;
  orderedGammaStart =
    builtins.readFile
      orderedPairsServices."cloister-netns-gamma".serviceConfig.ExecStart;
  evalServices = eval.config.systemd.services;
  evalDevStart = builtins.readFile evalServices."cloister-netns-dev".serviceConfig.ExecStart;
  evalLanStart = builtins.readFile evalServices."cloister-netns-lan".serviceConfig.ExecStart;
  fileBackedServices = fileBackedInputsEval.config.systemd.services;
  fileBackedVpnStart =
    builtins.readFile
      fileBackedServices."cloister-netns-vpn".serviceConfig.ExecStart;
  isolatedService = isolatedEval.config.systemd.services."cloister-netns-offline";
  autoHostnameService = wgAutoHostnameEval.config.systemd.services."cloister-netns-vpn";
  autoIpService = wgAutoIpEval.config.systemd.services."cloister-netns-vpn";
  forcedWaitService = wgForcedWaitEval.config.systemd.services."cloister-netns-vpn";
  forcedNoWaitService = wgForcedNoWaitEval.config.systemd.services."cloister-netns-vpn";
  helperDrvAttrs = helperWithCustomExecPaths.drvAttrs or { };
in
checks.mkCheck "test-cloister-netns" [
  (checks.expectTrue "netns wrapper configured" (eval.config.security.wrappers ? "cloister-netns"))
  (checks.expectTrue "localhost service exists" (eval.config.systemd.services ? "cloister-netns-dev"))
  (checks.expectTrue "lan service exists" (eval.config.systemd.services ? "cloister-netns-lan"))
  (checks.expectEq "netns wrapper uses restrictive permissions" "u+rx,g+rx,o-rwx"
    eval.config.security.wrappers.cloister-netns.permissions
  )
  (checks.expectEq "netns wrapper uses default authorization group" "cloister-netns"
    eval.config.security.wrappers.cloister-netns.group
  )
  (checks.expectEq "firewall interface opened for localhost ports" [
    3000
  ] eval.config.networking.firewall.interfaces."veth-dev".allowedTCPPorts)
  (checks.expectEq "firewall interface opens UDP localhost ports too" [
    3000
  ] eval.config.networking.firewall.interfaces."veth-dev".allowedUDPPorts)
  (checks.expectEq "lan enables ip forwarding" 1 eval.config.boot.kernel.sysctl."net.ipv4.ip_forward")
  (checks.expectContains "ordered localhost host address allocation is deterministic"
    "ip addr add 172.30.0.1/30 dev veth-alpha"
    orderedAlphaStart
  )
  (checks.expectContains "ordered localhost next slot is deterministic"
    "ip addr add 172.30.0.5/30 dev veth-zeta"
    orderedZetaStart
  )
  (checks.expectContains "ordered lan host address allocation is deterministic"
    "ip addr add 172.29.0.1/30 dev veth-beta"
    orderedBetaStart
  )
  (checks.expectContains "ordered lan next slot is deterministic"
    "ip addr add 172.29.0.5/30 dev veth-gamma"
    orderedGammaStart
  )
  (checks.expectContains "localhost disables host-side IPv6 on the veth"
    "sysctl -w net.ipv6.conf.veth-dev.disable_ipv6=1"
    evalDevStart
  )
  (checks.expectContains "localhost applies a generated nft ruleset" "nft -f /nix/store/"
    evalDevStart
  )
  (checks.expectContains "lan applies a generated nft ruleset" "nft -f /nix/store/" evalLanStart)
  (checks.expectEq "localhost service skips network-online target in auto mode" [ ] (
    evalServices."cloister-netns-dev".after or [ ]
  ))
  (checks.expectEq "lan service skips network-online target in auto mode" [ ] (
    evalServices."cloister-netns-lan".after or [ ]
  ))
  (checks.expectEq "isolated service skips network-online target" [ ] (isolatedService.after or [ ]))
  (checks.expectEq "wireguard hostname endpoint waits for network-online in auto mode" [
    "network-online.target"
  ] (autoHostnameService.after or [ ]))
  (checks.expectEq "wireguard endpointFile waits for network-online in auto mode" [
    "network-online.target"
  ] (fileBackedServices."cloister-netns-vpn".after or [ ]))
  (checks.expectEq "wireguard literal IP endpoint skips network-online in auto mode" [ ] (
    autoIpService.after or [ ]
  ))
  (checks.expectEq "wireguard explicit wait forces network-online target" [
    "network-online.target"
  ] (forcedWaitService.after or [ ]))
  (checks.expectEq "wireguard explicit no-wait skips network-online target" [ ] (
    forcedNoWaitService.after or [ ]
  ))
  (checks.expectEq "custom authorization group is honored" "sandboxers"
    customGroup.config.security.wrappers.cloister-netns.group
  )
  (checks.expectTrue "custom authorization group is declared" (
    customGroup.config.users.groups ? "sandboxers"
  ))
  (checks.expectFalse "autoOpenLocalhostPorts can disable firewall integration" (
    fileBackedInputsEval.config.networking.firewall.interfaces ? "veth-dev"
  ))
  (checks.expectContains "nameserversFile content is rendered into service" ''echo "nameserver $d"''
    fileBackedVpnStart
  )
  (checks.expectContains "wireguard addressFile is consumed in service"
    "WG_ADDR=\"$(tr -d '\\n' < /nix/store/"
    fileBackedVpnStart
  )
  (checks.expectContains "wireguard publicKeyFile is consumed in service"
    "PUBKEY=\"$(tr -d '\\n' < /nix/store/"
    fileBackedVpnStart
  )
  (checks.expectContains "wireguard endpointFile is consumed in service"
    "ENDPOINT=\"$(tr -d '\\n' < /nix/store/"
    fileBackedVpnStart
  )
  (expectOrdered "wireguard resolv.conf is created before endpoint configuration"
    "install -d -m 0711 /etc/netns"
    "wg set wg-vpn private-key"
    fileBackedVpnStart
  )
  (expectOrdered "wireguard endpoint setup happens after namespace DNS exists"
    "/etc/netns/vpn/resolv.conf"
    ''wg set wg-vpn "''${WG_ARGS[@]}"''
    fileBackedVpnStart
  )
  (checks.expectContains "wireguard persistentKeepalive is rendered" "persistent-keepalive 21"
    fileBackedVpnStart
  )
  (checks.expectContains "wireguard mtu is rendered" "link set wg-vpn mtu 1420" fileBackedVpnStart)
  (checks.expectContains "allowed exec path list is embedded in helper package"
    "/run/current-system/sw/bin/custom-launcher"
    helperDrvAttrs.CLOISTER_NETNS_ALLOWED_EXEC_PATHS
  )
  (checks.expectContains "second allowed exec path is embedded in helper package"
    "/opt/cloister/bin/helper"
    helperDrvAttrs.CLOISTER_NETNS_ALLOWED_EXEC_PATHS
  )
  (checks.expectAssertionMessage "expected namespace mismatch fails" missingNamespace.assertions
    "expectedNamespaces contains names not in networks or allowedNamespaces"
  )
  (checks.expectAssertionMessage "enable requires namespaces" noNamespaces.assertions
    "cloister-netns is enabled but no namespaces are configured"
  )
  (checks.expectAssertionMessage "invalid localhost pool is rejected" invalidLocalhostPool.assertions
    "addressPools.localhost must be valid IPv4 CIDR notation"
  )
  (checks.expectAssertionMessage "localhost pool exhaustion is rejected"
    localhostPoolExhausted.assertions
    "localhost address pool exhausted"
  )
  (checks.expectAssertionMessage "lan pool validation is rejected" invalidLanPool.assertions
    "addressPools.lan must be valid IPv4 CIDR notation"
  )
  (checks.expectAssertionMessage "localhost pool prefix must allow /30 allocation"
    invalidLocalhostPoolPrefix.assertions
    "addressPools.localhost prefix must be <= 30"
  )
  (checks.expectAssertionMessage "lan pool exhaustion is rejected" lanPoolExhausted.assertions
    "lan address pool exhausted"
  )
  (checks.expectAssertionMessage "invalid lan CIDR is rejected" invalidLanRange.assertions
    "lan.allowedRanges contains invalid CIDR notation"
  )
  (checks.expectAssertionMessage "veth interface names must stay short" ifnameTooLong.assertions
    "veth interface name"
  )
  (checks.expectAssertionMessage "isolated networks reject DNS" isolatedNoDns.assertions
    "isolated networks have no connectivity"
  )
  (checks.expectAssertionMessage "each namespace chooses one network type" multipleTypes.assertions
    "exactly one of wireguard, localhost, lan, or isolated must be set"
  )
  (checks.expectAssertionMessage "wireguard addresses must use CIDR" wgInvalidAddress.assertions
    "wireguard address entries must be in CIDR notation"
  )
  (checks.expectAssertionMessage "dns nameservers and file are mutually exclusive"
    dnsConflict.assertions
    "nameservers and nameserversFile are mutually exclusive"
  )
  (checks.expectAssertionMessage "wireguard address and addressFile are mutually exclusive"
    wgAddressConflict.assertions
    "address and addressFile are mutually exclusive"
  )
  (checks.expectAssertionMessage "wireguard peer public key sources are exclusive"
    peerKeyConflict.assertions
    "exactly one of publicKey or publicKeyFile"
  )
  (checks.expectAssertionMessage "wireguard peer endpoint sources are exclusive"
    peerEndpointConflict.assertions
    "endpoint and endpointFile are mutually exclusive"
  )
  (checks.expectAssertionMessage "duplicate host addresses are rejected"
    duplicateAddressEval.assertions
    "duplicate host addresses across namespaces"
  )
  (checks.expectAssertionMessage "duplicate namespace addresses are rejected"
    duplicateAddressEval.assertions
    "duplicate namespace addresses across namespaces"
  )
]
