{ lib, settingsLib, ... }:
let
  page = (settingsLib.systemPage "General" "com.apple.settings.general").navigate "Date & Time" open;
  inherit (page) setting toggle;

  inherit (settingsLib)
    boolKeys
    inverted
    bool
    global
    system
    file
    text
    onlyWhen
    ;

  open = [ "com.apple.systempreferences.general.dateAndTime" ];

  # systemsetup logs internal errors even when the change goes through,
  # so only its exit status is reported
  systemsetup =
    args:
    "/usr/sbin/systemsetup ${args} >/dev/null 2>&1 || echo ${lib.escapeShellArg "darwin.settings: failed: systemsetup ${args}"} >&2";
  onOff = enabled: if enabled then "on" else "off";
  option = name: "applications.systemSettings.general.dateAndTime.${name}";
in
{
  "24HourTime" = toggle {
    ui = "24-hour time";
    storage = {
      force24 = global "AppleICUForce24HourTime";
      force12 = global "AppleICUForce12HourTime";
    };
    value = boolKeys {
      force24 = bool;
      force12 = inverted bool;
    };
    control = "AXCheckBox:24-hour time";
  };

  # timed keeps this in /var/db/timed, readable only by root
  setTimeAndDateAutomatically = toggle {
    ui = "Set time and date automatically";
    storage = system "com.apple.timed" "TMAutomaticTimeOnlyEnabled";
    apply = enabled: systemsetup "-setusingnetworktime ${onOff enabled}";
  };

  source = setting {
    ui = "Source";
    description = "The network time server, e.g. \"time.apple.com\".";
    storage = file "/etc/ntp.conf";
    value = text;
    apply = server: systemsetup "-setnetworktimeserver ${lib.escapeShellArg server}";
    reads.command = "/usr/bin/awk '/^server / { print $2; exit }' /etc/ntp.conf";
    relations = [
      (onlyWhen (option "setTimeAndDateAutomatically") (
        enabled: enabled
      ) "the time is only fetched from a server when it's set automatically")
    ];
  };

  setTimeZoneAutomaticallyUsingYourCurrentLocation = toggle {
    ui = "Set time zone automatically using your current location";
    storage = system "com.apple.timezone.auto" "Active";
  };

  timeZone = setting {
    ui = "Time zone";
    description = "A time zone from `systemsetup -listtimezones`, e.g. \"Europe/Amsterdam\".";
    storage = file "/etc/localtime";
    value = text;
    apply = zone: systemsetup "-settimezone ${lib.escapeShellArg zone}";
    reads.command = "/usr/bin/readlink /etc/localtime | /usr/bin/sed 's|.*/zoneinfo/||'";
    relations = [
      (onlyWhen (option "setTimeZoneAutomaticallyUsingYourCurrentLocation") (
        enabled: !enabled
      ) "the location decides the time zone while it's set automatically")
    ];
  };
}
