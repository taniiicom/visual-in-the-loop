#!/usr/bin/env node
// Router: read stdin, route to provider, save PNG, print path.
// All failures: stderr WARN + exit 1 (run.sh converts to exit 0 to keep the agent moving).

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

function fail(msg) {
  process.stderr.write(`[visual-in-the-loop] ${msg}\n`);
  process.exit(1);
}

const planText = readFileSync(0, "utf-8").trim();
if (!planText) fail("empty stdin");

const here = dirname(fileURLToPath(import.meta.url));
const template = readFileSync(join(here, "..", "references", "prompt-template.md"), "utf-8");
const prompt = template.replace("{plan}", planText);

const provider = (process.env.VITL_PROVIDER ?? "gemini").toLowerCase();
const model = process.env.VITL_MODEL || ""; // empty → provider picks its default

let mod;
try {
  mod = await import(`./providers/${provider}.mjs`);
} catch (err) {
  fail(`unknown provider "${provider}": ${err.message}`);
}

const result = await mod.generate({ prompt, model, env: process.env });
if (!result.ok) fail(result.error);

const outDir = join(tmpdir(), "visual-in-the-loop");
mkdirSync(outDir, { recursive: true });
const out = join(outDir, `${Date.now()}.png`);
writeFileSync(out, result.png);
process.stdout.write(out + "\n");
