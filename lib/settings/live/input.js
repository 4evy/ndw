/**
 * @typedef {object} InputSource A Carbon TISInputSourceRef exposed through JXA
 * @typedef {object} NativeString An NSString exposed through JXA
 * @typedef {object} InputSourceList
 * @property {number} count
 * @property {(index: number) => InputSource} objectAtIndex
 *
 * @typedef {{ id: string, source: InputSource }} KeyboardSource
 */

ObjC.import("Carbon");

/**
 * @param {InputSource} source
 * @param {NativeString} name Carbon's input source property name
 * @returns {string}
 */
function property(source, name) {
  return ObjC.unwrap(
    ObjC.castRefToObject($.TISGetInputSourceProperty(source, name)),
  );
}

/**
 * @param {boolean} includeDisabled
 * @returns {KeyboardSource[]}
 */
function sources(includeDisabled) {
  /** @type {InputSourceList} */
  const list = ObjC.castRefToObject(
    $.TISCreateInputSourceList($(), includeDisabled),
  );
  return Array.from({ length: list.count }, (_, at) => list.objectAtIndex(at))
    .filter(
      (source) =>
        property(source, $.kTISPropertyInputSourceCategory) ===
        "TISCategoryKeyboardInputSource",
    )
    .map((source) => ({
      id: property(source, $.kTISPropertyInputSourceID),
      source,
    }));
}

/**
 * @param {readonly string[]} argv "list", or "set" followed by source IDs
 * @returns {string | undefined} Enabled source IDs as JSON when listing
 */
// biome-ignore lint/correctness/noUnusedVariables: JXA invokes run as the script entry point
function run(argv) {
  const [command, ...ids] = argv;
  if (command === "list" && ids.length === 0)
    return JSON.stringify(sources(false).map(({ id }) => id));
  if (command !== "set" || ids.length === 0)
    throw new Error("Expected list, or set followed by input source IDs");

  const wanted = new Set(ids);
  const available = new Map(sources(true).map((entry) => [entry.id, entry]));
  if (ids.some((id) => !available.has(id)))
    throw new Error(
      "Input sources must name at least one installed keyboard input source",
    );

  // Enable first so the user always has a keyboard input source
  for (const { id, source } of available.values()) {
    if (wanted.has(id) && $.TISEnableInputSource(source) !== 0)
      throw new Error(`Could not enable ${id}`);
  }
  const enabled = sources(false);
  if (!enabled.some(({ id }) => wanted.has(id)))
    throw new Error("No requested keyboard input source is enabled");
  for (const { id, source } of enabled) {
    if (!wanted.has(id) && $.TISDisableInputSource(source) !== 0)
      throw new Error(`Could not disable ${id}`);
  }
}
