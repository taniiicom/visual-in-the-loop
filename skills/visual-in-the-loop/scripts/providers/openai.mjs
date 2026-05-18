// OpenAI provider — direct REST call to https://api.openai.com/v1/images/generations
// Returns { ok: true, png: Buffer } on success, { ok: false, error: string } on failure.

const DEFAULT_MODEL = "gpt-image-1";

export async function generate({ prompt, model, env }) {
  const apiKey = env.OPENAI_API_KEY;
  if (!apiKey) {
    return { ok: false, error: "OPENAI_API_KEY is not set" };
  }

  const m = model || DEFAULT_MODEL;
  const url = "https://api.openai.com/v1/images/generations";

  let resp;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: m,
        prompt,
        n: 1,
        size: "1024x1024",
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
  const item = json.data?.[0];
  if (item?.b64_json) {
    return { ok: true, png: Buffer.from(item.b64_json, "base64") };
  }
  if (item?.url) {
    try {
      const imgResp = await fetch(item.url);
      if (!imgResp.ok) {
        return { ok: false, error: `image download failed: ${imgResp.status}` };
      }
      return { ok: true, png: Buffer.from(await imgResp.arrayBuffer()) };
    } catch (err) {
      return { ok: false, error: `image download failed: ${err.message}` };
    }
  }
  return { ok: false, error: "no image data in response" };
}
