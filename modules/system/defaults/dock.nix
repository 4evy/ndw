{ lib, ... }:
let
  inherit (lib)
    types
    mkOption
    strings
    last
    splitString
    ;
  inherit (lib.darwin.options) mkDefaultOption mkNullableOption;
  hotCorner =
    position:
    mkNullableOption lib.types.ints.positive ''
      Hot corner action for ${position} corner. Valid values include:

      * `1`: Disabled
      * `2`: Mission Control
      * `3`: Application Windows
      * `4`: Desktop
      * `5`: Start Screen Saver
      * `6`: Disable Screen Saver
      * `7`: Dashboard
      * `10`: Put Display to Sleep
      * `11`: Launchpad
      * `12`: Notification Center
      * `13`: Lock Screen
      * `14`: Quick Note
    '';
  # Dock masks modifiers with 0x1e0000 in _setCornerActionWithModifier
  hotCornerModifier =
    position:
    mkNullableOption
      (lib.types.addCheck lib.types.ints.unsigned (value: builtins.bitAnd value 1966080 == value))
      ''
        Modifier keys required to activate the ${position} hot corner.
        Add the native masks to combine keys: Shift = 131072, Control =
        262144, Option = 524288, and Command = 1048576. Zero requires no
        modifier keys. Null leaves the current preference unchanged
      '';
in

