// Gemini provider — direct REST call to https://generativelanguage.googleapis.com
// Returns { ok: true, png: Buffer } on success, { ok: false, error: string } on failure.

const DEFAULT_MODEL = "gemini-3-pro-image-preview";

export async function generate({ prompt, model, env }) {
  const apiKey = env.GEMINI_API_KEY ?? env.GOOGLE_API_KEY;
  if (!apiKey) {
    return { ok: false, error: "GEMINI_API_KEY (or GOOGLE_API_KEY) is not set" };
  }

  const m = model || DEFAULT_MODEL;
  const aspectRatio = env.VITL_ASPECT_RATIO || "2:3";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent`;

  let resp;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseModalities: ["IMAGE"],
          imageConfig: { aspectRatio },
        },
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
