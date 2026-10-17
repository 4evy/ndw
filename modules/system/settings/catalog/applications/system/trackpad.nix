{ lib, settingsLib, ... }:
let
  inherit (settingsLib)
    boolKeys
    integerBool
    inverted
    bool
    eachKey
    boolAs
    numberBetween
    global
    user
    byHost
    enum
    restarts
    allowedWhen
    conflictsWith
    ;

  page = settingsLib.systemPage "Trackpad" "com.apple.settings.trackpad";
  tabControls = tab: page.navigate tab "AXRadioButton:${tab}";
  pointAndClick = tabControls "Point & Click";
  scrollAndZoom = tabControls "Scroll & Zoom";
  moreGestures = tabControls "More Gestures";
  option = name: "applications.systemSettings.trackpad.${name}";

  gesture = name: hostName: {
    driver = user "com.apple.AppleMultitouchTrackpad" name;
    bluetooth = user "com.apple.driver.AppleBluetoothMultitouch.trackpad" name;
    host = byHost (global "com.apple.trackpad.${hostName}");
  };
  everywhere = value: {
    driver = value;
    bluetooth = value;
    host = value;
  };
  dock = name: user "com.apple.dock" name;

  gestureSwitch =
    {
      tab,
      ui,
      name,
      hostName,
      on ? true,
      off ? false,
    }:
    (tabControls tab).toggle {
      inherit ui;
      storage = gesture name hostName;
      value = eachKey (boolAs on off);
    };

  threeFingerHorizontal = gesture "TrackpadThreeFingerHorizSwipeGesture" "threeFingerHorizSwipeGesture";
  fourFingerHorizontal = gesture "TrackpadFourFingerHorizSwipeGesture" "fourFingerHorizSwipeGesture";
  threeFingerVertical = gesture "TrackpadThreeFingerVertSwipeGesture" "threeFingerVertSwipeGesture";
  fourFingerVertical = gesture "TrackpadFourFingerVertSwipeGesture" "fourFingerVertSwipeGesture";
  threeFingerTap = gesture "TrackpadThreeFingerTapGesture" "threeFingerTapGesture";

  prefixed = prefix: attrs: lib.mapAttrs' (name: lib.nameValuePair "${prefix}${name}") attrs;

  verticalSwipe =
    {
      ui,
      direction,
      enabled,
      other,
    }:
    moreGestures.select {
      inherit ui;
      storage = {
        inherit enabled;
      }
      // prefixed "three" threeFingerVertical
      // prefixed "four" fourFingerVertical;
      value = enum {
        Off = {
          enabled = false;
        };
        "Swipe ${direction} with Three Fingers" = {
          enabled = true;
        }
        // prefixed "three" (everywhere 2)
        // prefixed "four" (everywhere 0);
        "Swipe ${direction} with Four Fingers" = {
          enabled = true;
        }
        // prefixed "three" (everywhere 0)
        // prefixed "four" (everywhere 2);
      };
      behaviors = [ (restarts "Dock") ];
      relations = [
        (
          context:
          lib.optionals (context.value != "Off") (
            conflictsWith (option "moreGestures.${other}") (
              value: value != "Off" && lib.hasInfix "Four" value != lib.hasInfix "Four" context.value
            ) "Mission Control and App Exposé swipe with the same number of fingers" context
          )
        )
      ];
      control = "AXPopUpButton:${ui}";
      choices = [
        "Off"
        "Swipe ${direction} with Three Fingers"
        "Swipe ${direction} with Four Fingers"
      ];
    };
