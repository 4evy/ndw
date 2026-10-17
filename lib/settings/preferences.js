/**
 * @typedef {null | boolean | number | string} JSONScalar
 * @typedef {JSONScalar | JSONValue[] |
 *   { [key: string]: JSONValue }} JSONValue
 * @typedef {ReturnType<typeof JSON.rawJSON>} RawNumber
 * @typedef {JSONScalar | RawNumber | EncodedValue[] |
 *   { [key: string]: EncodedValue }} EncodedValue
 *
 * @typedef {object} Manifest
 * @property {{ id: string, file: string, keys: string[] }[]} domains
 * @property {{ option: string, file: string }[]} reads
 * @property {{ option: string, directory: string }[]} snapshots
 *
 * @typedef {{ raw: string, json?: JSONValue }} ReaderOutput
 * @typedef {object} State
 * @property {Record<string, Record<string, EncodedValue>>} domains
 * @property {Record<string, ReaderOutput>} reads
 * @property {Record<string, string>} snapshots
 *
 * @typedef {object} NativeObject
 * @property {() => boolean} isNil
 * @property {(type: unknown) => boolean} isKindOfClass
 *
 * @typedef {NativeObject & {
 *   allKeys: NativeObject,
 *   objectForKey(key: string | NativeObject): NativeObject
 * }} NativeDictionary
 *
 * @typedef {NativeObject & {
 *   base64EncodedStringWithOptions(options: number): NativeObject
 * }} NativeData
 *
 * @typedef {NativeObject & {
 *   objCType: NativeObject,
 *   stringValue: NativeObject
 * }} NativeNumber
 */

ObjC.import("Foundation");

/**
 * @param {string} path
 * @returns {NativeDictionary}
 */
function readDictionary(path) {
  const contents = $.NSDictionary.dictionaryWithContentsOfFile(path);
  return contents.isNil() ? $.NSDictionary.dictionary : contents;
}

/**
 * @param {string} path
 * @returns {string}
 */
function readText(path) {
  const contents = $.NSString.stringWithContentsOfFileEncodingError(
    path,
    $.NSUTF8StringEncoding,
    null,
  );
  return contents.isNil() ? "" : ObjC.unwrap(contents).trim();
}

/**
 * @param {NativeDictionary} dictionary
 * @param {readonly (string | NativeObject)[]} keys
 * @returns {Record<string, EncodedValue>}
 */
function encodeEntries(dictionary, keys) {
  return Object.fromEntries(
    keys.flatMap((key) => {
      const value = dictionary.objectForKey(key);
      return value.isNil() ? [] : [[ObjC.unwrap(key), encodeValue(value)]];
    }),
  );
}

/**
 * @param {NativeObject} value A property list value wrapped by JXA
 * @returns {EncodedValue}
 */
function encodeValue(value) {
  if (value.isKindOfClass($.NSDictionary)) {
    const dictionary = /** @type {NativeDictionary} */ (value);
    /** @type {NativeObject[]} */
    const keys = ObjC.unwrap(dictionary.allKeys);
    return encodeEntries(dictionary, keys);
  }
  if (value.isKindOfClass($.NSArray)) {
    /** @type {NativeObject[]} */
    const items = ObjC.unwrap(value);
    return items.map(encodeValue);
  }
  // JSON represents plist data and dates as base64 and ISO 8601 strings
  if (value.isKindOfClass($.NSData))
    return ObjC.unwrap(
      /** @type {NativeData} */ (value).base64EncodedStringWithOptions(0),
    );
  if (value.isKindOfClass($.NSDate))
    return ObjC.unwrap(
      $.NSISO8601DateFormatter.alloc.init.stringFromDate(value),
    );
  /** @type {unknown} */
  const unwrapped = ObjC.unwrap(value);
  if (typeof unwrapped === "string" || typeof unwrapped === "boolean")
    return unwrapped;
  if (typeof unwrapped !== "number" || !value.isKindOfClass($.NSNumber))
    throw new Error("Unsupported property list value");
  if (!Number.isInteger(unwrapped)) return unwrapped;

  const number = /** @type {NativeNumber} */ (value);
  const type = ObjC.unwrap(number.objCType);
  if (type !== "f" && type !== "d") {
    // Preserve native integer digits before JavaScript rounds them
    const decimal = ObjC.unwrap(number.stringValue);
    const integer = BigInt(decimal);
    if (integer >= -9223372036854775808n && integer <= 9223372036854775807n)
      return JSON.rawJSON(decimal);
  }

  // Nix accepts larger numbers as floats, and integral reals stay distinct
  if (!Number.isSafeInteger(unwrapped))
    return JSON.rawJSON(unwrapped.toExponential());
  return type === "f" || type === "d"
    ? JSON.rawJSON(unwrapped.toFixed(1))
    : unwrapped;
}

/**
 * @param {string} path
 * @returns {ReaderOutput}
 */
function readOutput(path) {
  const raw = readText(path);
  try {
    return { raw, json: JSON.parse(raw) };
  } catch {
    return { raw };
  }
}

/**
 * Prints stored values and reader output from the collection manifest
 * @param {readonly string[]} argv Collection directory as the first argument
 * @returns {string} Collected state encoded for Nix's JSON reader
 */
// biome-ignore lint/correctness/noUnusedVariables: JXA invokes run as the script entry point
function run(argv) {
  const [dir] = argv;
  if (dir === undefined) throw new Error("Expected a collection directory");
  /** @type {Manifest} */
  const input = JSON.parse(readText(`${dir}/manifest.json`));
  /** @type {State} */
  const state = {
    domains: Object.fromEntries(
      input.domains.map(({ id, file, keys }) => [
        id,
        encodeEntries(readDictionary(`${dir}/${file}`), keys),
      ]),
    ),
    reads: Object.fromEntries(
      input.reads.map(({ option, file }) => [
        option,
        readOutput(`${dir}/${file}`),
      ]),
    ),
    snapshots: Object.fromEntries(
      input.snapshots.map(({ option, directory }) => [option, directory]),
    ),
  };
  return JSON.stringify(state);
}
