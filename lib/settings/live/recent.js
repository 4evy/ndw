/**
 * @typedef {object} SharedFileList An LSSharedFileListRef exposed through JXA
 * @property {() => boolean} isNil
 */

ObjC.import("CoreServices");
ObjC.bindFunction("LSSharedFileListCreate", ["id", ["void *", "id", "void *"]]);
ObjC.bindFunction("LSSharedFileListSetProperty", ["int", ["id", "id", "id"]]);

/** @type {readonly string[]} */
const recentLists = ["RecentApplications", "RecentDocuments", "RecentServers"];

/**
 * @param {readonly string[]} argv A single non-negative integer item count
 * @returns {void}
 */
// biome-ignore lint/correctness/noUnusedVariables: JXA invokes run as the script entry point
function run(argv) {
  const [value] = argv;
  const amount = Number(value);
  if (
    argv.length !== 1 ||
    value === undefined ||
    value.trim() === "" ||
    !Number.isInteger(amount) ||
    amount < 0
  )
    throw new Error("Recent item count must be a non-negative integer");
  for (const name of recentLists) {
    /** @type {SharedFileList} */
    const list = $.LSSharedFileListCreate(
      null,
      $(`com.apple.LSSharedFileList.${name}`),
      null,
    );
    if (list.isNil())
      throw new Error(`Recent item list is unavailable: ${name}`);
    const status = $.LSSharedFileListSetProperty(
      list,
      $("com.apple.LSSharedFileList.MaxAmount"),
      $(amount),
    );
    if (status !== 0)
      throw new Error(`Could not set recent item count for ${name}`);
  }
}
