{
  checks,
  hm,
  ...
}:
let
  eval = hm {
    cloister = {
      enable = true;
      sandboxes = {
        hard.preset = "hardened";
        dev.preset = "developer";
        gui = {
          preset = "gui";
          gui.wayland.enable = false;
        };
        chromium.preset = "chromium";
      };
    };
  };

  overrideEval = hm {
    cloister = {
      enable = true;
      sandboxes = {
        hard = {
          preset = "hardened";
          network.enable = true;
          validators.enable = false;
        };
        dev = {
          preset = "developer";
          git.enable = false;
          dbus.portal.notifications = false;
        };
        gui = {
          preset = "gui";
          dbus.enable = false;
          dbus.portal.notifications = false;
          gui.x11.enable = true;
        };
        chromium = {
          preset = "chromium";
          audio.pipewire.pulseOnly = false;
          audio.pipewire.filters.enable = false;
          sandbox.seccomp.allowChromiumSandbox = false;
        };
      };
    };
  };

  plainEval = hm {
    cloister = {
      enable = true;
      sandboxes.plain = { };
    };
  };

  inherit (eval.config.cloister) sandboxes;
  overrideSandboxes = overrideEval.config.cloister.sandboxes;
  plainSandbox = plainEval.config.cloister.sandboxes.plain;
in
checks.mkCheck "test-cloister-presets" [
  (checks.expectFalse "hardened disables network" sandboxes.hard.network.enable)
  (checks.expectTrue "hardened enables validators" sandboxes.hard.validators.enable)
  (checks.expectFalse "hardened disables ssh" sandboxes.hard.ssh.enable)
  (checks.expectFalse "hardened disables dbus" sandboxes.hard.dbus.enable)
  (checks.expectTrue "developer enables git" sandboxes.dev.git.enable)
  (checks.expectTrue "developer enables notifications portal default" sandboxes.dev.dbus.portal.notifications)
  (checks.expectTrue "developer enables ssh" sandboxes.dev.ssh.enable)
  (checks.expectFalse "gui override beats preset default" sandboxes.gui.gui.wayland.enable)
  (checks.expectTrue "gui preset enables dbus" sandboxes.gui.dbus.enable)
  (checks.expectTrue "gui preset enables notifications portal" sandboxes.gui.dbus.portal.notifications)
  (checks.expectTrue "chromium enables pulseOnly" sandboxes.chromium.audio.pipewire.pulseOnly)
  (checks.expectTrue "chromium enables seccomp chromium mode" sandboxes.chromium.sandbox.seccomp.allowChromiumSandbox)
  (checks.expectTrue "chromium enables filtered pipewire" sandboxes.chromium.audio.pipewire.enable)
  (checks.expectTrue "hardened override can re-enable network" overrideSandboxes.hard.network.enable)
  (checks.expectFalse "hardened override can disable validators" overrideSandboxes.hard.validators.enable)
  (checks.expectFalse "developer override can disable git" overrideSandboxes.dev.git.enable)
  (checks.expectFalse "developer override can disable portal notifications" overrideSandboxes.dev.dbus.portal.notifications)
  (checks.expectFalse "gui override can disable dbus" overrideSandboxes.gui.dbus.enable)
  (checks.expectTrue "gui override can enable x11" overrideSandboxes.gui.gui.x11.enable)
  (checks.expectFalse "chromium override can disable pulseOnly" overrideSandboxes.chromium.audio.pipewire.pulseOnly)
  (checks.expectFalse "chromium override can disable chromium seccomp mode" overrideSandboxes.chromium.sandbox.seccomp.allowChromiumSandbox)
  (checks.expectFalse "plain sandbox stays inert for validators" plainSandbox.validators.enable)
  (checks.expectFalse "plain sandbox keeps dbus disabled" plainSandbox.dbus.enable)
]
