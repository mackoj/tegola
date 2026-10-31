# CLCTN · judgement experiments

Six pre-registered experiments against the TypeSafe System One API, testing
whether the judgement sites proposed in `44_Intelligent Judgement.dc.html`
actually work before any of them is built into the app.

**Pre-registered** means the prediction and the pass/fail gate for each
experiment were written down before the first call was made. `45_Judgement
Experiments.dc.html` shows them next to the real numbers, so a result that
disagrees with me is visible rather than quietly reframed.

## Running them

Two ways, same payloads:

**Browser** — open `45_Judgement Experiments.dc.html`, paste the key into the
field at the top (kept in `localStorage`, never written into a project file),
press Run on an experiment. If the call fails with a network error it is almost
certainly CORS; use the node path instead.

**Node** —

```sh
export TYPESAFE_API_KEY=apikey_...
node experiments/run.mjs          # all six
node experiments/run.mjs grades   # just one
```

## Files

| File | What it is |
| --- | --- |
| `payloads.json` | The six experiments: state per item, one question battery per experiment, ground truth where it exists. The single source of truth — the browser harness and the node runner both read this shape. |
| `run.mjs` | Node runner with 429/529 backoff and an accuracy tally. |

## Do not commit the key

The key is not in any file here, and should not be. `run.mjs` reads
`TYPESAFE_API_KEY` from the environment; the harness keeps it in
`localStorage`. This matters more than usual for this project — these files get
zipped and handed to a coworker.

## Ground truth

Only `grades` has real ground truth (a grade string has a correct answer on the
Goldmine ladder), which is why it is the experiment worth trusting most. The
other five report separation rather than accuracy: whether the battery pulls
clearly different items apart. Treat any single number as a sample size of one.

The sample text is synthetic — written to match what the live feedback form and
type board will receive, not taken from real submissions. Re-run `feedback`
against the real KV store once it has fifty rows; that result supersedes this one.
