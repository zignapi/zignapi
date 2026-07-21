import { parseArgs } from "node:util";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";
import { resolveZigbindSources, runZig } from "./zig.js";

const TEMPLATES_DIR = join(dirname(fileURLToPath(import.meta.url)), "templates");
const PLACEHOLDER = /__NAME__/g;

const NEW_HELP = `zigbind new — scaffold a new addon project

Usage:
  zigbind new <name>

Creates ./<name> from the built-in template, substituting the project name,
then wires up the zigbind Zig dependency with "zig fetch --save".
<name> must be a valid Zig identifier (letters, digits, underscore; not
starting with a digit).
`;

export async function runNew(argv) {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      help: { type: "boolean", short: "h", default: false },
    },
  });

  if (values.help || positionals.length === 0) {
    process.stdout.write(NEW_HELP);
    return;
  }

  const name = positionals[0];
  validateName(name);

  const target = join(process.cwd(), name);
  if (existsSync(target)) {
    throw new Error(`directory '${name}' already exists`);
  }

  copyTemplate(TEMPLATES_DIR, target, name);
  addZigbindDependency(target);

  process.stdout.write(
    `✔ created ${name}/\n\n` +
      `Next steps:\n` +
      `  cd ${name}\n` +
      `  zigbind build      # produces ${name}.node\n` +
      `  node --test\n`,
  );
}

/// Add the `zigbind` Zig dependency to the freshly scaffolded project by
/// running `zig fetch --save` against the sources shipped with the CLI. This
/// pins zigbind by content hash and removes any reliance on a fixed relative
/// path. Non-fatal: if Zig isn't available, tell the user how to do it later.
function addZigbindDependency(target) {
  let sources;
  try {
    sources = resolveZigbindSources();
    runZig(target, ["fetch", "--save=zigbind", sources], {
      repairZon: join(target, "build.zig.zon"),
    });
    process.stdout.write("✔ added zigbind dependency (zig fetch --save)\n");
  } catch (err) {
    process.stderr.write(
      `warning: could not add the zigbind dependency automatically ` +
        `(${err.message}).\nRun this inside the project once Zig 0.16.0 is ` +
        `available:\n  zig fetch --save=zigbind ${sources ?? "<path-to-zigbind/native>"}\n`,
    );
  }
}

/// Recursively copy the template tree, substituting the project name in both
/// file contents and file/directory names. `dot-` prefixed template names are
/// emitted as dotfiles (so e.g. `dot-gitignore` becomes `.gitignore`), which
/// also sidesteps npm's habit of renaming a packaged `.gitignore`.
function copyTemplate(srcDir, destDir, name) {
  mkdirSync(destDir, { recursive: true });
  for (const entry of readdirSync(srcDir, { withFileTypes: true })) {
    const outName = entry.name
      .replace(PLACEHOLDER, name)
      .replace(/^dot-/, ".");
    const src = join(srcDir, entry.name);
    const dest = join(destDir, outName);
    if (entry.isDirectory()) {
      copyTemplate(src, dest, name);
    } else {
      const content = readFileSync(src, "utf8").replace(PLACEHOLDER, name);
      writeFileSync(dest, content);
    }
  }
}

function validateName(name) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) {
    throw new Error(
      `invalid project name '${name}' (use letters, digits and underscores; ` +
        `must not start with a digit)`,
    );
  }
}
