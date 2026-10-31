// Cloudflare Pages Function: POST /api/feedback
// Stores each submission in a KV namespace bound as FEEDBACK (see README).
// Optionally forwards to an email via Resend if RESEND_KEY + NOTIFY_TO are set.

export async function onRequestPost({ request, env }) {
  let data;
  try { data = await request.json(); } catch { return json({ error: 'bad json' }, 400); }
  const wrong = String(data.wrong || '').trim().slice(0, 4000);
  if (!wrong) return json({ error: 'empty' }, 400);

  const record = {
    ts: new Date().toISOString(),
    hobbies: Array.isArray(data.hobbies) ? data.hobbies.slice(0, 12).map(String) : [],
    today: str(data.today), size: str(data.size), hook: str(data.hook), price: str(data.price),
    wrong,
    email: str(data.email).slice(0, 200),
    lang: str(data.lang).slice(0, 20),
    country: request.headers.get('cf-ipcountry') || '',
    ua: (request.headers.get('user-agent') || '').slice(0, 200)
  };

  if (env.FEEDBACK) {
    const key = `${record.ts}_${crypto.randomUUID().slice(0, 8)}`;
    await env.FEEDBACK.put(key, JSON.stringify(record));
  }

  if (env.RESEND_KEY && env.NOTIFY_TO) {
    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.RESEND_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: env.NOTIFY_FROM || 'CLCTN <feedback@clctn.app>',
        to: [env.NOTIFY_TO],
        subject: `Feedback: ${record.hobbies.join(', ') || 'collector'} · ${record.price || '—'} on price`,
        text: `${record.wrong}\n\n—\nCollects: ${record.hobbies.join(', ')}\nTracks today: ${record.today}\nSize: ${record.size}\nNodded at: ${record.hook}\nPrice: ${record.price}\nEmail: ${record.email || '(none)'}\nCountry: ${record.country} · ${record.lang}`
      })
    }).catch(() => {});
  }

  return json({ ok: true });
}

export async function onRequestGet({ request, env }) {
  // Simple export for you: /api/feedback?key=ADMIN_KEY → JSON of everything.
  const url = new URL(request.url);
  if (!env.ADMIN_KEY || url.searchParams.get('key') !== env.ADMIN_KEY) return json({ error: 'nope' }, 401);
  if (!env.FEEDBACK) return json([]);
  const list = await env.FEEDBACK.list({ limit: 1000 });
  const items = await Promise.all(list.keys.map(k => env.FEEDBACK.get(k.name, 'json')));
  return json(items);
}

const str = v => (v == null ? '' : String(v));
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
