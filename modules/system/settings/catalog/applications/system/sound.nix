{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Sound" "com.apple.settings.sounds";
  inherit (page) select toggle preference;

  inherit (settingsLib)
    numberBetween
    global
    file
    enum
    ;

  switchCheckbox = settingsLib.checkbox switch;
  switch = settingsLib.sectionWith toggle {
    value = settingsLib.integerBool;
  };
in
{
  soundEffects = {
    alertSound = select {
      ui = "Alert sound";
      storage = global "com.apple.sound.beep.sound";
      value = enum (
        lib.mapAttrs (_: file: "/System/Library/Sounds/${file}.aiff") {
          Boop = "Tink";
          Breeze = "Blow";
          Bubble = "Pop";
          Crystal = "Glass";
          Funky = "Funk";
          Heroine = "Hero";
          Jump = "Frog";
          Mezzo = "Basso";
          Pebble = "Bottle";
          Pluck = "Purr";
          Pong = "Morse";
          Sonar = "Ping";
          Sonumi = "Sosumi";
          Submerge = "Submarine";
        }
      );
      control = "AXPopUpButton:AlertSoundPicker";
      choices = [
        "Sonar"
        "Boop"
      ];
    };

    alertVolume = preference "Alert volume" (global "com.apple.sound.beep.volume") (
      numberBetween 0.0 1.0
    );

    playSoundOnStartup = toggle {
      ui = "Play sound on startup";
      storage = file "nvram StartupMute";
      apply = play: "/usr/sbin/nvram StartupMute=${if play then "%00" else "%01"}";
      control = "AXCheckBox:BootChimeCheckbox";
    };

    # System Settings' switch doesn't follow this key and ignores clicks,
    # so it can't be verified
    playUserInterfaceSoundEffects =
      switchCheckbox "Play user interface sound effects" (global "com.apple.sound.uiaudio.enabled")
        "AXCheckBox:SoundEffectsCheckbox"
      // {
        verify = null;
      };

    playFeedbackWhenVolumeIsChanged =
      switchCheckbox "Play feedback when volume is changed" (global "com.apple.sound.beep.feedback")
        "AXCheckBox:VolumeKeyFeedbackCheckbox";
  };
}
