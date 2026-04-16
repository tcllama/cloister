{ pkgs }:
let
  webRoot = pkgs.writeTextDir "index.html" "hello from host\n";
  inspectNetns = pkgs.writeShellScriptBin "cloister-netns-inspect" ''
    set -eu
    grep -E '^(NoNewPrivs|Cap(Inh|Prm|Eff|Bnd|Amb)):' /proc/self/status
  '';
in
pkgs.testers.runNixOSTest (_: {
  name = "cloister-runtime-netns";

  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation.cores = 2;

      imports = [ ../../modules/cloister-netns ];

      users.users.tester = {
        isNormalUser = true;
        extraGroups = [ "cloister-netns" ];
      };

      users.users.outsider = {
        isNormalUser = true;
        extraGroups = [ ];
      };

      cloister-netns = {
        enable = true;
        enforceExecAllowlist = true;
        allowedExecPaths = [
          "${pkgs.curl}/bin/curl"
          "${inspectNetns}/bin/cloister-netns-inspect"
          "${pkgs.iproute2}/bin/ip"
        ];
        networks = {
          dev.localhost.allowedPorts = [ 4000 ];
          lanonly.lan.allowedRanges = [ "192.168.0.0/16" ];
        };
      };

      systemd.services.localhost-http = {
        description = "HTTP server for cloister-netns runtime test";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.python3}/bin/python -m http.server 4000 --bind 127.0.0.1 --directory ${webRoot}";
          Restart = "always";
        };
      };
    };

  testScript = ''
    ${builtins.readFile ./lib.py}

    start_all()

    machine.wait_for_unit("cloister-netns-dev.service")
    machine.wait_for_unit("cloister-netns-lanonly.service")
    machine.wait_for_unit("localhost-http.service")
    machine.wait_until_succeeds("ip netns list | grep -F dev")
    machine.wait_until_succeeds("ip netns list | grep -F lanonly")

    machine.succeed(
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'grep -F host.internal /etc/netns/dev/hosts'"
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${pkgs.iproute2}/bin/ip route'",
        "default via 172.30.0.1",
        "dev netns has expected default route",
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${pkgs.curl}/bin/curl -fsS http://172.30.0.1:4000/'",
        "hello from host",
        "dev netns can reach host service",
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${inspectNetns}/bin/cloister-netns-inspect'",
        "NoNewPrivs:\t1",
        "dev netns enables no-new-privileges",
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${inspectNetns}/bin/cloister-netns-inspect'",
        "CapInh:\t0000000000000000",
        "dev netns clears inheritable capabilities",
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${inspectNetns}/bin/cloister-netns-inspect'",
        "CapPrm:\t0000000000000000",
        "dev netns clears permitted capabilities",
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${inspectNetns}/bin/cloister-netns-inspect'",
        "CapEff:\t0000000000000000",
        "dev netns clears effective capabilities",
    )
    assert_contains(
        machine,
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${inspectNetns}/bin/cloister-netns-inspect'",
        "CapAmb:\t0000000000000000",
        "dev netns clears ambient capabilities",
    )
    machine.fail(
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${pkgs.runtimeShell} -lc true'"
    )
    machine.fail(
        "${pkgs.util-linux}/bin/runuser -u outsider -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${pkgs.iproute2}/bin/ip route'"
    )
    machine.fail(
        "/run/wrappers/bin/cloister-netns --netns dev -- ${pkgs.iproute2}/bin/ip route"
    )
    machine.fail("ip -6 addr show dev veth-dev | grep -F \"inet6 \"")
    machine.fail("ip -6 addr show dev veth-lanonly | grep -F \"inet6 \"")
    machine.fail(
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns dev -- ${pkgs.iproute2}/bin/ip -6 addr show dev veth-dev-ns | grep -F \"inet6 \"'"
    )
    machine.fail(
        "${pkgs.util-linux}/bin/runuser -u tester -- ${pkgs.runtimeShell} -lc "
        + "'/run/wrappers/bin/cloister-netns --netns lanonly -- ${pkgs.iproute2}/bin/ip -6 addr show dev veth-lanonly-ns | grep -F \"inet6 \"'"
    )
  '';
})
