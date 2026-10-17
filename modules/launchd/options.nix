# Native keys and value types from macOS 27's launchd.plist(5)
# Types check the plist shape, not whether launchd honors a key in a particular
# bootstrap domain. New keys in extra.config need live launchd validation
{ lib, plistType }:
let
  t = lib.types;
  optional = lib.darwin.options.mkNullableOption;
  fields =
    type: names: lib.attrsets.genAttrs names (name: optional type "Native launchd ${name} setting.");
  dictionary = options: t.submodule { inherit options; };
  strings = t.listOf t.str;
  stringOrStrings = t.either t.str strings;
  calendar = dictionary (
    lib.attrsets.mapAttrs
      (
        name: range:
        optional (t.ints.between (builtins.elemAt range 0) (builtins.elemAt range 1)) "Calendar ${name}, omitted to match every value."
      )
      {
        Minute = [
          0
          59
        ];
        Hour = [
          0
          23
        ];
        Day = [
          1
          31
        ];
        Weekday = [
          0
          7
        ];
        Month = [
          1
          12
        ];
      }
  );
  limits = dictionary (
    fields t.int [
      "CPU"
      "Core"
      "Data"
      "FileSize"
      "MemoryLock"
      "NumberOfFiles"
      "NumberOfProcesses"
      "ResidentSetSize"
      "Stack"
    ]
  );
  socket = dictionary (
    fields t.str [
      "SockNodeName"
      "SockPathName"
      "SecureSocketWithKey"
      "MulticastGroup"
    ]
    // fields t.bool [ "SockPassive" ]
    // fields t.ints.unsigned [
      "SockPathOwner"
      "SockPathGroup"
      "SockPathMode"
    ]
    // {
      SockType = optional (t.enum [
        "stream"
        "dgram"
        "seqpacket"
      ]) "Socket type.";
      SockFamily = optional (t.enum [
        "IPv4"
        "IPv6"
        "IPv4v6"
        "Unix"
      ]) "Socket address family.";
      SockProtocol = optional (t.enum [
        "TCP"
        "UDP"
      ]) "Socket protocol.";
      SockServiceName = optional (t.either t.str t.port) "Service name or port number.";
      Bonjour = optional (t.either t.bool stringOrStrings) "Bonjour service registration.";
    }
  );
in
{
  options =
    fields t.bool [
      "Disabled"
      "EnableGlobbing"
      "EnableTransactions"
      "EnablePressuredExit"
      "OnDemand"
      "ServiceIPC"
      "RunAtLoad"
      "InitGroups"
      "StartOnMount"
      "Debug"
      "WaitForDebugger"
      "AbandonProcessGroup"
      "LowPriorityIO"
      "LowPriorityBackgroundIO"
      "MaterializeDatalessFiles"
      "LaunchOnlyOnce"
      "SessionCreate"
      "LegacyTimers"
    ]
    // fields t.str [
      "UserName"
      "GroupName"
      "Program"
      "BundleProgram"
      "RootDirectory"
      "WorkingDirectory"
      "StandardInPath"
      "StandardOutPath"
      "StandardErrorPath"
      "HopefullyExitsLast"
      "HopefullyExitsFirst"
    ]
    // fields strings [
      "ProgramArguments"
      "LimitLoadToHosts"
      "LimitLoadFromHosts"
      "WatchPaths"
      "QueueDirectories"
    ]
    // fields stringOrStrings [
      "LimitLoadToSessionType"
      "AssociatedBundleIdentifiers"
    ]
    // fields t.ints.unsigned [
      "TimeOut"
      "ExitTimeOut"
      "ThrottleInterval"
      "StartInterval"
    ]
    // fields (t.attrsOf strings) [
      "LimitLoadToHardware"
      "LimitLoadFromHardware"
    ]
    // fields limits [
      "SoftResourceLimits"
      "HardResourceLimits"
    ]
    // {
      Label = lib.options.mkOption {
        type = t.str;
        description = "Unique native launchd job label.";
      };
      inetdCompatibility = optional (dictionary (
        fields t.bool [ "Wait" ]
      )) "inetd compatibility settings.";
      KeepAlive = optional (t.either t.bool (
        dictionary (
          fields t.bool [
            "SuccessfulExit"
            "NetworkState"
            "Crashed"
            "AfterInitialDemand"
          ]
          // fields (t.attrsOf t.bool) [
            "PathState"
            "OtherJobEnabled"
          ]
        )
      )) "Conditions that keep the job running.";
      EnvironmentVariables = optional (t.attrsOf t.str) "Environment passed to the job.";
      Umask = optional (t.either (t.ints.between 0 511) (t.strMatching "[0-7]{1,4}")) "File creation mask as an integer or octal string.";
      Nice = optional (t.ints.between (-20) 20) "Process scheduling priority.";
      StartCalendarInterval = optional (t.either calendar (t.nonEmptyListOf calendar)) "Calendar launch schedule.";
      ProcessType = optional (t.enum [
        "Background"
        "Standard"
        "Adaptive"
        "Interactive"
      ]) "Resource management policy.";
      MachServices = optional (t.attrsOf (
        t.either t.bool (
          dictionary (
            fields t.bool [
              "ResetAtClose"
              "HideUntilCheckIn"
            ]
          )
        )
      )) "Mach services advertised by the job.";
      Sockets = optional (t.attrsOf (t.either socket (t.nonEmptyListOf socket))) "Sockets activated on demand.";
      LaunchEvents = optional (t.attrsOf (t.attrsOf (t.attrsOf plistType))) "Event subsystem descriptors.";
    };
}
