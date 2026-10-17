{ settingsLib, ... }:
let
  preference = settingsLib.preference setting;
  toggle = settingsLib.toggle setting;

  inherit (settingsLib)
    eachKey
    bool
    setting
    system
    ;

  pane = "com.apple.settings.general";
  open = [
    "com.apple.systempreferences.general.softwareUpdate"
    "AdvancedView.LabeledContent.infoButton"
  ];

  switchCheckbox = settingsLib.checkbox switch;
  switch = settingsLib.sectionWith toggle {
    ui = [
      "System Settings"
      "General"
      "Software Update"
      "Automatic Updates (i)"
    ];
    verify = { inherit pane open; };
  };
in
{
  automaticallyDownloadNewUpdatesWhenAvailable =
    switchCheckbox "Download new updates when available"
      (system "com.apple.SoftwareUpdate" "AutomaticDownload")
      "AXCheckBox:AdvancedOptionsView.DownloadNewUpdatesToggle";

  automaticallyInstallMacOSUpdates =
    switchCheckbox "Install macOS updates"
      (system "com.apple.SoftwareUpdate" "AutomaticallyInstallMacOSUpdates")
      "AXCheckBox:AdvancedOptionsView.InstallMacOSUpdatesToggle";

  automaticallyInstallSystemDataFilesAndSecurityUpdates = switch {
    ui = "Install system data files and security updates";
    storage = {
      configData = system "com.apple.SoftwareUpdate" "ConfigDataInstall";
      critical = system "com.apple.SoftwareUpdate" "CriticalUpdateInstall";
    };
    value = eachKey bool;
    control = "AXCheckBox:AdvancedOptionsView.InstallSecurityResponsesToggle";
  };

  automaticallyInstallApplicationUpdatesFromTheAppStore = preference [
    "App Store"
    "Settings"
    "Automatic Updates"
  ] (system "com.apple.commerce" "AutoUpdate") bool;
}