in
{
  pointAndClick = {
    trackingSpeed = pointAndClick.preference "Tracking speed" (global "com.apple.trackpad.scaling") (
      numberBetween 0.0 3.0
    );

    click = pointAndClick.setting {
      ui = "Click";
      storage = {
        first = user "com.apple.AppleMultitouchTrackpad" "FirstClickThreshold";
        second = user "com.apple.AppleMultitouchTrackpad" "SecondClickThreshold";
      };
      value = eachKey (enum {
        Light = 0;
        Medium = 1;
        Firm = 2;
      });
      verify.expect = {
        Light = {
          "AXSlider:ClickPressureSlider" = 0;
        };
        Firm = {
          "AXSlider:ClickPressureSlider" = 2;
        };
      };
    };

    forceClickAndHapticFeedback = pointAndClick.toggle {
      ui = "Force Click and haptic feedback";
      storage = {
        detents = user "com.apple.AppleMultitouchTrackpad" "ActuateDetents";
        suppressed = user "com.apple.AppleMultitouchTrackpad" "ForceSuppressed";
      };
      value = boolKeys {
        detents = integerBool;
        suppressed = inverted bool;
      };
    };

    lookUpAndDataDetectors = pointAndClick.select {
      ui = "Look up & data detectors";
      storage = {
        forceClick = global "com.apple.trackpad.forceClick";
      }
      // threeFingerTap;
      value = enum {
        Off = {
          forceClick = false;
        }
        // everywhere 0;
        "Force Click with One Finger" = {
          forceClick = true;
        }
        // everywhere 0;
        "Tap with Three Fingers" = {
          forceClick = false;
        }
        // everywhere 2;
      };
      relations = [
        (allowedWhen "Force Click with One Finger" (option "pointAndClick.forceClickAndHapticFeedback") (
          enabled: enabled
        ) "Force Click needs Force Click and haptic feedback")
      ];
    };

    secondaryClick = pointAndClick.select {
      ui = "Secondary click";
      storage = {
        twoFingers = user "com.apple.AppleMultitouchTrackpad" "TrackpadRightClick";
        twoFingersBluetooth = user "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadRightClick";
        twoFingersHost = byHost (global "com.apple.trackpad.enableSecondaryClick");
        corner = user "com.apple.AppleMultitouchTrackpad" "TrackpadCornerSecondaryClick";
        cornerBluetooth = user "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadCornerSecondaryClick";
        cornerHost = byHost (global "com.apple.trackpad.trackpadCornerClickBehavior");
        contextMenu = global "ContextMenuGesture";
      };
      value =
        let
          twoFingers = on: {
            twoFingers = on;
            twoFingersBluetooth = on;
            twoFingersHost = on;
          };
          corner = device: host: {
            corner = device;
            cornerBluetooth = device;
            cornerHost = host;
          };
        in
        enum {
          Off = twoFingers false // corner 0 0 // { contextMenu = 0; };
          "Click or Tap with Two Fingers" = twoFingers true // corner 0 0 // { contextMenu = 1; };
          "Click in Bottom Right Corner" = twoFingers false // corner 2 1 // { contextMenu = 1; };
          "Click in Bottom Left Corner" = twoFingers false // corner 1 3 // { contextMenu = 1; };
        };
      choices = [
        "Off"
        "Click in Bottom Right Corner"
        "Click or Tap with Two Fingers"
      ];
    };

    tapToClick = pointAndClick.toggle {
      ui = "Tap to click";
      storage = {
        driver = user "com.apple.AppleMultitouchTrackpad" "Clicking";
        bluetooth = user "com.apple.driver.AppleBluetoothMultitouch.trackpad" "Clicking";
        host = byHost (global "com.apple.mouse.tapBehavior");
      };
      value = boolKeys {
        driver = bool;
        bluetooth = bool;
        host = integerBool;
      };
    };
  };

  scrollAndZoom = {
    naturalScrolling = scrollAndZoom.toggle {
      ui = "Natural scrolling";
      storage = global "com.apple.swipescrolldirection";
    };

    zoomInOrOut = gestureSwitch {
      tab = "Scroll & Zoom";
      ui = "Zoom in or out";
      name = "TrackpadPinch";
      hostName = "pinchGesture";
    };

    smartZoom = gestureSwitch {
      tab = "Scroll & Zoom";
      ui = "Smart zoom";
      name = "TrackpadTwoFingerDoubleTapGesture";
      hostName = "twoFingerDoubleTapGesture";
      on = 1;
      off = 0;
    };

    rotate = gestureSwitch {
      tab = "Scroll & Zoom";
      ui = "Rotate";
      name = "TrackpadRotate";
      hostName = "rotateGesture";
    };
  };

  # Full-screen applications is applied first, so a three-finger page swipe
  # wins where both are set
  moreGestures = {
    swipeBetweenFullScreenApplications = moreGestures.select {
      ui = "Swipe between full-screen applications";
      storage = prefixed "three" threeFingerHorizontal // prefixed "four" fourFingerHorizontal;
      value = enum {
        Off = prefixed "three" (everywhere 0) // prefixed "four" (everywhere 0);
        "Swipe Left or Right with Three Fingers" =
          prefixed "three" (everywhere 2) // prefixed "four" (everywhere 0);
        "Swipe Left or Right with Four Fingers" =
          prefixed "three" (everywhere 0) // prefixed "four" (everywhere 2);
      };
    };

    swipeBetweenPages = moreGestures.select {
      ui = "Swipe between pages";
      storage = {
        scrolls = global "AppleEnableSwipeNavigateWithScrolls";
      }
      // threeFingerHorizontal;
      value = enum {
        Off = {
          scrolls = false;
        };
        "Scroll Left or Right with Two Fingers" = {
          scrolls = true;
        };
        "Swipe with Three Fingers" = {
          scrolls = false;
        }
        // everywhere 1;
        "Swipe with Two or Three Fingers" = {
          scrolls = true;
        }
        // everywhere 1;
      };
      relations = [
        (
          context:
          lib.optionals (lib.hasInfix "Three" context.value) (
            conflictsWith (option "moreGestures.swipeBetweenFullScreenApplications") (
              fullScreen: fullScreen == "Swipe Left or Right with Three Fingers"
            ) "both would use the three-finger swipe" context
          )
        )
      ];
      choices = [
        "Off"
        "Swipe with Two or Three Fingers"
        "Scroll Left or Right with Two Fingers"
      ];
    };

    notificationCenter = gestureSwitch {
      tab = "More Gestures";
      ui = "Notification Center";
      name = "TrackpadTwoFingerFromRightEdgeSwipeGesture";
      hostName = "twoFingerFromRightEdgeSwipeGesture";
      on = 3;
      off = 0;
    };

    missionControl = verticalSwipe {
      ui = "Mission Control";
      direction = "Up";
      enabled = dock "showMissionControlGestureEnabled";
      other = "appExpose";
    };

    appExpose = verticalSwipe {
      ui = "App Exposé";
      direction = "Down";
      enabled = dock "showAppExposeGestureEnabled";
      other = "missionControl";
    };

    showDesktop = moreGestures.toggle {
      ui = "Show Desktop";
      storage = dock "showDesktopGestureEnabled";
      behaviors = [ (restarts "Dock") ];
    };
  };
}
