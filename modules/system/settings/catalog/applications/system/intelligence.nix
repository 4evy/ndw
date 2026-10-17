{ settingsLib, ... }:
let
  page = settingsLib.systemPage "Apple Intelligence & Siri" "com.apple.settings.siri";
  inherit (page) toggle preference;

  inherit (settingsLib)
    user
    global
    bool
    enum
    ;

in
{
  appleIntelligence =
    preference "Apple Intelligence" (user "com.apple.CloudSubscriptionFeatures.optIn" "10334750688")
      bool;

  siri = {
    enable = preference "Siri" (user "com.apple.assistant.support" "Assistant Enabled") bool;

    responses = page.radio {
      ui = "Responses";
      storage = user "com.apple.assistant.backedup" "Use device speaker for TTS";
      value = enum {
        "Spoken Response" = 2;
        "Silent Response" = 3;
      };

      verify = {
        open = [ "Responses" ];
      };
    };
  };

  automaticVisualLookUp = toggle {
    ui = "Automatic Visual Look Up";
    storage = global "SSPreferencesVisualLookUpInSSSEnabled";
  };

  chatGpt.useExtension = toggle {
    ui = [
      "ChatGPT"
      "Use Extension"
    ];
    storage = user "com.apple.siri.generativeassistantsettings" "isEnabled";
    verify.open = [ "ChatGPT" ];
  };
}
