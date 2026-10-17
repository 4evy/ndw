{ settingsLib, ... }:
# EnabledPreferenceRules lists what's turned off, despite its name
let
  preference = settingsLib.preference toggle;
  page = settingsLib.systemPage "Spotlight" "com.apple.settings.search";
  inherit (page) setting select toggle;

  inherit (settingsLib)
    boolAs
    user
    enum
    member
    members
    ;

  rules = user "com.apple.Spotlight" "EnabledPreferenceRules";
  spotlight = user "com.apple.Spotlight";

in
{
  showRelatedContent = toggle {
    ui = "Show Related Content";
    storage = rules;
    value = member {
      item = "Custom.relatedContents";
      listedWhen = false;
    };
  };

  helpAppleImproveSearch =
    preference "Help Apple Improve Search"
      (user "com.apple.assistant.support" "Search Queries Data Sharing Status")
      (boolAs 1 2);

  searchResults = setting {
    ui = "Search results";
    storage = rules;
    value = members {
      listedWhen = false;
      items = {
        appStore = "com.apple.AppStore";
        books = "com.apple.iBooksX";
        calculator = "com.apple.calculator";
        calendar = "com.apple.iCal";
        contacts = "com.apple.AddressBook";
        dictionary = "com.apple.Dictionary";
        games = "com.apple.games";
        mail = "com.apple.mail";
        messages = "com.apple.MobileSMS";
        music = "com.apple.Music";
        notes = "com.apple.Notes";
        phone = "com.apple.mobilephone";
        photos = "com.apple.Photos";
        podcasts = "com.apple.podcasts";
        reminders = "com.apple.reminders";
        safari = "com.apple.Safari";
        shortcuts = "com.apple.shortcuts";
        systemSettings = "com.apple.systempreferences";
        tips = "com.apple.tips";
        voiceMemos = "com.apple.VoiceMemos";
        apps = "System.applications";
        files = "System.files";
        folders = "System.folders";
        iPhoneApps = "System.iphoneApps";
        menuItems = "System.menuItems";
      };
    };
  };

  resultsFromClipboard = toggle {
    ui = "Results from Clipboard";
    storage = spotlight "PasteboardHistoryEnabled";
  };

  clipboardHistoryIsAvailableInSpotlight = select {
    ui = [
      "Results from Clipboard"
      "Keep for"
    ];
    storage = spotlight "PasteboardHistoryTimeout";
    value = enum {
      "30 minutes" = 1800;
      "8 hours" = 28800;
      "7 days" = 604800;
    };
    control = "AXPopUpButton:Results from Clipboard";
    choices = [
      "8 hours"
      "7 days"
    ];
  };
}
