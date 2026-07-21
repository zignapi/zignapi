const test = require("node:test");
const assert = require("node:assert");

const addon = require("./zig-out/lib/addon.node");

test("add(2, 3) === 5", () => {
  assert.strictEqual(addon.add(2, 3), 5);
});
