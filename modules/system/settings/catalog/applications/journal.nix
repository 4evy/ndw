{ settingsLib, ... }:
let
  preference = settingsLib.preference setting;
  setting = settingsLib.section {
    ui = [
      "Journal"
      "Settings…"
      "General"
    ];
  };

  inherit (settingsLib)
    user
    bool
    enum
    ;

  shared = user "~/Library/Group Containers/group.com.apple.Journal/Library/Preferences/group.com.apple.Journal";
in
{
  addEntryTitle = setting {
    ui = [ "Add Entry Title" ];
    storage = shared "ADD_ENTRY_TITLE";
    value = enum {
      Always = 0;
      "Only for Moments" = 1;
      Never = 2;
    };
  };

  alwaysUseMomentDate = preference [
    "Always Use Moment Date"
  ] (shared "ALWAYS_USE_MOMENT_DATE") bool;

  getWritingPrompts = preference [ "Get Writing Prompts" ] (shared "showFollowupPrompts") bool;
}
