{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Battery" "com.apple.settings.battery";
  inherit (page) select toggle;

  inherit (settingsLib)
    system
    enum
    live
    ;

  sections = {
    b = "Battery Power";
    c = "AC Power";
  };
  powerManagement = source: system "com.apple.PowerManagement" sections.${source};

  pmset =
    source: key: value:
    "/usr/bin/pmset -${source} ${key} ${toString value}";
  pmsetBool =
    source: key: enabled:
    pmset source key (if enabled then 1 else 0);
  onOff = {
    true = 1;
    false = 0;
  };

  modes = {
    Automatic = 0;
    "Low Power" = 1;
    "High Power" = 2;
  };

  energyMode =
    { ui, source }:
    select {
      inherit ui;
      storage = powerManagement source;
      value = enum modes;
      apply = mode: pmset source "powermode" modes.${mode};
      reads = {
        command = live.pmsetValue sections.${source} "powermode";
        values = modes;
      };
      control = "AXPopUpButton:energy_mode + ${lib.last ui}";
      choices = [
        "Automatic"
        "Low Power"
        "High Power"
      ];
    };

  option =
    {
      ui,
      control,
      source,
      apply,
      reads,
    }:
    toggle {
      inherit reads;
      ui = [
        "Options…"
        ui
      ];
      storage = powerManagement source;
      inherit apply;
      inherit control;
      verify.open = [ "Options…" ];
    };
in
{
  energyMode = {
    onBattery = energyMode {
      ui = [
        "Energy Mode"
        "On battery"
      ];
      source = "b";
    };
    onPowerAdapter = energyMode {
      ui = [
        "Energy Mode"
        "On power adapter"
      ];
      source = "c";
    };
  };

  options = {
    slightlyDimTheDisplayOnBattery = option {
      ui = "Slightly dim the display on battery";
      control = "AXCheckBox:Slightly dim the display on battery";
      source = "b";
      apply = pmsetBool "b" "lessbright";
      reads = {
        command = live.pmsetValue sections.b "lessbright";
        values = onOff;
      };
    };

    preventAutomaticSleepingOnPowerAdapterWhenTheDisplayIsOff = option {
      ui = "Prevent automatic sleeping on power adapter when the display is off";
      control = "AXCheckBox:Prevent automatic sleeping on power adapter when the display is off";
      source = "c";
      # System Settings sets the sleep timer to 0 (never) or back to 1
      apply = prevent: pmset "c" "sleep" (if prevent then 0 else 1);
      reads.command = "${live.pmsetValue sections.c "sleep"} | /usr/bin/awk '{ print ($1 == 0 ? \"true\" : \"false\") }'";
    };

    wakeForNetworkAccess = select {
      ui = [
        "Options…"
        "Wake for network access"
      ];
      storage = {
        battery = powerManagement "b";
        adapter = powerManagement "c";
      };
      value = enum {
        Always = 0;
        "Only on Power Adapter" = 1;
        Never = 2;
      };
      apply = choice: [
        (pmsetBool "b" "womp" (choice == "Always"))
        (pmsetBool "c" "womp" (choice != "Never"))
      ];
      reads = {
        command = ''echo "$(${live.pmsetValue sections.b "womp"}) $(${live.pmsetValue sections.c "womp"})"'';
        values = {
          Always = "1 1";
          "Only on Power Adapter" = "0 1";
          Never = "0 0";
        };
      };
      control = "Wake for network access";
      choices = [
        "Always"
        "Only on Power Adapter"
        "Never"
      ];
      verify.open = [ "Options…" ];
    };
  };
}
