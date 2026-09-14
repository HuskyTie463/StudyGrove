const DEFAULT_PAGE_ORIGIN = "https://huskytie463.github.io";
const MAX_BODY = 32_768;
const HOUR_LIMIT = 8;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function pageOrigin(env) {
  return String(env.SUPPORT_PAGE_ORIGIN || DEFAULT_PAGE_ORIGIN).trim() ||
    DEFAULT_PAGE_ORIGIN;
}

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin") || "";
  const allowed =
    origin === pageOrigin(env) ||
    origin.startsWith("http://127.0.0.1:") ||
    origin.startsWith("http://localhost:");
  const headers = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Accept",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
  if (allowed) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

function json(request, env, status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(request, env),
    },
  });
}

function clientIp(request) {
  return (
    request.headers.get("CF-Connecting-IP") ||
    request.headers.get("X-Forwarded-For")?.split(",")[0]?.trim() ||
    "unknown"
  );
}

function clip(value, max) {
  return String(value ?? "").trim().slice(0, max);
}

function safeSubject(name) {
  const clean = clip(name, 80).replace(/[\r\n]+/g, " ");
  return `Study Grove support from ${clean || "someone"}`;
}

async function rateLimited(ip) {
  const key = new Request(`https://sg-support-rate.invalid/hour/${encodeURIComponent(ip)}`);
  const hit = await caches.default.match(key);
  let count = 0;
  if (hit) {
    count = Number.parseInt(await hit.text(), 10) || 0;
  }
  if (count >= HOUR_LIMIT) return true;
  await caches.default.put(
    key,
    new Response(String(count + 1), {
      headers: { "Cache-Control": "max-age=3600" },
    }),
  );
  return false;
}

function genericMailError(request, env) {
  return json(request, env, 503, { ok: false, error: "unavailable" });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "")) {
      return Response.redirect(`${pageOrigin(env)}/StudyGrove/support/`, 302);
    }

    if (request.method === "OPTIONS" && url.pathname === "/support") {
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }

    if (request.method !== "POST" || url.pathname !== "/support") {
      return json(request, env, 404, { ok: false, error: "not_found" });
    }

    const origin = request.headers.get("Origin") || "";
    if (
      origin &&
      origin !== pageOrigin(env) &&
      !origin.startsWith("http://127.0.0.1:") &&
      !origin.startsWith("http://localhost:")
    ) {
      return json(request, env, 403, { ok: false, error: "forbidden" });
    }

    const length = Number(request.headers.get("Content-Length") || "0");
    if (length > MAX_BODY) {
      return json(request, env, 413, { ok: false, error: "too_large" });
    }

    if (await rateLimited(clientIp(request))) {
      return json(request, env, 429, { ok: false, error: "slow_down" });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json(request, env, 400, { ok: false, error: "invalid" });
    }

    if (clip(payload?.website, 200)) {
      return json(request, env, 200, { ok: true });
    }

    const name = clip(payload?.name, 120);
    const email = clip(payload?.email, 254);
    const context = clip(payload?.context, 160);
    const message = clip(payload?.message, 8000);

    if (!name || !email || !message || !EMAIL_RE.test(email)) {
      return json(request, env, 400, { ok: false, error: "invalid" });
    }

    const inbox = String(env.SUPPORT_INBOX || "").trim();
    const apiKey = String(env.RESEND_API_KEY || "").trim();
    if (!inbox || !apiKey) {
      return genericMailError(request, env);
    }

    const from = String(env.RESEND_FROM || "").trim() ||
      "Study Grove Support <onboarding@resend.dev>";

    const text = [
      `Name: ${name}`,
      `Reply-to: ${email}`,
      context ? `App / Windows: ${context}` : null,
      "",
      message,
    ]
      .filter(Boolean)
      .join("\n");

    let res;
    try {
      res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from,
          to: [inbox],
          reply_to: email,
          subject: safeSubject(name),
          text,
        }),
      });
    } catch {
      return genericMailError(request, env);
    }

    if (!res.ok) {
      return genericMailError(request, env);
    }

    return json(request, env, 200, { ok: true });
  },
};
