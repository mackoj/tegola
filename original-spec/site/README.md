# CLCTN — feedback site

Static landing page + one Cloudflare Pages Function that collects the feedback form.

## Deploy (5 minutes)

1. Cloudflare dashboard → Workers & Pages → Create → Pages → **Upload assets** (drag the `site/` folder), or from a repo with build output directory `site`.
2. Create a KV namespace: Workers & Pages → KV → Create → name it `clctn-feedback`.
3. Pages project → Settings → Functions → **KV namespace bindings** → variable name `FEEDBACK` → pick `clctn-feedback`.
4. Settings → Environment variables → add `ADMIN_KEY` = any long random string.
5. Redeploy. The form now posts to `/api/feedback` and each answer is stored in KV.

Read everything you've received:
`https://your-site.pages.dev/api/feedback?key=YOUR_ADMIN_KEY` → JSON.

## Optional: email me each submission

Add env vars `RESEND_KEY` (from resend.com, free tier) and `NOTIFY_TO` (your address), optionally `NOTIFY_FROM` (a verified sender). Each submission is also emailed.

## If the function isn't set up

The form falls back to a `mailto:` link to hello@clctn.app with the answers pre-filled, so nothing is lost.

## Edit

Everything is in `index.html`. No build step, no framework. Fonts load from Google Fonts; there are no analytics or cookies — the footer promises that, so keep it true.
