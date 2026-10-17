{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Notifications" "com.apple.settings.notifications";
  inherit (page) setting select toggle;

  inherit (settingsLib)
    user
    bool
    enum
    snapshot
    restarts
    ;

  domain = "~/Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted";
  usernoted = user domain;
  restartsUsernoted = restarts "usernoted";

  # dnd_prefs is stored inverted: dndDisplaySleep is true when notifications
  # aren't allowed
  dndPreference =
    entry: allowed:
    let
      q = lib.escapeShellArg;
      path = ''"$HOME"/${q (lib.removePrefix "~/" domain)}'';
    in
    ''
      (
        set -o pipefail
        f=$(/usr/bin/mktemp) || exit 1
        trap '/bin/rm -f "$f"' EXIT
        if ! {
          /usr/bin/defaults export ${path} - |
            /usr/bin/plutil -extract dnd_prefs raw -o - - |
            /usr/bin/base64 -D > "$f" &&
            /usr/bin/plutil -replace ${entry} -bool ${lib.boolToString (!allowed)} "$f" &&
            /usr/bin/defaults write ${path} dnd_prefs -data "$(/usr/bin/xxd -p "$f" | /usr/bin/tr -d '\n')"
        }; then
          printf '%s\n' ${q "darwin.settings: failed: setting ${entry} in dnd_prefs"} >&2
          exit 1
        fi
      )
    '';

  allow =
    {
      ui,
      entry,
      control,
    }:
    toggle {
      ui = [
        "Allow notifications"
        ui
      ];
      storage = usernoted "dnd_prefs";
      apply = dndPreference entry;
      behaviors = [
        restartsUsernoted
      ];
      control = "AXCheckBox:${control}";
    };
in
{
  notificationCenter = {
    showPreviews = select {
      ui = "Show previews";
      storage = usernoted "content_visibility";
      value = enum {
        Always = 3;
        "When Unlocked" = 2;
        Never = 1;
      };
      behaviors = [ restartsUsernoted ];
      control = "AXPopUpButton:show-previews";
      choices = [
        "Always"
        "When Unlocked"
      ];
    };

    summarizeNotifications = setting {
      ui = "Summarize notifications";
      storage = usernoted "summarize_previews";
      value = bool;
      behaviors = [ restartsUsernoted ];
    };
  };

  allowNotifications = {
    whenTheDisplayIsSleeping = allow {
      ui = "When the display is sleeping";
      entry = "dndDisplaySleep";
      control = "allow-when-sleeping";
    };
    whenTheScreenIsLocked = allow {
      ui = "When the screen is locked";
      entry = "dndDisplayLock";
      control = "allow-when-locked";
    };

    whenMirroringOrSharingTheDisplay = select {
      ui = [
        "Allow notifications"
        "When mirroring or sharing the display"
      ];
      storage = usernoted "dnd_prefs";
      value = enum {
        "Allow Notifications" = true;
        "Notifications Off" = false;
      };
      apply = choice: dndPreference "dndMirrored" (choice == "Allow Notifications");
      behaviors = [
        restartsUsernoted
      ];
      control = "AXPopUpButton:allow-when-sharing";
    };
  };

  applications = setting {
    ui = "Application Notifications";
    storage.apps = usernoted "apps";
    value = snapshot;
    behaviors = [ restartsUsernoted ];
  };
}
