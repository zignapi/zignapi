const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");

const addon = require("./zig-out/lib/addon.node");
const api = require("./index.js");

test("add(2, 3) === 5", () => {
  assert.strictEqual(addon.add(2, 3), 5);
});

test("index.js loader re-exports add and hides internals", () => {
  assert.strictEqual(api.add(2, 3), 5);
  assert.strictEqual(api.__zignapi_dts__, undefined);
});

test("index.d.ts declares add", () => {
  const dts = fs.readFileSync("./index.d.ts", "utf8");
  assert.match(dts, /export function add\(arg0: number, arg1: number\): number;/);
});
