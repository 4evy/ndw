ObjC.import("Foundation");
ObjC.import("CoreGraphics");
ObjC.bindFunction("getuid", ["unsigned int", []]);

/**
 * @param {readonly string[]} argv Automatic and dark mode as "true" or "false"
 * @returns {"deferred" | undefined} Defers login preferences to Bash when the
 *   current process has no window server session belonging to its user
 */
// biome-ignore lint/correctness/noUnusedVariables: JXA invokes run as the script entry point
function run(argv) {
  if (
    argv.length !== 2 ||
    argv.some((value) => !["true", "false"].includes(value))
  )
    throw new Error("Expected automatic and dark appearance booleans");
  const [automatic, dark] = argv.map((value) => value === "true");

  // Another user activated through sudo inherits the caller's session
  // System Events cannot reach that user, so Bash writes login preferences
  /** @type {{ kCGSSessionUserIDKey: number } | null} */
  const session = ObjC.deepUnwrap(
    ObjC.castRefToObject($.CGSessionCopyCurrentDictionary()),
  );
  if (!session || session.kCGSSessionUserIDKey !== $.getuid())
    return "deferred";

  if (
    !$.NSBundle.bundleWithPath(
      "/System/Library/PrivateFrameworks/SkyLight.framework",
    ).load
  )
    throw new Error("SkyLight is unavailable");
  ObjC.bindFunction("SLSSetAppearanceThemeSwitchesAutomatically", [
    "void",
    ["bool"],
  ]);
  $.SLSSetAppearanceThemeSwitchesAutomatically(automatic);
  if (!automatic)
    Application("System Events").appearancePreferences.darkMode = dark;
}
