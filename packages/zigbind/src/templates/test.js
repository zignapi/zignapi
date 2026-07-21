const test = require("node:test");
const assert = require("node:assert");

const addon = require("./zig-out/lib/__NAME__.node");

test("add(2, 3) === 5", () => {
  assert.strictEqual(addon.add(2, 3), 5);
});

test("greet returns a string", () => {
  assert.strictEqual(addon.greet("world"), "hello from Zig");
});
