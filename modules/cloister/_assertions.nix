# Assertion builder: produces the list of assertion attrsets for a sandbox.
{
  lib,
  name,
  sCfg,
  duplicateDests,
  dirTmpfsOverlap,
  duplicateLinks,
  duplicateManagedFiles,
  unsafePaths,
  matchedDangerousPaths,
  overriddenEnvKeys,
  overriddenDbusKeys,
  overriddenGuiKeys,
  overriddenPortalKeys,
  blockedPassthroughEnv,
  invalidPassthroughEnv,
  guiEnabled,
  hasPerDirBinds,
  normalizeCopyDest,
  sandboxNames,
}:
let
  workerBrokerCfg = sCfg.workerBroker;
  isRelativeDescendantPath =
    path: path != "" && !lib.hasPrefix "/" path && normalizeCopyDest path == path;
  isAbsoluteTraversalFreeHostPath =
    path:
    path != ""
    && lib.hasPrefix "/" path
    && !(builtins.any (segment: segment == "..") (lib.splitString "/" path));
  invalidAvailableDelegatedMountKeys = builtins.filter (
    mountName: !isRelativeDescendantPath mountName
  ) (lib.attrNames workerBrokerCfg.availableDelegatedPerDirMounts);
  invalidReferencedDelegatedMountKeys = lib.filterAttrs (
    _: profile:
    builtins.any (mountName: !isRelativeDescendantPath mountName) (
      lib.attrNames profile.delegatedPerDirMounts
    )
  ) workerBrokerCfg.spawnableProfiles;
  invalidSpawnableProfiles = lib.filterAttrs (
    _: profile: !(builtins.elem profile.sandbox sandboxNames)
  ) workerBrokerCfg.spawnableProfiles;
  invalidDelegatedMountProfiles = lib.filterAttrs (
    _: profile:
    builtins.any (
      mountName: !(builtins.hasAttr mountName workerBrokerCfg.availableDelegatedPerDirMounts)
    ) (lib.attrNames profile.delegatedPerDirMounts)
  ) workerBrokerCfg.spawnableProfiles;
  invalidSpawnableProfileMessages = lib.concatMapStringsSep "; " (
    profileName:
    let
      profile = invalidSpawnableProfiles.${profileName};
    in
    "workerBroker.spawnableProfiles.${profileName}.sandbox references unknown sandbox '${profile.sandbox}'"
  ) (lib.attrNames invalidSpawnableProfiles);
  invalidDelegatedMountMessages = lib.concatMapStringsSep "; " (
    profileName:
    let
      profile = workerBrokerCfg.spawnableProfiles.${profileName};
      invalidMounts = builtins.filter (
        mountName: !(builtins.hasAttr mountName workerBrokerCfg.availableDelegatedPerDirMounts)
      ) (lib.attrNames profile.delegatedPerDirMounts);
    in
    lib.concatMapStringsSep "; " (
      mountName:
      "workerBroker.spawnableProfiles.${profileName}.delegatedPerDirMounts references unknown availableDelegatedPerDirMounts entry '${mountName}'"
    ) invalidMounts
  ) (lib.attrNames invalidDelegatedMountProfiles);
  invalidDelegatedMountSubPaths = lib.filterAttrs (
    _: mount:
    mount.subPath != null
    && (
      mount.subPath == ""
      || lib.hasPrefix "/" mount.subPath
      || normalizeCopyDest mount.subPath != mount.subPath
    )
  ) workerBrokerCfg.availableDelegatedPerDirMounts;
  invalidDelegatedMountBasePaths = lib.filterAttrs (
    _: mount: !isAbsoluteTraversalFreeHostPath mount.path
  ) workerBrokerCfg.availableDelegatedPerDirMounts;
  invalidDelegatedMountSubPathMessages = lib.concatMapStringsSep "; " (
    mountName:
    "workerBroker.availableDelegatedPerDirMounts.${mountName}.subPath must be a relative descendant path without traversal"
  ) (lib.attrNames invalidDelegatedMountSubPaths);
  invalidDelegatedMountBasePathMessages = lib.concatMapStringsSep "; " (
    mountName:
    "workerBroker.availableDelegatedPerDirMounts.${mountName}.path must be an absolute traversal-free host path"
  ) (lib.attrNames invalidDelegatedMountBasePaths);
  inherit (workerBrokerCfg) invalidGeneratedLauncherNames;
  generatedLauncherNames = lib.attrNames workerBrokerCfg.generatedLaunchers;
  generatedLauncherAliasCollisions = lib.intersectLists generatedLauncherNames (
    lib.attrNames sCfg.registry.aliases
  );
  generatedLauncherFunctionCollisions = lib.intersectLists generatedLauncherNames (
    lib.attrNames sCfg.registry.functions
  );
  generatedLauncherCommandCollisions = lib.intersectLists generatedLauncherNames sCfg.registry.commands;
  generatedLauncherExtraCommandCollisions = lib.intersectLists generatedLauncherNames sCfg.registry.extraCommands;
  invalidDelegatedMountKeyMessages = lib.concatStringsSep "; " (
    map (
      _: "workerBroker availableDelegatedPerDirMounts keys must be sandbox-relative descendant paths"
    ) (invalidAvailableDelegatedMountKeys ++ lib.attrNames invalidReferencedDelegatedMountKeys)
  );
