// Azure OpenAI provider — calls a deployment's images/generations endpoint.
// The model is determined by the Azure deployment (configured in the Azure
// portal), so VITL_MODEL is ignored here.
//
// Required env:
//   AZURE_OPENAI_API_KEY
//   AZURE_OPENAI_ENDPOINT     e.g. https://my-resource.openai.azure.com
//   AZURE_OPENAI_DEPLOYMENT   the image-gen deployment name
//
// Optional env:
//   AZURE_OPENAI_API_VERSION  default 2024-10-21

const DEFAULT_API_VERSION = "2024-10-21";

export async function generate({ prompt, env }) {
  const apiKey = env.AZURE_OPENAI_API_KEY;
  const endpoint = env.AZURE_OPENAI_ENDPOINT;
  const deployment = env.AZURE_OPENAI_DEPLOYMENT;
  const apiVersion = env.AZURE_OPENAI_API_VERSION || DEFAULT_API_VERSION;

  if (!apiKey) return { ok: false, error: "AZURE_OPENAI_API_KEY is not set" };
  if (!endpoint) return { ok: false, error: "AZURE_OPENAI_ENDPOINT is not set" };
  if (!deployment) return { ok: false, error: "AZURE_OPENAI_DEPLOYMENT is not set" };

  const base = endpoint.replace(/\/+$/, "");
  const url = `${base}/openai/deployments/${deployment}/images/generations?api-version=${apiVersion}`;

  let resp;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": apiKey,
      },
      body: JSON.stringify({
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
