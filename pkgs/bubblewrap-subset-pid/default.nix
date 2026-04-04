{
  lib,
  bubblewrap,
}:

# Keep this aligned with nixpkgs' bubblewrap package. When nixpkgs updates
# bubblewrap, rebuild this derivation and refresh the local patch if needed.
bubblewrap.overrideAttrs (old: {
  pname = "bubblewrap-subset-pid";
  patches = (old.patches or [ ]) ++ [ ./0001-mount-proc-with-subset-pid.patch ];
  meta = (old.meta or { }) // {
    homepage = "https://github.com/tcllama/cloister";
    license = lib.licenses.mit;
    mainProgram = "bwrap";
    platforms = lib.platforms.linux;
  };
})
