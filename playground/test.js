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

test("async multiplySlow resolves a Promise", async () => {
  const pending = api.multiplySlow(6, 7);
  assert.ok(pending instanceof Promise);
  assert.strictEqual(await pending, 42);
});

test("async failing rejects a Zig error, resolves otherwise", async () => {
  await assert.rejects(() => api.failing(-1), /MustBeNonNegative/);
  assert.strictEqual(await api.failing(9), 9);
});

test("threadsafe countTo calls back from a worker thread", async () => {
  const got = [];
  await new Promise((resolve) => {
    let n = 0;
    api.countTo(3, (v) => {
      got.push(v);
      if (++n === 3) resolve();
    });
  });
  assert.deepStrictEqual(got, [1, 2, 3]);
});

test("index.d.ts declares async and callback signatures", () => {
  const dts = fs.readFileSync("./index.d.ts", "utf8");
  assert.match(dts, /export function multiplySlow\(arg0: number, arg1: number\): Promise<number>;/);
  assert.match(dts, /export function countTo\(arg0: number, arg1: any\): void;/);
});
