// Vertex AI provider — calls the publishers/google/models/<model>:generateContent
// endpoint on aiplatform.googleapis.com. Same payload shape as Gemini API, but
// OAuth2 auth is required.
//
// Auth strategy: shell out to `gcloud auth application-default print-access-token`.
// This keeps the skill zero-dep (no google-auth-library) and works if the user
// already has gcloud configured (the common case for Vertex AI users).
//
// If gcloud is unavailable or unauthenticated, we return a clear error and the
// caller's fail-safe handling takes over.

import { execFileSync } from "node:child_process";

const DEFAULT_MODEL = "gemini-3-pro-image-preview";

function getAccessToken() {
  try {
    const tok = execFileSync(
      "gcloud",
      ["auth", "application-default", "print-access-token"],
      { encoding: "utf-8", stdio: ["ignore", "pipe", "pipe"] },
    ).trim();
    return tok || null;
  } catch {
    return null;
  }
}

export async function generate({ prompt, model, env }) {
  const project = env.VITL_VERTEX_PROJECT;
  const location = env.VITL_VERTEX_LOCATION;
  if (!project) {
    return { ok: false, error: "VITL_VERTEX_PROJECT is not set" };
  }
  if (!location) {
    return { ok: false, error: "VITL_VERTEX_LOCATION is not set" };
  }

  const token = getAccessToken();
  if (!token) {
    return {
      ok: false,
      error:
        "could not obtain GCP access token. Install gcloud CLI and run `gcloud auth application-default login`.",
    };
  }

  const m = model || DEFAULT_MODEL;
  const url =
    `https://${location}-aiplatform.googleapis.com/v1/projects/${project}` +
    `/locations/${location}/publishers/google/models/${m}:generateContent`;

  let resp;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: "Respond with a generated image, not with text." }],
        },
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseModalities: ["TEXT", "IMAGE"] },
      }),
    });
  } catch (err) {
    return { ok: false, error: `fetch failed: ${err.message}` };
  }

  if (!resp.ok) {
    const body = await resp.text().catch(() => "");
    return { ok: false, error: `API ${resp.status}: ${body.slice(0, 500)}` };
  }

  const json = await resp.json();
  const parts = json.candidates?.[0]?.content?.parts ?? [];
  const imagePart = parts.find((p) => p.inlineData);
  if (!imagePart) {
    const textPreview = parts
      .map((p) => p.text)
      .filter(Boolean)
      .join(" ")
      .slice(0, 200);
    return {
      ok: false,
      error: `no image part in response${textPreview ? `; text returned: "${textPreview}"` : ""}`,
    };
  }

  return { ok: true, png: Buffer.from(imagePart.inlineData.data, "base64") };
}
