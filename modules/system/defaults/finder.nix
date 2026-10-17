{ config, lib, ... }:

let
  inherit (lib.darwin.options) mkNullableOption;
  inherit (lib) types;

  cfg = config.system.defaults.finder;
in
{
  options.system.defaults.finder = {

    # Finder registers these Boolean preferences with its other user defaults
    # The registration table starts at 0x10000652c in the arm64e executable
    WarnOnEmptyTrash = mkNullableOption types.bool ''
      Ask for confirmation before emptying the Trash. The macOS registered
      default is true. Null leaves the current preference unchanged
    '';

    FXEnableRemoveFromICloudDriveWarning = mkNullableOption types.bool ''
      Warn before moving files out of iCloud Drive, which also removes them
      from iCloud Drive on other devices. The macOS registered default is true
    '';

    FXCopyAsPathnameQuoted = mkNullableOption types.bool ''
      Quote paths copied with Finder's Copy as Pathname command. The macOS
      registered default is true
    '';

    ShowSidebar = mkNullableOption types.bool ''
      Show the sidebar in Finder windows. The macOS registered default is true
    '';

    ShowRecentTags = mkNullableOption types.bool ''
      Show recent tags in the Finder sidebar. The macOS registered default is
      true
    '';

    ShowTabView = mkNullableOption types.bool ''
      Keep the tab bar visible even when a Finder window has only one tab.
      The macOS registered default is false
    '';

    AppleDisableTagBasedIconTinting = mkNullableOption types.bool ''
      Disable using tag colors to tint file and folder icons in Finder.
      The macOS registered default is false on versions that support it
    '';

    AppleShowAllFiles = mkNullableOption types.bool ''
      Whether to always show hidden files. The default is false.
    '';

    ShowStatusBar = mkNullableOption types.bool ''
      Show status bar at bottom of finder windows with item/disk space stats. The default is false.
    '';

    ShowPathbar = mkNullableOption types.bool ''
      Show path breadcrumbs in finder windows. The default is false.
    '';

    FXDefaultSearchScope = mkNullableOption types.str ''
      Change the default search scope. Use "SCcf" to default to current folder.
      The default is unset ("This Mac").
    '';

    FXRemoveOldTrashItems = mkNullableOption types.bool ''
      Remove items in the trash after 30 days.
      The default is false.
    '';

    FXPreferredViewStyle = mkNullableOption types.str ''
      Change the default finder view.
      "icnv" = Icon view, "Nlsv" = List view, "clmv" = Column View, "Flwv" = Gallery View
      The default is icnv.
    '';

    AppleShowAllExtensions = mkNullableOption types.bool ''
      Whether to always show file extensions. The default is false.
    '';

    CreateDesktop = mkNullableOption types.bool ''
      Whether to show icons on the desktop or not. The default is true.
    '';

    QuitMenuItem = mkNullableOption types.bool ''
      Whether to allow quitting of the Finder. The default is false.
    '';

    ShowExternalHardDrivesOnDesktop = mkNullableOption types.bool ''
      Whether to show external disks on desktop. The default is true.
    '';

    ShowHardDrivesOnDesktop = mkNullableOption types.bool ''
      Whether to show hard disks on desktop. The default is false.
    '';

    ShowMountedServersOnDesktop = mkNullableOption types.bool ''
      Whether to show connected servers on desktop. The default is false.
    '';

    ShowRemovableMediaOnDesktop = mkNullableOption types.bool ''
      Whether to show removable media (CDs, DVDs and iPods) on desktop. The default is true.
    '';

    _FXEnableColumnAutoSizing = mkNullableOption types.bool ''
      Resize columns to fit filenames.
      The default is false.
    '';

    _FXShowPosixPathInTitle = mkNullableOption types.bool ''
      Whether to show the full POSIX filepath in the window title. The default is false.
    '';

    _FXSortFoldersFirst = mkNullableOption types.bool ''
      Keep folders on top when sorting by name. The default is false.
    '';

    _FXSortFoldersFirstOnDesktop = mkNullableOption types.bool ''
      Keep folders on top when sorting by name on the desktop. The default is false.
    '';

    FXEnableExtensionChangeWarning = mkNullableOption types.bool ''
      Whether to show warnings when change the file extension of files. The default is true.
    '';

    NewWindowTarget =
      mkNullableOption
        (types.enum [
          "Computer"
          "OS volume"
          "Home"
          "Desktop"
          "Documents"
          "Recents"
          "iCloud Drive"
          "Other"
        ])
        ''
          Change the default folder shown in Finder windows. "Other" corresponds to the value of
          NewWindowTargetPath. The default is unset ("Recents").
        ''
      // {
        apply = lib.trivial.mapNullable (
          key:
          {
            "Computer" = "PfCm";
            "OS volume" = "PfVo";
            "Home" = "PfHm";
            "Desktop" = "PfDe";
            "Documents" = "PfDo";
            "Recents" = "PfAF";
            "iCloud Drive" = "PfID";
            "Other" = "PfLo";
          }
          .${key}
        );
      };

    NewWindowTargetPath = mkNullableOption types.str ''
      Sets the URI to open when NewWindowTarget is "Other". Spaces and similar characters must be
      escaped. If the value is invalid, Finder will open your home directory.
      Example: "file:///Users/foo/long%20cat%20pics".
      The default is unset.
    '';
  };

  config = {
    assertions = [
      {
        assertion = cfg.NewWindowTargetPath != null -> cfg.NewWindowTarget == "PfLo";
        message = "`system.defaults.finder.NewWindowTarget` should be set to `Other` when `NewWindowTargetPath` is non-null.";
      }
      {
        assertion = cfg.NewWindowTarget == "PfLo" -> cfg.NewWindowTargetPath != null;
        message = "`system.defaults.finder.NewWindowTargetPath` should be non-null when `NewWindowTarget` is set to `Other`.";
      }
    ];
  };
}
