{ lib }:
let
  renderWrapperInit =
    {
      configHome,
      configDir,
      initExt,
      outsideRendered,
    }:
    ''
      if [[ -n "''${CLOISTER:-}" && "''${CLOISTER}" =~ ^[A-Za-z0-9_-]+$ ]]; then
        _cloister_init="${configHome}/${configDir}/cloister-''${CLOISTER}.${initExt}"
        if [[ -f "$_cloister_init" ]]; then
          source "$_cloister_init"
        fi
        unset _cloister_init
      else
        ${outsideRendered}
      fi
    '';
in
{
  renderAlias = name: value: "alias ${name}=${lib.escapeShellArg value}";

  renderFunction = name: body: ''
    ${name}() {
    ${body}
    }
  '';

  renderOutsideFunction =
    {
      name,
      sandbox,
      initPath,
      command,
    }:
    ''
      ${name}() {
        __cloister_run_${sandbox} -c ${command} -lc "source \"${initPath}\"; ${name} \"\$@\"" -- "$@"
      }
    '';

  renderOutsideRunner = sandbox: ''
    __cloister_run_${sandbox}() {
      _cloister_args=()
      while [[ "$#" -gt 0 ]]; do
        case "$1" in
          --shell)
            _cloister_args+=("$1")
            shift
            ;;
          -c)
            _cloister_args+=("$1")
            shift
            if [[ "$#" -gt 0 ]]; then
              _cloister_args+=("$1")
              shift
            fi
            break
            ;;
          --)
            _cloister_args+=("$1")
            shift
            break
            ;;
          *)
            break
            ;;
        esac
      done

      cl-${sandbox} "''${_cloister_args[@]}" "$@"
      }
  '';

  inherit renderWrapperInit;

  mkRenderWrapperInit =
    { configDir, initExt }:
    { configHome, outsideRendered }:
    renderWrapperInit {
      inherit
        configHome
        configDir
        initExt
        outsideRendered
        ;
    };
}
