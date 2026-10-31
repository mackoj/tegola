// CLCTN · TypeSafe experiment runner
//
//   export TYPESAFE_API_KEY=apikey_...
//   node experiments/run.mjs              # all experiments
//   node experiments/run.mjs grades        # one experiment
//
// Reads payloads.json (same shape the browser harness uses) and prints one
// line per item plus an accuracy tally for experiments that carry ground truth.
// Use this if the browser harness is blocked by CORS.

import { readFile } from 'node:fs/promises';

const KEY = process.env.TYPESAFE_API_KEY;
if (!KEY) { console.error('Set TYPESAFE_API_KEY first.'); process.exit(1); }

const ENDPOINT = 'https://api.typesafe.ai/v1/systemone';
const payloads = JSON.parse(await readFile(new URL('./payloads.json', import.meta.url), 'utf8'));
const only = process.argv[2];

async function ask(state, questions, attempt = 0) {
  const res = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ state, model: 'jev-latest', questions })
  });
  if ((res.status === 429 || res.status === 529) && attempt < 4) {
    await new Promise(r => setTimeout(r, 400 * 2 ** attempt));
    return ask(state, questions, attempt + 1);
  }
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return res.json();
}

const fmt = a =>
  a.type === 'noul' ? a.noul.toFixed(2)
  : a.type === 'choice' ? `${a.choice} (conf ${a.confidence.toFixed(2)})`
  : `${a.score.toFixed(2)} (conf ${a.confidence.toFixed(2)})`;

for (const [name, exp] of Object.entries(payloads)) {
  if (only && only !== name) continue;
  console.log(`\n=== ${name} — ${exp.title}`);
  console.log(`gate: ${exp.gate}\n`);
  let hits = 0, scored = 0, tokens = 0;

  for (const item of exp.items) {
    let out;
    try { out = await ask(item.state, exp.questions); }
    catch (e) { console.log(`  ${item.label}\n    ERROR ${e.message}`); continue; }

    tokens += out.usage.input_tokens + out.usage.output_tokens;
    console.log(`  ${item.label}`);
    for (const [id, a] of Object.entries(out.answers)) console.log(`    ${id.padEnd(30)} ${fmt(a)}`);

    if (item.truth) {
      scored++;
      const a = out.answers[exp.truthQuestion];
      const got = a.type === 'choice' ? a.choice : a.type === 'noul' ? (a.noul > 0.5 ? 'yes' : 'no') : String(Math.round(a.score));
      const ok = got === item.truth;
      if (ok) hits++;
      console.log(`    ${'→ expected'.padEnd(30)} ${item.truth}  ${ok ? 'HIT' : 'MISS'}`);
    }
    console.log('');
  }

  if (scored) console.log(`  accuracy on ${exp.truthQuestion}: ${hits}/${scored}`);
  console.log(`  tokens: ${tokens}`);
}
