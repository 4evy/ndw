{
  lib,
  coreutils,
  linkFarm,
  writeTextFile,
}:
let
  javascript = [ ./preferences.js ] ++ lib.filesystem.listFilesRecursive ./live;
  checkedJavaScript = lib.genAttrs' (lib.filter (lib.hasSuffix ".js") javascript) (
    source:
    lib.nameValuePair (lib.removePrefix "${toString ./.}/" (toString source)) (writeTextFile {
      name = baseNameOf source;
      text = builtins.readFile source;
      checkPhase = ''
        /usr/bin/osacompile -l JavaScript -o "$TMPDIR/compiled.scpt" "$target"
      '';
    })
  );
in
linkFarm "darwin-settings-scripts" (
  checkedJavaScript
  // {
    # Exact file replacement must reject directory destinations atomically
    "bin/mv" = lib.getExe' coreutils "mv";
  }
)
