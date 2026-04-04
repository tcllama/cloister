# Audio

Cloister supports direct PulseAudio passthrough, PipeWire native forwarding, filtered audio access, in-sandbox `pipewire-pulse` compatibility, and PulseAudio-only access backed by filtered PipeWire.

## Choosing an audio mode

- use `audio.pulseaudio.enable = true` for simple direct PulseAudio socket forwarding with no filtering
- use `audio.pipewire.enable = true` for native PipeWire clients, cameras, and screen-sharing capable apps
- use `audio.pipewire.pulseOnly = true` for audio-only sandboxes that should not receive a native PipeWire socket
- use `audio.pipewire.pulseCompat.enable = true` when applications expect a local PulseAudio server but you still want native PipeWire filtering underneath

## Filtered PipeWire access

When `audio.pipewire.enable = true` is set, the sandbox receives unrestricted access to the PipeWire graph unless filtering is enabled.

Enabling `audio.pipewire.filters.enable = true` provisions a dedicated PipeWire socket and generates WirePlumber policy so the sandbox can only see and interact with the audio or video device classes you explicitly allow.

```nix
cloister.sandboxes.zoom = {
  audio.pipewire = {
    enable = true;
    filters = {
      enable = true;
      audioOut = true;  # speakers (default)
      audioIn = true;   # microphones
      videoIn = true;   # webcams / V4L2
      control = false;  # volume / mute changes
      routing = false;  # default device / stream routing
    };
  };
  video.enable = true;
};
```

### Discovery toggles

These control which `media.class` types are visible in the PipeWire registry.

| Toggle | media.class | Default | Notes |
|--------|------------|---------|-------|
| `audioOut` | `Audio/Sink` | `true` | Playback |
| `audioIn` | `Audio/Source` | `false` | Microphones |
| `videoIn` | `Video/Source` | `false` | Cameras. Also needs `video.enable = true` for `/dev/video*` binding |

### Management toggles

These grant additional WirePlumber permissions on objects the sandbox can already see.

| Toggle | Permission | Effect |
|--------|-----------|--------|
| `control` | `w` (write) | Change volume, mute state of visible nodes |
| `routing` | `m` (metadata) | Change default devices, move streams |

The link-only baseline lets sandbox-created streams connect to explicitly exposed sinks or sources without making the rest of the graph visible. `audioIn = true` allows microphone capture, and `videoIn = true` allows camera capture once the corresponding device nodes are available.

## `pipewire-pulse` compatibility

When `audio.pipewire.pulseCompat.enable = true` is set, Cloister generates a small wrapper around the sandbox entry command. That wrapper:

- starts `pipewire-pulse` inside the sandbox if `"$XDG_RUNTIME_DIR/pulse/native"` does not already exist
- waits for the local PulseAudio socket to appear
- exports `PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native`
- launches the requested shell or command
- stops the transient `pipewire-pulse` process again when that command exits

This gives `libpulse` applications a normal PulseAudio endpoint without forwarding the host PulseAudio socket. `pipewire-pulse` still connects to the PipeWire native socket mounted into the sandbox, so all audio filter rules continue to apply.

### Requirements

- `audio.pipewire.enable = true`
- `audio.pulseaudio.enable = false`
- `XDG_RUNTIME_DIR` must be present
- the mounted PipeWire socket must exist and be valid on the host
- `pipewire` must be available in the sandbox package set

For filtered setups, the usual media prerequisites still apply:

- `audioIn = true` for microphones
- `videoIn = true` plus `video.enable = true` for cameras
- `control = true` for volume / mute writes
- `routing = true` for default-device or stream-routing changes

If sandbox D-Bus is disabled, Cloister writes both `client.conf` and `pipewire-pulse.conf` with `support.dbus = false`.

## Pulse-only mode

When `audio.pipewire.pulseOnly = true` is set, Cloister still uses filtered PipeWire as the backend, but it does not mount any native PipeWire socket into the sandbox. Instead, Cloister starts a transient `pipewire-pulse` bridge outside the sandbox, points it at the sandbox's filtered `cloister/pipewire/<name>` remote, and binds only the resulting `pulse/native` socket into the sandbox.

This mode is intended for audio-only sandboxes that want:

- playback without exposing native PipeWire
- optional microphone access via `filters.audioIn = true`
- optional volume/mute control via `filters.control = true`
- no access to cameras, screen sharing, or native PipeWire tooling inside the sandbox

```nix
cloister.sandboxes.music.audio.pipewire = {
  enable = true;
  pulseOnly = true;
  filters = {
    audioOut = true;
    audioIn = false;
    control = false;
  };
};
```

`pulseOnly` is mutually exclusive with `audio.pulseaudio.enable`, `audio.pipewire.pulseCompat.enable`, and `audio.pipewire.alsa.enable`.

## Per-sandbox filtered sockets

Filtered PipeWire sockets are scoped per sandbox (for example, `cloister/pipewire/zoom`). Even if two sandboxes use identical filter settings, each gets its own socket and WirePlumber policy so filtered graph visibility stays isolated.

## Anonymized audio sandboxes

When `sandbox.anonymize.enable = true` is also set, Cloister does not allow exposing a native PipeWire socket inside the sandbox. Nix evaluation fails if `audio.pipewire.enable = true` is combined with anonymization without also setting `audio.pipewire.pulseOnly = true`.

For anonymized audio sandboxes, `pulseOnly` launches `pipewire-pulse` inside a transient helper bubblewrap with a synthetic hostname and passwd/group view, then forwards only that helper's `pulse/native` socket into the final sandbox.

## Validation

Inside the sandbox, run:

```bash
cloister-pipewire-validate      # summary
cloister-pipewire-validate -v   # per-object detail
```

The helper exits `0` on `RESULT: PASS` and `1` on `RESULT: FAIL` or connection errors, so it is safe to use in scripts and CI.

For manual debugging, `wpctl status` shows visible devices and `wpctl set-volume <id> 5%+` can confirm whether `control` is effective.

If `pulseOnly` is enabled, `pw-cli` should not have any native PipeWire socket to talk to inside the sandbox. For audio-only validation, use PulseAudio-compatible applications or `pactl` instead.
