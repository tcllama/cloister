# JSON config generation and compiled binary package builder.
{
  pkgs,
  lib,
  bwrapLib,
  cloister-sandbox,
  name,
  sCfg,
  config,
  shellLib,
  anonymize,
  sandboxHome,
  gpuEnabled,
  seccompFilter,
  allDirs,
  managedFileDirsOverlapping,
  managedFileDirOverlap,
  noHostConfigEnv,
  guiEnv,
  portalEnv,
  computedEnv,
  staticRoBinds,
  staticRwBinds,
  dynamicBindsList,
  bindSources,
  perDirBuckets,
  dirMkdirSpecs,
  fileMkdirSpecs,
  copyFileSpecs,
  normalizedDangerousPaths,
  normalizedAllowDangerousPaths,
  dbusProxyWrapper,
  flatpakAppId,
  pipewireSocketName,
  renderedWorkerBroker,
  buildRevision,
  bubblewrap-subset-pid,
  osConfig ? null,
}:
let
  bubblewrapPackage = if anonymize then bubblewrap-subset-pid else pkgs.bubblewrap;

  pulseaudioSocketName = if sCfg.audio.pulseaudio.enable then "pulse/native" else null;

  storeRootFromEntry =
    entry:
    let
      match = builtins.match "^(/nix/store/[^/:]+)(/.*)?$" entry;
    in
    if match == null then
      null
    else
      builtins.appendContext (builtins.elemAt match 0) (builtins.getContext entry);

  storeRootsFromValue =
    value: builtins.filter (p: p != null) (map storeRootFromEntry (lib.splitString ":" value));

  imageStoreMode = sCfg.sandbox.nixStore.mode == "image-store";

  portalDesktopEnabled = builtins.any (x: x) [
    sCfg.dbus.portal.fileChooser
    sCfg.dbus.portal.openUri
    sCfg.dbus.portal.screencast
    sCfg.dbus.portal.camera
  ];

  imageStoreConfig =
    if osConfig != null && osConfig ? cloister && osConfig.cloister ? imageStore then
      osConfig.cloister.imageStore
    else
      null;

  hostGraphicsConfig =
    if osConfig == null then
      null
    else if lib.hasAttrByPath [ "hardware" "graphics" ] osConfig then
      lib.getAttrFromPath [ "hardware" "graphics" ] osConfig
    else if lib.hasAttrByPath [ "hardware" "opengl" ] osConfig then
      lib.getAttrFromPath [ "hardware" "opengl" ] osConfig
    else
      null;

  hostGpuStoreInputs =
    if hostGraphicsConfig == null then
      [ ]
    else
      lib.unique (
        lib.filter (pkg: pkg != null) (
          lib.optional (hostGraphicsConfig ? package) hostGraphicsConfig.package
          ++ lib.optional (hostGraphicsConfig ? package32) hostGraphicsConfig.package32
          ++ (hostGraphicsConfig.extraPackages or [ ])
          ++ (hostGraphicsConfig.extraPackages32 or [ ])
        )
      );

  _imageStoreConfigCheck =
    if imageStoreMode && imageStoreConfig == null then
      throw ''
        cloister.sandboxes.${name}: sandbox.nixStore.mode = "image-store" requires the NixOS
        cloister-image-store module so osConfig.cloister.imageStore is available.
      ''
    else
      null;

  storeRoots = lib.unique (lib.sort builtins.lessThan (map toString storeInputs));

  storeRootsText = lib.concatMapStringsSep " " lib.escapeShellArg storeRoots;

  storeId = builtins.hashString "sha256" (
    builtins.toJSON {
      version = 1;
      inherit (sCfg.sandbox.nixStore) mode;
      roots = storeRoots;
    }
  );

  storeImagePublishedPath =
    if imageStoreConfig == null then null else "${imageStoreConfig.base}/${storeId}.squashfs";

  storeMetaPublishedPath =
    if imageStoreConfig == null then null else "${imageStoreConfig.base}/${storeId}.json";

  storeMountPath =
    if imageStoreConfig == null then null else "${imageStoreConfig.mountBase}/${storeId}";

  storeMetaJson = builtins.toJSON {
    version = 1;
    mode = "image-store";
    inherit storeId storeRoots;
  };

  storeMeta = pkgs.writeText "cloister-image-store-${storeId}.json" "${storeMetaJson}\n";

  closureInfo = pkgs.closureInfo { rootPaths = storeRoots; };

  storeImage =
    pkgs.runCommand "cloister-image-store-${storeId}.squashfs"
      {
        nativeBuildInputs = [ pkgs.squashfsTools ];
      }
      ''
        set -eu

        root="$TMPDIR/root"
        mkdir -p "$root/nix/store"

        for path in ${storeRootsText}; do
          if [ ! -e "$path" ]; then
            echo "missing declared store root: $path" >&2
            exit 1
          fi
        done

        LC_ALL=C sort "${closureInfo}/store-paths" | while IFS= read -r path; do
          cp -a "$path" "$root/nix/store/$(basename "$path")"
        done
        cp ${storeMeta} "$root/meta.json"

        mksquashfs "$root" "$out" -noappend -all-root >/dev/null
      '';

  pipewireBackendSocketName =
    if sCfg.audio.pipewire.pulseOnly then "cloister/pipewire/${name}" else null;

  anonymizedIdentity =
    if anonymize then
      let
        match = builtins.match "^/home/([^/]+)$" sandboxHome;
      in
      if match == null then
        throw ''
          cloister.sandboxes.${name}: anonymized sandboxHome must be exactly /home/<username>, got ${sandboxHome}
        ''
      else
        builtins.elemAt match 0
    else
      null;

  pipewirePulseOnlyConfText =
    let
      anonymizedPulseOnlyProps = lib.optionalString sCfg.sandbox.anonymize.enable ''
        "context.user-name" = "${anonymizedIdentity}"
        "context.host-name" = "${anonymizedIdentity}"
      '';
      pulseOnlyQuirks =
        lib.optional (!sCfg.audio.pipewire.filters.audioOut) "block-playback-stream"
        ++ lib.optional (!sCfg.audio.pipewire.filters.audioIn) "block-record-stream"
        ++ lib.optionals (!sCfg.audio.pipewire.filters.control) [
          "block-sink-volume"
          "block-source-volume"
        ];
      pulseOnlyQuirksText =
        if pulseOnlyQuirks == [ ] then
          ""
        else
          ''
            pulse.rules = [
              {
                matches = [ { client.api = "pulse" } ]
                actions = {
                  quirks = [ ${lib.concatStringsSep " " pulseOnlyQuirks} ]
                }
              }
            ]
          '';
    in
    ''
      context.properties = {
          support.dbus = ${
            if (sCfg.dbus.enable && sCfg.audio.pipewire.dbus.enable) then "true" else "false"
          }
      ${anonymizedPulseOnlyProps}
      }
      context.spa-libs = {
          audio.convert.* = audioconvert/libspa-audioconvert
          support.*       = support/libspa-support
      }
      context.modules = [
          { name = libpipewire-module-protocol-native }
          { name = libpipewire-module-client-node }
          { name = libpipewire-module-adapter }
          { name = libpipewire-module-metadata }
          { name = libpipewire-module-protocol-pulse
              args = { }
          }
      ]
      context.exec = [ ]
      pulse.cmd = [ ]
      stream.properties = { }
      pulse.properties = {
          server.address = [ "unix:native" ]
          server.dbus-name = "org.pulseaudio.Server.cloister.${name}"
          pulse.allow-module-loading = false
      }
      ${pulseOnlyQuirksText}
    '';

  pipewirePulseOnlyConf =
    if sCfg.audio.pipewire.pulseOnly then
      pkgs.writeText "cloister-pipewire-pulse-only-${name}.conf" pipewirePulseOnlyConfText
    else
      null;

  pipewirePulseWrapperText = ''
    set -eu

    interactive=0
    if [ "''${1-}" = "--interactive" ]; then
      interactive=1
      shift
    fi

    if [ "''${1-}" != "--" ]; then
      echo "cloister pipewire wrapper: expected -- before target command" >&2
      exit 64
    fi
    shift

    if [ "$#" -eq 0 ]; then
      echo "cloister pipewire wrapper: missing target command" >&2
      exit 64
    fi

    pulse_socket="$XDG_RUNTIME_DIR/pulse/native"
    pulse_pid=""
    child_pid=""

    cleanup_pulse() {
      if [ -n "$pulse_pid" ]; then
        kill "$pulse_pid" 2>/dev/null || true
        i=0
        while kill -0 "$pulse_pid" 2>/dev/null && [ "$i" -lt 20 ]; do
          ${pkgs.coreutils}/bin/sleep 0.1
          i=$((i + 1))
        done
        kill -KILL "$pulse_pid" 2>/dev/null || true
        wait "$pulse_pid" 2>/dev/null || true
        pulse_pid=""
      fi
      ${pkgs.coreutils}/bin/rm -f "$pulse_socket"
    }

    forward_and_exit() {
      signal="$1"
      code="$2"
      if [ -n "$child_pid" ]; then
        kill "-$signal" -- "-$child_pid" 2>/dev/null || kill "$child_pid" 2>/dev/null || true
      fi
      cleanup_pulse
      exit "$code"
    }

    trap "forward_and_exit TERM \$((128 + 15))" TERM
    trap "forward_and_exit HUP \$((128 + 1))" HUP

    if [ "$interactive" -eq 1 ]; then
      trap "" INT
    else
      trap "forward_and_exit INT \$((128 + 2))" INT
    fi

    if [ ! -S "$pulse_socket" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$XDG_RUNTIME_DIR/pulse"
      ${pkgs.pipewire}/bin/pipewire-pulse &
      pulse_pid=$!
      i=0
      while [ ! -S "$pulse_socket" ] && [ "$i" -lt 20 ]; do
        if ! kill -0 "$pulse_pid" 2>/dev/null; then
          echo "cloister pipewire wrapper: pipewire-pulse exited before creating $pulse_socket" >&2
          wait "$pulse_pid" 2>/dev/null || true
          exit 1
        fi
        ${pkgs.coreutils}/bin/sleep 0.1
        i=$((i + 1))
      done
      if [ ! -S "$pulse_socket" ]; then
        echo "cloister pipewire wrapper: timed out waiting for $pulse_socket" >&2
        cleanup_pulse
        exit 1
      fi
    fi

    export PULSE_SERVER="unix:$pulse_socket"

    # Run the target in its own session so traps can signal the full process tree.
    ${pkgs.util-linux}/bin/setsid "$@" &
    child_pid=$!
    if wait "$child_pid"; then
      status=0
    else
      status=$?
    fi
    child_pid=""

    cleanup_pulse
    exit "$status"
  '';

  pipewirePulseWrapperPath =
    if sCfg.audio.pipewire.pulseCompat.enable then
      pkgs.writeShellScript "cloister-pipewire-pulse-wrapper-${name}" pipewirePulseWrapperText
    else
      null;

  envAttrs = sCfg.sandbox.env // guiEnv // portalEnv // computedEnv // noHostConfigEnv;

  symlinkTargets = map (entry: entry.target) (sCfg.sandbox.symlinks ++ sCfg.sandbox.extraSymlinks);

  storeInputs = lib.unique (
    builtins.filter (p: p != null) (
      sCfg.packages
      ++ sCfg.extraPackages
      ++ [ pkgs.tini ]
      ++ lib.optional gpuEnabled pkgs.mesa
      ++ lib.optionals gpuEnabled hostGpuStoreInputs
      ++ lib.optional sCfg.audio.pipewire.pulseOnly pkgs.pipewire
      ++ lib.optional (pipewirePulseOnlyConf != null) pipewirePulseOnlyConf
      ++ lib.optional (pipewirePulseWrapperPath != null) pipewirePulseWrapperPath
      ++ map storeRootFromEntry symlinkTargets
      ++ map storeRootFromEntry bindSources
      ++ lib.concatMap storeRootsFromValue (builtins.attrValues envAttrs)
    )
  );

  # The JSON config for the compiled binary
  sandboxConfigJsonBase =
    assert _imageStoreConfigCheck == null;
    builtins.toJSON {
      inherit name;
      bwrap_path = "${bubblewrapPackage}/bin/bwrap";
      shell_bin = shellLib.bin;
      shell_interactive_args = shellLib.interactiveArgs;
      shell_name = sCfg.shell.name;
      shell_host_config = sCfg.shell.hostConfig;
      default_command = sCfg.defaultCommand;

      network_enable = sCfg.network.enable;
      network_namespace = sCfg.network.namespace;
      wayland_enable = sCfg.gui.wayland.enable;
      wayland_security_context = sCfg.gui.wayland.securityContext.enable;
      x11_enable = sCfg.gui.x11.enable;
      gpu_enable = gpuEnabled;
      gpu_shm = sCfg.gui.gpu.shm;
      ssh_enable = sCfg.ssh.enable;
      pulseaudio_socket_name = pulseaudioSocketName;
      pipewire_backend_socket_name = pipewireBackendSocketName;
      pipewire_socket_name = pipewireSocketName;
      pipewire_pulse_binary_path =
        if sCfg.audio.pipewire.pulseOnly then "${pkgs.pipewire}/bin/pipewire-pulse" else null;
      pipewire_pulse_config_path =
        if sCfg.audio.pipewire.pulseOnly then "${pipewirePulseOnlyConf}" else null;
      pipewire_pulse_wrapper_path = pipewirePulseWrapperPath;
      fido2_enable = sCfg.fido2.enable;
      video_enable = sCfg.video.enable;
      printing_enable = sCfg.printing.enable;
      dbus_enable = sCfg.dbus.enable;
      seccomp_enable = sCfg.sandbox.seccomp.enable;
      git_enable = sCfg.git.enable;
      bind_working_directory = sCfg.sandbox.bindWorkingDirectory;
      store_mode = sCfg.sandbox.nixStore.mode;
      store_roots = if imageStoreMode then storeRoots else [ ];
      store_id = if imageStoreMode then storeId else null;
      store_image_path = if imageStoreMode then storeImagePublishedPath else null;
      store_mount_path = if imageStoreMode then storeMountPath else null;
      inherit anonymize;

      ssh_allow_fingerprints = sCfg.ssh.allowFingerprints;
      ssh_filter_timeout_seconds = sCfg.ssh.filterTimeoutSeconds;

      home_directory = config.home.homeDirectory;
      sandbox_home = if anonymize then sandboxHome else config.home.homeDirectory;
      seccomp_filter_path = if seccompFilter != "" then seccompFilter else null;
      per_dir = perDirBuckets;
      copy_file_base = sCfg.sandbox.copyFileBase;
      netns_helper_path =
        if sCfg.network.namespace != null then "/run/wrappers/bin/cloister-netns" else null;
      git_path = "${pkgs.git}/bin/git";
      init_path = "${pkgs.tini}/bin/tini";

      static_bwrap_args = bwrapLib.mkBwrapArgs {
        dirs =
          allDirs
          ++ (lib.optionals anonymize [
            "/home"
            sandboxHome
          ]);
        inherit (sCfg.sandbox) tmpfs;
        symlinks = sCfg.sandbox.symlinks ++ sCfg.sandbox.extraSymlinks;
        binds = {
          ro = staticRoBinds;
          rw = staticRwBinds;
        };
        env = envAttrs;
      };
      dynamic_binds = dynamicBindsList;

      passthrough_env = sCfg.sandbox.passthroughEnv;
      disallowed_paths = sCfg.sandbox.disallowedPaths;
      dangerous_paths = normalizedDangerousPaths;
      allow_dangerous_paths = normalizedAllowDangerousPaths;
      dangerous_path_warnings = sCfg.sandbox.dangerousPathWarnings;
      dev_binds = sCfg.sandbox.devBinds;
      bind_sources = bindSources;

      dir_mkdirs = dirMkdirSpecs;
      file_mkdirs = fileMkdirSpecs;
      managed_file_host_mkdirs = map managedFileDirOverlap managedFileDirsOverlapping;
      copy_files = copyFileSpecs;

      enforce_strict_home_policy = sCfg.sandbox.enforceStrictHomePolicy;
      dbus_proxy_socket_name = if sCfg.dbus.enable then "cloister/dbus/${name}" else null;
      dbus_proxy_path = if sCfg.dbus.enable then dbusProxyWrapper else null;
      flatpak_app_id = if portalDesktopEnabled then flatpakAppId else null;
      worker_broker = renderedWorkerBroker;
      build_revision = buildRevision;
    };

  configJsonPath = pkgs.writeText "cloister-config-${name}.json" sandboxConfigJsonBase;

  package =
    pkgs.runCommand "cl-${name}"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${cloister-sandbox}/bin/cloister-sandbox $out/bin/cl-${name} \
          --set-default CLOISTER_BUILD_REV ${lib.escapeShellArg buildRevision} \
          --add-flags "--config ${configJsonPath} --"
      '';
in
{
  inherit configJsonPath package;
  sandboxConfig = builtins.fromJSON (builtins.unsafeDiscardStringContext sandboxConfigJsonBase);
  internal = {
    inherit pipewirePulseOnlyConfText pipewirePulseWrapperText;
  };
  imageStoreInfo =
    if imageStoreMode then
      {
        inherit name storeId storeRoots;
        imagePath = toString storeImage;
        metaPath = toString storeMeta;
        publishedImagePath = storeImagePublishedPath;
        publishedMetaPath = storeMetaPublishedPath;
        mountPath = storeMountPath;
      }
    else
      null;
  sandboxConfigJson = builtins.readFile configJsonPath;
}
