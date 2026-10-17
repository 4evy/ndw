{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types hasPrefix mkIf;
  inherit (lib.darwin.options) mkNullableOption;
  location = config.system.defaults.screencapture.location;
  user = config.system.primary.user;
  prepareDirectory = pkgs.writeShellApplication {
    name = "prepare-screencapture-directory";
    runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) coreutils; };
    excludeShellChecks = [ "SC2016" ];
    text = ''
      # Resolve the home shorthand after sudo sets HOME for the primary user
      # Other shell syntax stays literal, including dollar signs in filenames
      mkdir --parents -- ${
        if location == "~" then
          ''"$HOME"''
        else if lib.strings.hasPrefix "~/" location then
          ''"$HOME"/${lib.strings.escapeShellArg (lib.strings.removePrefix "~/" location)}''
        else
          lib.strings.escapeShellArg location
      }
    '';
  };
in

{
  options.system.defaults.screencapture = {
    location =
      mkNullableOption
        (
          types.addCheck types.str (value: hasPrefix "/" value || value == "~" || hasPrefix "~/" value)
          // {
            description = "absolute path or a home-relative path starting with ~/";
          }
        )
        ''
          Directory in which to save screenshots, as an absolute path or a
          path starting with `~/`. Activation creates missing directories as
          `system.primary.user`. `~` refers to that user's home directory

          Other shell syntax is literal. Existing directory permissions are
          preserved, and existing screenshots are not moved when this changes
        '';

    type = mkNullableOption types.str ''
      The image format to use, such as "jpg".
    '';

    disable-shadow = mkNullableOption types.bool ''
      Disable drop shadow border around screencaptures. The default is false.
    '';

    include-date = mkNullableOption types.bool ''
      Include date and time in screenshot filenames. The default is true.
      Screenshot 2024-01-09 at 13.27.20.png would be an example for true.

      Screenshot.png
      Screenshot 1.png would be an example for false.
    '';

    save-selections = mkNullableOption types.bool ''
      Remember the selection window of the last screencapture. The default is true.
    '';

    show-thumbnail = mkNullableOption types.bool ''
      Show thumbnail after screencapture before writing to file. The default is true.
    '';

    target =
      mkNullableOption
        (types.enum [
          "file"
          "clipboard"
          "preview"
          "mail"
          "messages"
        ])
        ''
          Target to which screencapture should save screenshot to. The default is "file".
          Valid values include:

          * `file`: Saves as a file in location specified by `system.defaults.screencapture.location`
          * `clipboard`: Saves screenshot to clipboard
          * `preview`: Opens screenshot in Preview app
          * `mail`
          * `messages`
        '';
  };

  config = mkIf (location != null && user != null) {
    system.activation.steps = {
      screencapture = {
        deps = [ "users" ];
        text = lib.darwin.shell.asUser user [ (lib.meta.getExe prepareDirectory) ];
      };
      userDefaults.deps = [ "screencapture" ];
    };
  };
}