{
  options.system.defaults.dock = {
    appswitcher-all-displays = mkNullableOption types.bool ''
      Whether to display the appswitcher on all displays or only the main one. The default is false.
    '';

    autohide = mkNullableOption types.bool ''
      Whether to automatically hide and show the dock. The default is false.
    '';

    autohide-delay =
      mkNullableOption types.float ''
        Sets the speed of the autohide delay. The default is given in the example.
      ''
      // {
        example = 0.24;
      };

    autohide-time-modifier =
      mkNullableOption types.float ''
        Sets the speed of the animation when hiding/showing the Dock. The default is given in the example.
      ''
      // {
        example = 1.0;
      };

    dashboard-in-overlay = mkNullableOption types.bool ''
      Whether to hide Dashboard as a Space. The default is false.
    '';

    enable-spring-load-actions-on-all-items = mkNullableOption types.bool ''
      Enable spring loading for all Dock items. The default is false.
    '';

    expose-animation-duration =
      mkNullableOption types.float ''
        Sets the speed of the Mission Control animations. The default is given in the example.
      ''
      // {
        example = 1.0;
      };

    expose-group-apps = mkNullableOption types.bool ''
      Whether to group windows by application in Mission Control's Exposé. The default is false.
    '';

    launchanim = mkNullableOption types.bool ''
      Animate opening applications from the Dock. The default is true.
    '';

    mineffect =
      mkNullableOption
        (types.enum [
          "genie"
          "suck"
          "scale"
        ])
        ''
          Set the minimize/maximize window effect. The default is genie.
        '';

    minimize-to-application = mkNullableOption types.bool ''
      Whether to minimize windows into their application icon.  The default is false.
    '';

    mouse-over-hilite-stack = mkNullableOption types.bool ''
      Enable highlight hover effect for the grid view of a stack in the Dock.
    '';

    mru-spaces = mkNullableOption types.bool ''
      Whether to automatically rearrange spaces based on most recent use.  The default is true.
    '';

    orientation =
      mkNullableOption
        (types.enum [
          "bottom"
          "left"
          "right"
        ])
        ''
          Position of the dock on screen.  The default is "bottom".
        '';

    persistent-apps = mkOption {
      type =
        let
          taggedType = types.attrTag {
            app = mkOption {
              description = "An application to be added to the dock.";
              type = types.str;
            };
            file = mkOption {
              description = "A file to be added to the dock.";
              type = types.str;
            };
            folder = mkOption {
              description = "A folder to be added to the dock.";
              type = types.str;
            };
            spacer = mkOption {
              description = "A spacer to be added to the dock. Can be small or regular size.";
              type = types.submodule {
                options.small = mkDefaultOption types.bool false "Whether the spacer is small.";
              };
            };
          };

          simpleType = types.either types.str types.path;
          # Preserve filesystem paths without copying applications to the store
          toTagged = path: { app = toString path; };
        in
        types.nullOr (types.listOf (types.coercedTo simpleType toTagged taggedType));
      default = null;
      example = [
        { app = "/Applications/Safari.app"; }
        {
          spacer = {
            small = false;
          };
        }
        {
          spacer = {
            small = true;
          };
        }
        { folder = "/System/Applications/Utilities"; }
        { file = "/User/example/Downloads/test.csv"; }
      ];
      description = ''
        Persistent applications, spacers, files, and folders in the dock.
      '';
      apply =
        let
          toTile =
            item:
            if item ? app then
              {
                tile-data.file-data = {
                  _CFURLString = item.app;
                  _CFURLStringType = 0;
                };
              }
            else if item ? spacer then
              {
                tile-data = { };
                tile-type = if item.spacer.small then "small-spacer-tile" else "spacer-tile";
              }
            else if item ? folder || item ? file then
              {
                tile-data.file-data = {
                  _CFURLString = "file://" + (item.folder or item.file);
                  _CFURLStringType = 15;
                };
                tile-type = if item ? folder then "directory-tile" else "file-tile";
              }
            else
              item;
        in
        lib.trivial.mapNullable (map toTile);
    };

    persistent-others = mkOption {
      type =
        let
          folderType = types.submodule {
            options.path = mkOption {
              description = "Path to a folder to be added to the dock.";
              type = types.str;
            };
            options.arrangement = mkDefaultOption (types.enum [
              "name"
              "date-added"
              "date-modified"
              "date-created"
              "kind"
            ]) "name" "Sort order for files in folder when clicked.";
            options.displayas =
              mkDefaultOption
                (types.enum [
                  "stack"
                  "folder"
                ])
                "stack"
                "How to display the folder before clicked.  stack: Stack of file previews.  folder: A folder icon";
            options.showas = mkDefaultOption (types.enum [
              "automatic"
              "fan"
              "grid"
              "list"
            ]) "automatic" "Effect to show files when clicked.  fan: fan-out effect, grid: box, list: list";
          };
          taggedType = types.attrTag {
            file = mkOption {
              description = "A file to be added to the dock.";
              type = types.str;
            };
            folder = mkOption {
              description = "A folder to be added to the dock.";
              type = types.coercedTo types.str (str: { path = str; }) folderType;
            };
          };
          simpleType = types.either types.str types.path;
          # Preserve the legacy inference for untagged file and folder paths
          toTagged =
            _path:
            let
              path = toString _path;
            in
            if strings.hasInfix "." (last (splitString "/" path)) then { file = path; } else { folder = path; };
        in
        types.nullOr (types.listOf (types.coercedTo simpleType toTagged taggedType));
      default = null;
      example = lib.literalExpression ''
        [
          ./flake.nix
          "/Volumes"
          { folder = "/Users/@username@/Downloads"; }
          { folder = { path = "/Users/@username@/.emacs.d"; showas = "grid"; }; }
          { file = "/Users/@username@/Desktop/this_is_a_file"; }
        ]'';
      description = ''
        Persistent files, and folders in the dock.
      '';
      apply =
        let
          arrangementMap = {
            name = 1;
            date-added = 2;
            date-modified = 3;
            date-created = 4;
            kind = 5;
          };
          displayasMap = {
            stack = 0;
            folder = 1;
          };
          showasMap = {
            automatic = 0;
            fan = 1;
            grid = 2;
            list = 3;
          };
          parseFolder = folder: {
            arrangement = arrangementMap.${folder.arrangement};
            displayas = displayasMap.${folder.displayas};
            showas = showasMap.${folder.showas};
          };
          toTile = item: {
            tile-data = {
              file-data = {
                _CFURLString = "file://" + (if item ? folder then item.folder.path else item.file);
                _CFURLStringType = 15;
              };
            }
            // (
              if item ? folder then { inherit (parseFolder item.folder) arrangement displayas showas; } else { }
            );
            tile-type = if item ? folder then "directory-tile" else "file-tile";
          };
        in
        lib.trivial.mapNullable (map toTile);
    };

    scroll-to-open = mkNullableOption types.bool ''
      Scroll up on a Dock icon to show all Space's opened windows for an app, or open stack. The default is false.
    '';

    showAppExposeGestureEnabled = mkNullableOption types.bool ''
      Whether to enable trackpad gestures (three- or four-finger vertical swipe) to show App Exposé. The default is false. This feature interacts with `system.defaults.trackpad.TrackpadFourFingerVertSwipeGesture` and `system.defaults.trackpad.TrackpadThreeFingerVertSwipeGesture` to determine which gesture triggers App Exposé.
    '';

    showDesktopGestureEnabled = mkNullableOption types.bool ''
      Whether to enable four-finger spread gesture to show the Desktop. The default is false.
    '';

    showLaunchpadGestureEnabled = mkNullableOption types.bool ''
      Whether to enable four-finger pinch gesture to show the Launchpad. The default is false.
    '';

    showMissionControlGestureEnabled = mkNullableOption types.bool ''
      Whether to enable trackpad gestures (three- or four-finger vertical swipe) to show Mission Control. The default is false. This feature interacts with `system.defaults.trackpad.TrackpadFourFingerVertSwipeGesture` and `system.defaults.trackpad.TrackpadThreeFingerVertSwipeGesture` to determine which gesture triggers Mission Control.
    '';

    show-process-indicators = mkNullableOption types.bool ''
      Show indicator lights for open applications in the Dock. The default is true.
    '';

    showhidden = mkNullableOption types.bool ''
      Whether to make icons of hidden applications tranclucent.  The default is false.
    '';

    show-recents = mkNullableOption types.bool ''
      Show recent applications in the dock. The default is true.
    '';

    slow-motion-allowed = mkNullableOption types.bool ''
      Allow for slow-motion minimize effect while holding Shift key. The default is false.
    '';

    static-only = mkNullableOption types.bool ''
      Show only open applications in the Dock. The default is false.
    '';

    tilesize = mkNullableOption types.int ''
      Size of the icons in the dock.  The default is 64.
    '';

    magnification = mkNullableOption types.bool ''
      Magnify icon on hover. The default is false.
    '';

    largesize = mkNullableOption (types.ints.between 16 128) ''
      Magnified icon size on hover. The default is 16.
    '';

    wvous-tl-corner = hotCorner "top left";

    wvous-bl-corner = hotCorner "bottom left";

    wvous-tr-corner = hotCorner "top right";

    wvous-br-corner = hotCorner "bottom right";

    wvous-tl-modifier = hotCornerModifier "top left";

    wvous-bl-modifier = hotCornerModifier "bottom left";

    wvous-tr-modifier = hotCornerModifier "top right";

    wvous-br-modifier = hotCornerModifier "bottom right";
  };
}
