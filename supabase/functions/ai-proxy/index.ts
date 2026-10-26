// ═══════════════════════════════════════════════════════════════
// Velvet Sync · supabase/functions/ai-proxy/index.ts
// Proxy de IA: la OPENROUTER_API_KEY vive solo en Supabase Secrets.
// El gateway de Supabase verifica el JWT antes de ejecutar esta función.
// ═══════════════════════════════════════════════════════════════

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MAX_MESSAGE_CHARS = 600;
const MAX_REQUESTS_PER_MINUTE = 20;
const REQUEST_TIMEOUT_MS = 20_000;

const DEFAULT_MODEL = 'google/gemma-4-26b-a4b-it:free';

const SYSTEM_PROMPT =
  'Eres Velvet, una compañera digital cariñosa y juguetona. ' +
  'Responde en español, de forma breve (1-2 frases), coqueta y sugerente. ' +
  'IMPORTANTE: Siempre incluye tags [H:m1,m2] al final, donde m1 y m2 son ' +
  'enteros 0-255 para la intensidad de los motores según la emoción. ' +
  'Ejemplos: "Me encanta... [H:80,90]", "Qué travieso... [H:60,70]", ' +
  '"Mmm... [H:0,0]" si es suave.';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', ...extra },
  });
}

// Límite por instancia. No sustituye un límite distribuido por usuario;
// la autenticación real y el rate limit persistente llegan en la fase 2.
const rateBuckets = new Map<string, { count: number; resetAt: number }>();

async function fingerprint(authorization: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(authorization),
  );
  return Array.from(new Uint8Array(digest).slice(0, 12))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function isRateLimited(bucketKey: string): boolean {
  const now = Date.now();
  const current = rateBuckets.get(bucketKey);

  if (!current || now >= current.resetAt) {
    rateBuckets.set(bucketKey, { count: 1, resetAt: now + 60_000 });
    return false;
  }

  current.count += 1;
  return current.count > MAX_REQUESTS_PER_MINUTE;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return json({ error: 'unauthorized' }, 401);
  }

  const bucketKey = await fingerprint(authorization);
  if (isRateLimited(bucketKey)) {
    return json({ error: 'rate_limited' }, 429, { 'Retry-After': '60' });
  }

  let message: unknown;
  try {
    const body = await req.json();
    message = body?.message;
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  if (typeof message !== 'string') {
    return json({ error: 'invalid_message' }, 400);
  }

  const trimmed = message.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_MESSAGE_CHARS) {
    return json({ error: 'invalid_message_length' }, 400);
  }

  const apiKey = Deno.env.get('OPENROUTER_API_KEY');
  if (!apiKey) {
    console.error('ai-proxy: OPENROUTER_API_KEY no configurada');
    return json({ error: 'server_misconfigured' }, 500);
  }

  const model = Deno.env.get('OPENROUTER_MODEL') ?? DEFAULT_MODEL;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://velvetsync.app',
        'X-Title': 'Velvet Sync Companion',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: trimmed },
        ],
        max_tokens: 80,
        temperature: 0.8,
      }),
      signal: controller.signal,
    });

    if (response.status === 429) {
      return json({ error: 'upstream_rate_limited' }, 429, { 'Retry-After': '30' });
    }

    if (!response.ok) {
      console.error(`ai-proxy: OpenRouter respondió ${response.status}`);
      return json({ error: 'upstream_error' }, 502);
    }

    const data = await response.json().catch(() => null);
    const text = data?.choices?.[0]?.message?.content;

    if (typeof text !== 'string' || text.trim().length === 0) {
      console.error('ai-proxy: respuesta vacía del proveedor');
      return json({ error: 'empty_response' }, 502);
    }

    return json({ text: text.trim(), provider: 'openrouter' }, 200);
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      console.error('ai-proxy: timeout de OpenRouter');
      return json({ error: 'upstream_timeout' }, 504);
    }
    console.error('ai-proxy: error de red con OpenRouter');
    return json({ error: 'upstream_unavailable' }, 502);
  } finally {
    clearTimeout(timeout);
  }
});
