# TestStore conventions

## What a reducer test looks like

- Exhaustive by default: every state change asserted, every received action listed. A non-exhaustive store needs a
  comment naming what it deliberately skips and why.
- Every dependency overridden: the database is the in-memory seed shelf, clocks are `TestClock`, dates `.constant`,
  ids `.incrementing`. A dependency a test doesn't expect is `unimplemented`, so an unexpected effect fails.
- Tests are named for what a collector sees (`aNamedPieceLandsOnTheShelfWithItsStory`), not for the action sent.
- Routing: every `Route` is opened from every tab once (PLAN §5), so no screen is reachable from one tab only.

## Gate

`scripts/test.sh TegolaFeatures <Feature>Tests` green, zero warnings.

## Report (under 400 words)

The tests added, what they assert, and anything left non-exhaustive with the reason.
