#!/usr/bin/env node
// Read the plan text from stdin, generate ONE image of it via the configured
// provider, save the PNG, and print its path to stdout.
//
// The whole plan becomes a single diagram. The stdin text is passed to the
// model verbatim (only wrapped by references/prompt-template.md) — do not
// pre-summarize or rewrite it upstream; the model needs the real plan.
//
// All failures: stderr WARN + exit 1 (run.sh converts that to exit 0).

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
const template = readFileSync(
  join(here, "..", "references", "prompt-template.md"),
  "utf-8",
);

// {language}: an optional " in <language>" clause. VITL_LANG is set by run.sh
// from the agent's `--lang` argument (the language the conversation is being
// held in). Function replacers avoid `$` patterns in the substituted text
// being interpreted.
const lang = (process.env.VITL_LANG || "").trim();
const languageClause = lang ? ` in ${lang}` : "";
const prompt = template
  .replace("{language}", () => languageClause)
  .replace("{plan}", () => planText);

const provider = (process.env.VITL_PROVIDER ?? "gemini").toLowerCase();
const model = process.env.VITL_MODEL || "";

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
