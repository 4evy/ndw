/**
 * @typedef {object} DisplayClient
 * @property {() => boolean} isNil
 * @property {(enabled: boolean) => boolean} setEnabled
 * @property {(mode: number) => boolean} setMode
 * @property {(strength: number, commit: boolean) => boolean} setStrengthCommit
 *
 * @typedef {(client: DisplayClient) => boolean} DisplayMutation
 * @typedef {object} DisplayCommand
 * @property {string} client
 * @property {string} method
 * @property {number} arity
 * @property {(args: readonly string[]) => DisplayMutation} parse
 */

ObjC.import("Foundation");

/** @type {readonly DisplayCommand[]} */
const commands = [
  {
    client: "CBTrueToneClient",
    method: "setEnabled",
    arity: 1,
    parse: ([enabled]) => {
      const value = parseBoolean(enabled);
      return (client) => client.setEnabled(value);
    },
  },
  {
    client: "CBBlueLightClient",
    method: "setMode",
    arity: 1,
    parse: ([mode]) => {
      const value = parseNumber(mode);
      return (client) => client.setMode(value);
    },
  },
  {
    client: "CBBlueLightClient",
    method: "setStrengthCommit",
    arity: 2,
    parse: ([strength, commit]) => {
      const value = parseNumber(strength);
      const committed = parseBoolean(commit);
      return (client) => client.setStrengthCommit(value, committed);
    },
  },
];

/**
 * @param {string | undefined} value
 * @returns {boolean}
 */
function parseBoolean(value) {
  if (value !== "true" && value !== "false")
    throw new Error("Expected a display setting boolean");
  return value === "true";
}

/**
 * @param {string | undefined} value
 * @returns {number}
 */
function parseNumber(value) {
  const parsed = Number(value);
  if (value === undefined || value.trim() === "" || !Number.isFinite(parsed))
    throw new Error("Expected a finite display setting number");
  return parsed;
}

/**
 * @param {readonly string[]} argv Client class, method, and scalar arguments
 * @returns {void}
 */
// biome-ignore lint/correctness/noUnusedVariables: JXA invokes run as the script entry point
function run(argv) {
  const [client, method, ...args] = argv;
  const command = commands.find(
    (entry) => entry.client === client && entry.method === method,
  );
  if (!command || args.length !== command.arity)
    throw new Error("Unsupported display setting or arguments");

  // Parse everything before loading a framework or changing a setting
  const apply = command.parse(args);
  if (
    !$.NSBundle.bundleWithPath(
      "/System/Library/PrivateFrameworks/CoreBrightness.framework",
    ).load
  )
    throw new Error("CoreBrightness is unavailable");

  /** @type {DisplayClient} */
  const instance = $.NSClassFromString(command.client).alloc.init;
  if (instance.isNil())
    throw new Error(`Display client is unavailable: ${command.client}`);
  if (apply(instance) === false)
    throw new Error(
      `Display setting was refused: ${command.client}.${command.method}`,
    );
}
