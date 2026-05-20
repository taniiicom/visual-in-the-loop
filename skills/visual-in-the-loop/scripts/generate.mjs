#!/usr/bin/env node
// Router: read stdin, generate one or more images via the selected provider,
// save each PNG to $TMPDIR/visual-in-the-loop/, print one TSV line per image
// to stdout: `<path>\t<title>` (title may be empty).
//
// Input format on stdin:
//   - JSON array (detected by leading `[`) of either:
//       ["content 1", "content 2"]
//     or
//       [{"title": "...", "content": "..."}, ...]
//   - Anything else → treated as a single plain-text content (single image).
//
// All failures: stderr WARN + exit 1 (run.sh converts to exit 0).

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

function fail(msg) {
  process.stderr.write(`[visual-in-the-loop] ${msg}\n`);
  process.exit(1);
}

const stdin = readFileSync(0, "utf-8").trim();
if (!stdin) fail("empty stdin");

// Normalize input to: [{ title, content }, ...]
let items;
if (stdin.startsWith("[")) {
  let parsed;
  try {
    parsed = JSON.parse(stdin);
  } catch (err) {
    fail(`stdin looks like JSON but failed to parse: ${err.message}`);
  }
  if (!Array.isArray(parsed)) fail("JSON input must be an array");
  if (parsed.length === 0) fail("JSON array is empty");
  items = parsed.map((item, idx) => {
    if (typeof item === "string") return { title: "", content: item };
    if (item && typeof item === "object") {
      return { title: item.title ?? "", content: item.content ?? "" };
    }
    fail(`item ${idx} is not a string or object`);
  });
} else {
  items = [{ title: "", content: stdin }];
}

items = items.filter((i) => i.content && i.content.trim());
if (items.length === 0) fail("no content to render");

const here = dirname(fileURLToPath(import.meta.url));
const template = readFileSync(
  join(here, "..", "references", "prompt-template.md"),
  "utf-8",
);

const provider = (process.env.VITL_PROVIDER ?? "gemini").toLowerCase();
const model = process.env.VITL_MODEL || "";

let mod;
try {
  mod = await import(`./providers/${provider}.mjs`);
} catch (err) {
  fail(`unknown provider "${provider}": ${err.message}`);
}

const outDir = join(tmpdir(), "visual-in-the-loop");
mkdirSync(outDir, { recursive: true });

const baseTs = Date.now();
let successCount = 0;

for (let i = 0; i < items.length; i++) {
  const { title, content } = items[i];
  const prompt = template.replace("{plan}", content);
  const result = await mod.generate({ prompt, model, env: process.env });
  if (!result.ok) {
    process.stderr.write(
      `[visual-in-the-loop] slide ${i + 1}/${items.length} failed: ${result.error}\n`,
    );
    continue;
  }
  const out = join(outDir, `${baseTs}-${i + 1}.png`);
  writeFileSync(out, result.png);
  // Strip tab/newline from title to keep TSV well-formed
  const safeTitle = (title || "").replace(/[\t\n\r]/g, " ").trim();
  process.stdout.write(`${out}\t${safeTitle}\n`);
  successCount++;
}

if (successCount === 0) process.exit(1);