in
[
  {
    assertion = sCfg.sandbox.bindWorkingDirectory || !hasPerDirBinds;
    message = "cloister.sandboxes.${name}: sandbox.bindWorkingDirectory = false is incompatible with sandbox.extraBinds.perDir. Per-directory isolation requires the working directory to be detected.";
  }
  {
    assertion = builtins.all (
      bind: bind.dest != "" && !lib.hasPrefix "/" bind.dest && normalizeCopyDest bind.dest == bind.dest
    ) sCfg.sandbox.extraBinds.managedFileBind;
    message = "cloister.sandboxes.${name}: all extraBinds.managedFileBind dest paths must be home-relative descendant paths without traversal";
  }
  {
    assertion = builtins.all (
      cf: lib.hasPrefix "$HOME/" (normalizeCopyDest cf.dest)
    ) sCfg.sandbox.copyFiles;
    message = "cloister.sandboxes.${name}: all copyFiles dest paths must start with $HOME/ (after normalization)";
  }
  (
    let
      invalidModes = builtins.filter (
        cf: builtins.match "^[0-7]{3,4}$" cf.mode == null
      ) sCfg.sandbox.copyFiles;
    in
    {
      assertion = invalidModes == [ ];
      message = "cloister.sandboxes.${name}: copyFiles contains invalid mode values: ${
        lib.concatMapStringsSep ", " (cf: "'${cf.mode}' (for ${cf.dest})") invalidModes
      }. Modes must be 3 or 4 octal digits (e.g. '0644', '755').";
    }
  )
  {
    assertion =
      sCfg.gui.scaleFactor == null
      || (
        sCfg.gui.scaleFactor > 0.0
        && (
          let
            scaled = sCfg.gui.scaleFactor * 4.0;
          in
          builtins.floor scaled == builtins.ceil scaled
        )
      );
    message = "cloister.sandboxes.${name}: gui.scaleFactor must be a positive value in 0.25 increments (e.g. 1.0, 1.25, 1.5, 1.75, 2.0).";
  }
  {
    assertion = duplicateDests == [ ];
    message = "cloister.sandboxes.${name}: duplicate bind mount destinations: ${lib.concatStringsSep ", " duplicateDests}";
  }
  {
    assertion = dirTmpfsOverlap == [ ];
    message = "cloister.sandboxes.${name}: paths appear in both sandbox dirs and tmpfs: ${lib.concatStringsSep ", " dirTmpfsOverlap}";
  }
  {
    assertion = duplicateLinks == [ ];
    message = "cloister.sandboxes.${name}: duplicate symlink destinations: ${lib.concatStringsSep ", " duplicateLinks}";
  }
  {
    assertion = duplicateManagedFiles == [ ];
    message = "cloister.sandboxes.${name}: duplicate managed file destinations: ${lib.concatStringsSep ", " duplicateManagedFiles}";
  }
  {
    assertion = overriddenEnvKeys == [ ];
    message = "cloister.sandboxes.${name}: sandbox.env sets keys that are computed and cannot be overridden: ${lib.concatStringsSep ", " overriddenEnvKeys}";
  }
  {
    assertion = overriddenDbusKeys == [ ];
    message = "cloister.sandboxes.${name}: sandbox.env sets keys managed by dbus and cannot be overridden when dbus is enabled: ${lib.concatStringsSep ", " overriddenDbusKeys}";
  }
  {
    assertion = overriddenGuiKeys == [ ];
    message = "cloister.sandboxes.${name}: sandbox.env sets keys managed by gui and cannot be overridden when gui is enabled: ${lib.concatStringsSep ", " overriddenGuiKeys}";
  }
  {
    assertion = overriddenPortalKeys == [ ];
    message = "cloister.sandboxes.${name}: sandbox.env sets keys managed by dbus.portal and cannot be overridden when portal is enabled: ${lib.concatStringsSep ", " overriddenPortalKeys}";
  }
  {
    assertion =
      !(builtins.any (x: x) [
        sCfg.dbus.portal.fileChooser
        sCfg.dbus.portal.openUri
        sCfg.dbus.portal.screencast
        sCfg.dbus.portal.camera
        sCfg.dbus.portal.notifications
      ])
      || sCfg.dbus.enable;
    message = "cloister.sandboxes.${name}: dbus.portal.* requires dbus.enable = true.";
  }
  {
    assertion = invalidPassthroughEnv == [ ];
    message = "cloister.sandboxes.${name}: sandbox.passthroughEnv contains invalid variable names: ${lib.concatStringsSep ", " invalidPassthroughEnv}";
  }
  {
    assertion = blockedPassthroughEnv == [ ];
    message = "cloister.sandboxes.${name}: sandbox.passthroughEnv cannot include computed/managed keys: ${lib.concatStringsSep ", " blockedPassthroughEnv}";
  }
  {
    assertion = unsafePaths == [ ];
    message = "cloister.sandboxes.${name}: bind/copy/dir/tmpfs/symlink/env paths cannot contain variable expansions ($) or newlines: ${lib.concatStringsSep ", " unsafePaths}";
  }
  {
    assertion = !sCfg.gui.desktopEntry.enable || guiEnabled;
    message = "cloister.sandboxes.${name}: gui.desktopEntry.enable requires gui.wayland.enable.";
  }
  {
    assertion = !workerBrokerCfg.enable || workerBrokerCfg.spawnableProfiles != { };
    message = "cloister.sandboxes.${name}: workerBroker.enable requires at least one workerBroker.spawnableProfiles entry.";
  }
  {
    assertion = !workerBrokerCfg.enable || sCfg.sandbox.bindWorkingDirectory;
    message = "cloister.sandboxes.${name}: workerBroker.enable requires sandbox.bindWorkingDirectory = true.";
  }
  {
    assertion = invalidSpawnableProfiles == { };
    message = "cloister.sandboxes.${name}: ${invalidSpawnableProfileMessages}.";
  }
  {
    assertion = invalidDelegatedMountProfiles == { };
    message = "cloister.sandboxes.${name}: ${invalidDelegatedMountMessages}.";
  }
  {
    assertion = invalidAvailableDelegatedMountKeys == [ ] && invalidReferencedDelegatedMountKeys == { };
    message = "cloister.sandboxes.${name}: ${invalidDelegatedMountKeyMessages}.";
  }
  {
    assertion = invalidDelegatedMountSubPaths == { };
    message = "cloister.sandboxes.${name}: ${invalidDelegatedMountSubPathMessages}.";
  }
  {
    assertion = invalidDelegatedMountBasePaths == { };
    message = "cloister.sandboxes.${name}: ${invalidDelegatedMountBasePathMessages}.";
  }
  {
    assertion = invalidGeneratedLauncherNames == [ ];
    message = "cloister.sandboxes.${name}: workerBroker.spawnableProfiles keys must produce safe generated launcher names: ${
      lib.concatStringsSep ", " (
        map (launcherName: lib.removePrefix "clb-" launcherName) invalidGeneratedLauncherNames
      )
    }";
  }
  {
    assertion = generatedLauncherAliasCollisions == [ ];
    message = "cloister.sandboxes.${name}: generated worker broker launcher names collide with registry.aliases: ${lib.concatStringsSep ", " generatedLauncherAliasCollisions}";
  }
  {
    assertion = generatedLauncherFunctionCollisions == [ ];
    message = "cloister.sandboxes.${name}: generated worker broker launcher names collide with registry.functions: ${lib.concatStringsSep ", " generatedLauncherFunctionCollisions}";
  }
  {
    assertion = generatedLauncherCommandCollisions == [ ];
    message = "cloister.sandboxes.${name}: generated worker broker launcher names collide with registry.commands: ${lib.concatStringsSep ", " generatedLauncherCommandCollisions}";
  }
  {
    assertion = generatedLauncherExtraCommandCollisions == [ ];
    message = "cloister.sandboxes.${name}: generated worker broker launcher names collide with registry.extraCommands: ${lib.concatStringsSep ", " generatedLauncherExtraCommandCollisions}";
  }
  {
    assertion =
      !sCfg.gui.desktopEntry.enable || (sCfg.defaultCommand != null && sCfg.defaultCommand != [ ]);
    message = "cloister.sandboxes.${name}: gui.desktopEntry.enable requires defaultCommand to be set so the launcher does not open an interactive shell.";
  }
  {
    assertion =
      sCfg.gui.desktopEntry.execArgs == ""
      ||
        builtins.match ''
          .*['";|&
          `$].*'' sCfg.gui.desktopEntry.execArgs == null;
    message = ''cloister.sandboxes.${name}: gui.desktopEntry.execArgs must not contain shell metacharacters (', ", ;, |, &, `, $) or newlines.'';
  }
  (
    let
      dbusNamePattern = ''^([A-Za-z_][A-Za-z0-9_-]*)(\.([A-Za-z_][A-Za-z0-9_-]*))+$'';
      dbusWildcardPattern = ''^([A-Za-z_][A-Za-z0-9_-]*)(\.([A-Za-z_][A-Za-z0-9_-]*))+\.\*$'';
      validDbusName =
        n: builtins.match dbusNamePattern n != null || builtins.match dbusWildcardPattern n != null;
      allDbusNames =
        sCfg.dbus.policies.talk
        ++ sCfg.dbus.policies.own
        ++ sCfg.dbus.policies.see
        ++ lib.attrNames sCfg.dbus.policies.call
        ++ lib.attrNames sCfg.dbus.policies.broadcast;
      invalidDbusNames = builtins.filter (n: !validDbusName n) allDbusNames;
    in
    {
      assertion = !sCfg.dbus.enable || invalidDbusNames == [ ];
      message = "cloister.sandboxes.${name}: D-Bus policy names are invalid: ${lib.concatStringsSep ", " invalidDbusNames}. Names must be dot-separated well-known bus names, with optional .*.";
    }
  )
  {
    assertion = sCfg.network.namespace == null || sCfg.network.enable;
    message = "cloister.sandboxes.${name}: network.namespace requires network.enable = true so bubblewrap preserves the joined network namespace.";
  }
  {
    assertion = !sCfg.audio.pipewire.pulseOnly || sCfg.audio.pipewire.enable;
    message = "cloister.sandboxes.${name}: audio.pipewire.pulseOnly requires audio.pipewire.enable = true so Cloister can create the filtered PipeWire backend socket used by the PulseAudio proxy.";
  }
  {
    assertion = !sCfg.audio.pipewire.enable || sCfg.audio.pipewire.filters.enable;
    message = "cloister.sandboxes.${name}: audio.pipewire.enable requires audio.pipewire.filters.enable = true because unfiltered PipeWire socket forwarding is not supported.";
  }
  {
    assertion = !(sCfg.audio.pipewire.pulseOnly && sCfg.audio.pipewire.filters.videoIn);
    message = "cloister.sandboxes.${name}: audio.pipewire.pulseOnly is audio-only and does not support audio.pipewire.filters.videoIn.";
  }
  {
    assertion =
      !(sCfg.sandbox.anonymize.enable && sCfg.audio.pipewire.enable && !sCfg.audio.pipewire.pulseOnly);
    message = "cloister.sandboxes.${name}: it is not possible to anonymize a PipeWire socket. If sandbox.anonymize.enable = true and audio.pipewire.enable = true, you must also enable audio.pipewire.pulseOnly.";
  }
  {
    assertion = !sCfg.sandbox.dangerousPathWarnings || matchedDangerousPaths == [ ];
    message = lib.concatStringsSep "\n" (
      [
        "cloister.sandboxes.${name}: binds/extraBinds/managedFile contains paths that expose credentials or secrets:"
      ]
      ++ map (p: "  - ${p}") matchedDangerousPaths
      ++ [
        ""
        "These paths contain sensitive data (SSH keys, cloud credentials, keyrings, etc.)"
        "that the sandbox is designed to protect. Binding them in defeats the purpose."
        ""
        "To suppress this warning for specific paths:"
        "  cloister.sandboxes.${name}.sandbox.allowDangerousPaths = [ ${
            lib.concatMapStringsSep " " (p: ''"${p}"'') matchedDangerousPaths
          } ];"
        ""
        "To disable all dangerous path checks:"
        "  cloister.sandboxes.${name}.sandbox.dangerousPathWarnings = false;"
      ]
    );
  }
]
