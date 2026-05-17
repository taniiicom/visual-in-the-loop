#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const apiKey = process.env.GEMINI_API_KEY ?? process.env.GOOGLE_API_KEY;
if (!apiKey) {
  process.stderr.write("[visual-in-the-loop] GEMINI_API_KEY (or GOOGLE_API_KEY) is not set\n");
  process.exit(1);
}

const planText = readFileSync(0, "utf-8").trim();
if (!planText) {
  process.stderr.write("[visual-in-the-loop] empty stdin\n");
  process.exit(1);
}

const here = dirname(fileURLToPath(import.meta.url));
const template = readFileSync(join(here, "..", "references", "prompt-template.md"), "utf-8");
const prompt = template.replace("{plan}", planText);

const url =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent";

let resp;
try {
  resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseModalities: ["TEXT", "IMAGE"] },
    }),
  });
} catch (err) {
  process.stderr.write(`[visual-in-the-loop] fetch failed: ${err.message}\n`);
  process.exit(1);
}

if (!resp.ok) {
  const body = await resp.text().catch(() => "");
  process.stderr.write(`[visual-in-the-loop] API ${resp.status}: ${body.slice(0, 500)}\n`);
  process.exit(1);
}

const json = await resp.json();
const part = json.candidates?.[0]?.content?.parts?.find((p) => p.inlineData);
if (!part) {
  process.stderr.write("[visual-in-the-loop] no image part in response\n");
  process.exit(1);
}

const outDir = join(tmpdir(), "visual-in-the-loop");
mkdirSync(outDir, { recursive: true });
const out = join(outDir, `${Date.now()}.png`);
writeFileSync(out, Buffer.from(part.inlineData.data, "base64"));
process.stdout.write(out + "\n");
