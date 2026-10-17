{ settingsLib, ... }:
let
  preference = settingsLib.preference setting;
  setting = settingsLib.section {
    ui = [
      "Voice Memos"
      "Settings…"
    ];
  };

  inherit (settingsLib)
    user
    bool
    enum
    ;

  shared = user "~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Library/Preferences/group.com.apple.VoiceMemos.shared";
in
{
  clearDeleted = setting {
    ui = [ "Clear Deleted" ];
    storage = shared "RCVoiceMemosRecentlyDeletedWindowKey";
    value = enum {
      Immediately = 0;
      "After 1 Day" = 1;
      "After 7 Days" = 7;
      "After 30 Days" = 30;
      Never = -1;
    };
  };

  audioQuality = setting {
    ui = [ "Audio Quality" ];
    storage = shared "RCVoiceMemosAudioQualityKey";
    value = enum {
      Lossy = 0;
      Lossless = 1;
    };
  };

  locationBasedNaming = preference [
    "Location-based Naming"
  ] (shared "RCVoiceMemosUseLocationBasedNaming") bool;
}
