# App Strategy — What to Focus On

Distilled from Apple App Store sessions covering discovery, monetization, retention, analytics, and platform integrity.

---

## The frame: fix the funnel in order

Impressions → Product page views → Downloads → Payer conversion → Retention → LTV

Most teams over-invest at the top. The classic image from Apple's retention session is a **leaky bucket**: pouring acquisition spend into a bucket full of holes loses you subscribers faster than you add them. Plugging holes is usually cheaper per dollar than filling faster — and on the App Store there's a direct financial reason: **once a subscriber passes one year, your proceeds go from 70% to 85%.**

**Priority order for most apps:** retention → conversion → discovery → acquisition spend.

---

## 1. Discovery — make the store surface work for you

### Product page optimization (PPO)
Test up to 3 treatments against your control (icon, screenshots, app previews).

- Treat it as an **ongoing loop**, not a one-off: research → hypothesis → assets → test → analyze → iterate.
- **One variable per test.** Otherwise you can't attribute the lift.
- Run **at least 7 days, in 7-day increments** — partial weeks skew results if your traffic is weekday/weekend skewed.
- Make treatments **notably different**. Subtle changes take far longer to reach confidence.
- Wait for **90%+ confidence** before acting.
- Don't port learnings from other platforms. Different UI, different user behavior.
- **The control winning is a valid, useful result.** In Apple's own examples, the hypothesis was wrong in all three case studies (seasonal art lost to evergreen; a video preview lost to a static screenshot; a robot icon lost to a brain icon).

### Custom product pages (CPPs)
- Build distinct pages per use case / audience segment, each with its own URL.
- **Assign keywords to CPPs** so they surface directly in search results in place of your default page — keyword-only changes go live without review.
- Keep keyword sets **unique per CPP** so the right one wins.
- Match the CPP creative to the ad or web banner that drove the click, and deep-link into the matching in-app experience.

### Creative assets: product page header + search results
- The **product page header** is the first thing someone sees — image or video, separate from your screenshots. Use it for brand and visual identity.
- Replace default screenshots in **search results** with a single high-impact image or video.
- Upload to the **Asset Library** and get assets pre-approved. Approved assets can then be swapped onto your header or search results **in real time, with no new review** — huge for seasonal or campaign agility.

### App Store tags
- Auto-generated from your metadata via LLM, human-reviewed, and they drive placement in curated tag rooms and search.
- **Audit them in App Store Connect.** You can deselect tags that misrepresent your app — but deselecting also removes you from that tag room, so weigh reach vs. accuracy.

### In-app events
Promote time-boxed experiences (competitions, premieres, seasonal content) to pull in both new and lapsed users. Track event impressions, notification taps, and app opens.

### Metrics to follow — discovery

| Metric | Where | What it tells you | Watch for |
|---|---|---|---|
| **Impressions / unique impressions** | App Analytics | Top-of-funnel reach | Flat impressions + rising downloads = you fixed conversion, not reach |
| **Product page views** | App Analytics | How many go past the tile | Low PPV vs. impressions → icon and search-result creative are the problem |
| **Conversion rate** (downloads ÷ unique impressions) | App Analytics + benchmarks | The single headline discovery metric | Compare to your peer percentile, not to an absolute target |
| **Conversion rate by territory** | App Analytics | Localization gaps | Bottom-of-list markets usually need translated pages, not more spend |
| **Conversion rate by source type** | App Analytics | Browse vs. search vs. app/web referrer | Each source needs different creative |
| **Conversion rate by page type** | App Analytics | Product page vs. store sheet vs. no page | Directly decides where to point ad traffic |
| **PPO: impressions per treatment, % improvement, confidence** | PPO dashboard | Whether a test is decidable yet | Don't act below 90% confidence |
| **CPP: product page views, conversion rate, search traffic per page** | App Analytics | Whether each page earns its keyword set | Overlapping keywords = pages cannibalizing each other |
| **In-app events: impressions, notification taps, app opens, downloads** | App Analytics | Whether events pull anyone in | Impressions without opens = wrong hook |

**Leading indicator to watch weekly:** conversion rate by source type. It moves before downloads do.

---

## 2. Conversion & monetization — widen the pricing surface

### Pricing flexibility
| Option | Use it for |
|---|---|
| **Monthly with 12-month commitment** | Lower monthly sticker price while locking annual value. Requires a disclosure sheet (shown once per Apple Account). |
| **Volume pricing** | Up to 5 price bands with per-band quantity thresholds — incentivizes bigger group buys. |
| **Bundles & Suites** | Bundle = sellable individually but discounted together. Suite = only exists as a group across related apps. |
| **Group & organization subscriptions** | Two channels: in-app group purchases (invite link, Apple handles seat management by default) and volume purchasing via Apple Business/School Manager. Requires StoreKit 2. |

### Offer codes — now for every product type
Consumables, non-consumables, non-renewing subscriptions, and auto-renewables.

- Up to **10 active offers per IAP**, up to **1M codes per app per quarter**.
- Set **redemption eligibility**: never spent / spent but not in last 30 days / spent in last 30 days.
- Distribute via deep link, QR code, or in-app entry.
- Test with sandbox codes (10k/quarter, unlimited redemptions per sandbox account).

### Family Sharing
Up to 6 entitlements instead of 1 — drives subscriber growth, engagement, and reduced churn simultaneously.

- **It's irreversible once enabled on a SKU.** Decide deliberately.
- Two models: enable on your existing SKU (positioned as added value at no cost) or create a separate, higher family tier (group it with individual tiers so you can run upgrade messaging).
- New purchases auto-share; **existing** subscriptions require the purchaser to opt in from Settings, so you need to market that push.
- Merchandise it in onboarding, post-purchase carousels, and to the family members themselves.

### Merchandising hygiene
- **Check entitlement status before merchandising anything.** Showing a paywall to someone who already has access is the fastest route to refunds and 1-star reviews.
- Listen for transactions at launch and for the app's whole lifetime — offer codes, Ask to Buy, and family transactions all finalize outside your purchase flow.
- Use `SubscriptionOfferView` and StoreKit views (SwiftUI) rather than hand-rolling; specify the plan relationship (upgrade / downgrade / crossgrade / current / all).

### Metrics to follow — conversion & monetization

| Metric | Where | What it tells you | Watch for |
|---|---|---|---|
| **Download-to-Paid Conversion** (cohort, by day 7 / 30 / 35) | App Analytics → Cohorts | How fast new users start paying | The most diagnostic monetization metric you have — always read it against the benchmark |
| **Average Proceeds per Download** (cohort) | App Analytics → Cohorts | Spend depth per acquired user | Rising curve = repeat purchasers; flat = one-and-done |
| **Paying users / total IAP count / proceeds** | App Analytics → Sales | Absolute scale | — |
| **Proceeds by product** | App Analytics → Sales | Which SKU actually carries revenue | An underperforming SKU is often a segment problem, not a pricing one — filter by CPP to check |
| **Proceeds by territory** | App Analytics → Sales | Where pricing and localization pay off | — |
| **Active plans / paid plans / MRR** | App Analytics → Subscriptions | Subscription business size | — |
| **Net paid plans** (starts + reactivations − voluntary − involuntary churn) | App Analytics → Subscriptions | Whether you're actually growing | The clearest single subscription health number |
| **Plan mix / paid plans breakdown** | App Analytics → Subscriptions | Which tier wins | — |
| **Billing plan split** (upfront vs. monthly-with-commitment) | Transaction `billingPlanType` | Whether the new plan expands the base or just cannibalizes | Cannibalization looks like flat total subs with shifting mix |
| **Offer code redemptions by campaign and eligibility tier** | App Store Connect reports | Which distribution channel works | — |
| **Family Sharing: subscriber count vs. entitled-member count** | Sales & Trends subscriber column | Reach multiplier from sharing | Column only populates above 3 active subscriptions |
| **Seats per group purchase / average price per seat** | Server API group endpoints | Whether volume pricing bands are set right | Bunching at a band edge = mispriced threshold |

**The key diagnostic pairing:** Download-to-Paid Conversion *and* subscription retention, read together. Low conversion + high retention is a pricing/onboarding/intro-offer problem. High conversion + low retention is a value-delivery problem. They need opposite fixes.

---

## 3. Retention — the highest-leverage area

### Understand your churn split
- **Voluntary**: customer chose to cancel. Driven by content staleness, unclear value, price.
- **Involuntary**: billing failure. Not correlated with behavior, region, or category — and largely fixable.

Category and geography matter: health/fitness and music churn low; entertainment and lifestyle (dating) churn higher by design. Benchmark against your peer group, not a global average.

**The math that justifies the work:** a cohort of 10,000 at 85% monthly retention ends the year at ~1,673. At 90% it's ~3,487. At 95% it's ~5,688 — roughly **triple** the survivors for a 10-point retention gain.

### What Apple does for you automatically
- **Billing retry**: 60-day window with email, push, and App Store banner nudges. Recovered subscribers keep accruing paid days toward the 85% tier.
- **Billing problem message**: in-app prompt to fix payment without leaving your app. You can defer it via the StoreKit Message API if it would interrupt a critical flow.

### What you should turn on
- **Billing grace period** — customer keeps access while Apple recovers payment, and the original renewal date is preserved so you lose no paid days. Choose 3, 16, or 28 days. Recovery rates: **40% within 3 days, 75% within 16, 90% within 28.** Pick 28 unless you have a strong reason not to.
- **Retention Messaging in App Store Connect** — a value message (optionally with an image or an offer) shown at the cancellation screen. Reported average save-rate lift of **+1.4 points (~82% relative)**, and **+5.5 points (~223%)** when a promotional offer is attached. Setup is no-code; results vary by developer.
- **Real-time Retention Messaging** (server-to-server) if you want per-customer decisioning, switch-plan offers, or dynamic promotional offers. Requires a fast endpoint and a sandbox performance test. Always configure the App Store Connect version too — it's your fallback.

### Subscription offers by cohort
| Cohort | Signal | Play | Channel |
|---|---|---|---|
| Active but low-engagement | still auto-renewing | Re-educate on value, surface unknown features, offer a free period or plan change | Email / push (outside the app) |
| Auto-renew off, still has access | `willAutoRenew = false`, status subscribed | Discount to reverse the cancel. **90%+ cancel with 2+ days remaining** and many keep using the app — this window is real. | In-app |
| Fully churned | status expired | Win-back, deepening the discount as time since churn grows | Push / email, offer-code deep link |

**Caution:** don't discount immediately on churn, or you train people to cancel to get a deal. And don't over-send — it reads as spam.

Use `recentSubscriptionStartDate` to gauge tenure and target offers by loyalty rather than blasting everyone.

### Metrics to follow — retention

| Metric | Where | What it tells you | Watch for |
|---|---|---|---|
| **Monthly retention rate by cohort** | App Analytics → Cohorts (Subscription Retention) | The number that compounds into everything else | 85% → 90% → 95% roughly doubles then triples year-end survivors |
| **Voluntary churn rate** | Subscriptions / subscription events | Value and pricing problems | Segment by territory and category before judging — churn norms differ a lot |
| **Involuntary churn rate** | Subscriptions / subscription events | Billing failure leakage | Should be low and falling once grace period is on; not behavior-driven, so no excuse for it staying high |
| **Billing recovery rate** (recovered ÷ entered retry) | `DID_RENEW` + `BILLING_RECOVERY` vs. `DID_FAIL_TO_RENEW` | Whether retry/grace is working | Benchmarks: ~40% by day 3, ~75% by day 16, ~90% by day 28 |
| **Grace period recovery rate** | `GRACE_PERIOD` → recovered vs. `GRACE_PERIOD_EXPIRED` | Value of the grace window specifically | If close to zero, check the setting actually applies to your plans |
| **Save rate** (kept subscription ÷ reached cancel confirmation page) | Retention Messaging reporting | Whether your cancellation-flow message lands | Reference lifts: **+1.4 pts (~82%)** average, **+5.5 pts (~223%)** with an offer |
| **Auto-renew-off count** (`willAutoRenew = false`, still subscribed) | Subscription state metrics | Size of your save-window audience | **90%+ cancel with 2+ days left** — this cohort is reachable in-app |
| **Offer redemption → paid conversion** | App Analytics → Offers / Cohorts | Whether offers convert or just discount | Reference: ~67% trial-to-paid in Apple's example |
| **Retention by offer start** | App Analytics → Cohorts | Whether discounted users stick | Reference: ~78% at 3 months, ~73% at 6 months |
| **Win-back rate by time-since-churn** | Offer campaign reports | Optimal delay before discounting | Discounting too early trains people to cancel — watch for cancels clustering just before your offer trigger |
| **% of subscribers past 12 months** | Subscription state metrics | Share of revenue at the 85% proceeds tier | The most under-tracked revenue lever on this list |
| **Usage retention (D1 / D7 / D28)** | App Analytics benchmarks | Engagement upstream of churn | Falling D7 predicts churn weeks before it shows in subscriptions |

**Leading indicator:** D7 usage retention and auto-renew-off count. Both move before churn does, which means both give you time to intervene.

---

## 4. Measurement — decide from data, not instinct

### App Analytics essentials
- Core four: **impressions, product page views, conversion rate, total downloads** (conversion = downloads ÷ unique impressions).
- Break down by **territory** (low conversion in CN/JP/KR usually signals a localization gap), **source type** (browse / search / app referrer / web referrer), and **page type** (product page vs. store sheet vs. no page).
- Page type × source type answers a concrete question: for your ad campaigns, does sending traffic to the full product page or the store sheet convert better?
- Filtering now supports **up to 7 filters** with multi-select per filter.

### The newer monetization layer
- **Cohort metrics**: Download-to-Paid Conversion and Average Proceeds per Download, both with peer benchmarks — this tells you whether your problem is *payer conversion* or *spend depth*.
- **50+ subscription metrics** split into states (snapshot) and events (movement between states).
- **Offer metrics**: trial-to-paid conversion and retention by offer start.
- **Peer group benchmarks** by business model, category, and download volume — read your percentile position per metric rather than chasing absolute numbers.

A worked example from the material: a segment converted to payer at less than half the app average, yet **retained better than average once subscribed**. That's a conversion problem, not a retention problem — and it points at pricing, onboarding, or an intro offer, not at content.

### Attribution
- Migrate **SKAdNetwork → AdAttributionKit**.
- Enable **overlapping re-engagement conversion windows** and use **conversion tags** if you run multiple concurrent campaigns, so purchases attribute to the right ad.
- Configure **attribution windows** per ad network and interaction type, and **attribution cooldowns** so a re-engagement ad doesn't steal credit from the install that actually drove the purchase.
- **Country code** is now in postbacks (subject to crowd anonymity thresholds).
- Export via the **Analytics Reports API** for offline analysis.

### Metrics to follow — measurement quality

These are metrics about your metrics. Worth tracking because bad attribution quietly misallocates budget.

| Metric | Where | What it tells you | Watch for |
|---|---|---|---|
| **Your percentile per benchmark metric** | App Analytics → Benchmarks | Where you sit vs. peers on conversion, proceeds per paying user, crash rate, retention | Fix your *lowest* percentile first — that's where the headroom is |
| **Benchmark trend over time** | Benchmarks → View trends | Whether you're closing or widening the gap | Below the 25th percentile but improving is a different story than below and flat |
| **Postback volume vs. expected installs** | Your postback endpoint | Attribution coverage | Large gaps suggest configuration or crowd-anonymity thresholds |
| **Crowd anonymity tier distribution** | Postbacks | How much detail you actually receive | Country code only appears above a bonus tier |
| **Conversion value distribution** | Postbacks | Whether your value schema is informative | Everything landing in one bucket = schema needs redesign |
| **Attribution split: install vs. re-engagement** | Postbacks | Whether re-engagement ads are stealing install credit | The exact problem attribution cooldowns exist to fix |
| **Crash rate** | App Analytics + benchmarks | Quality floor | Sits upstream of retention and reviews |

---

## 5. Technical foundation — what has to be right underneath

- **Adopt StoreKit 2.** It's now a prerequisite for group/org subscriptions and for most new capabilities.
- **`appTransactionId` is the identifier to standardize on.** Globally unique per Apple Account per app, stable across redownloads/refunds/repurchases/storefront changes, unique per family member, and present across `AppTransaction`, `JWSTransaction`, and `JWSRenewalInfo`. It lets you link multiple subscriptions to one account without extra plumbing.
- **`appAccountToken`**: generate a UUID per customer account and set it at purchase. The Set App Account Token endpoint now lets you set or fix it for purchases made outside your app (offer code redemptions, promoted purchases).
- **App Store Server Notifications V2** — subscribe and handle the full lifecycle. Key ones: `DID_FAIL_TO_RENEW` (+`GRACE_PERIOD`), `DID_RENEW` (+`BILLING_RECOVERY`), `EXPIRED` (+`BILLING_RETRY` / `VOLUNTARY`), `GRACE_PERIOD_EXPIRED`, `OFFER_REDEEMED`, `REVOKE`, `CONSUMPTION_REQUEST`.
- **On revocation, re-derive entitlements from the full transaction history.** A revoked transaction doesn't mean no access — another transaction may still entitle them. Getting this wrong causes silent service interruptions.
- **App Store Server Library** (Java, Python, Node.js, Swift) for signing — unified JWS format across promotional offers, introductory offer eligibility, and Advanced Commerce.
- **Send Consumption Information V2**: 5 input fields instead of 12, all product types, and a `GRANT_PRORATED` refund preference. Participating gets you better refund outcomes; handle `REFUND` notifications using `refundPercentage` and `revocationType`.
- **App Attest** if you have fraud exposure (leaderboards, premium content, sensitive payloads): validate attestations server-side, track the assertion counter for replay protection, watch launch validation category / bundle version / key access control for tampering, and treat the fraud metric as an **investigation signal, not an auto-ban trigger**.

### Metrics to follow — platform health

| Metric | Where | What it tells you | Watch for |
|---|---|---|---|
| **Notification delivery success rate** | Your server logs vs. App Store Connect | Whether you're missing lifecycle events | Missed `REVOKE` or `EXPIRED` events cause phantom entitlements |
| **Entitlement mismatch rate** | Your server | Users whose access doesn't match their transaction history | Usually a revocation-handling bug; drives support tickets and refunds |
| **Transactions unlinked to an account** | `appAccountToken` / `appTransactionId` coverage | Association gaps from offer codes and promoted purchases | Fix retroactively with Set App Account Token |
| **Refund request rate and refund grant rate** | `CONSUMPTION_REQUEST` vs. `REFUND` / `REFUND_DECLINED` | Whether participating in consumption reporting is paying off | — |
| **Prorated vs. full refund split** | `revocationType`, `refundPercentage` | Value captured by responding with consumption data | — |
| **Restore/entitlement-check failure rate** | Your app telemetry | Merchandising to people who already paid | Directly causes 1-star reviews |
| **App Attest: attestation failure rate, assertion counter anomalies, fraud metric distribution** | Your server | Tampering and brokered attestations | Baseline first, then alert on spikes — never auto-ban on the fraud metric alone |
| **`isSupported` unsupported-response rate** | Your app | Possible tampering signal | Spikes for a single user warrant investigation |

---

## 6. Trust, privacy, and compliance — table stakes that affect conversion

- **Delay or remove sign-in.** Let people use the app before asking for an account. Forced upfront registration suppresses activation.
- **Minimize data requests.** Ask what features you're delivering, then the minimum data those features need. Make non-essential fields (e.g. birthday for a coupon perk) clearly optional with a plain explanation.
- **Use scoped pickers instead of blanket permissions** — photo picker over full library access, contact picker over full Contacts, a "Share Current Location" button over a launch-time location prompt.
- **Always have a graceful fallback** when permission is declined (manual address entry, avatar instead of photo). Apps that break on denial fail review and lose users. Never nag someone to reverse a permission decision.
- **Write clear purpose strings.**
- **Age ratings**: five thresholds now, with new questions on messaging/chat, user-generated content, and advertising. Ratings are recalculated from existing answers — review yours and answer the new questions.
- **Accessibility Nutrition Labels**: declare per device, publish when ready, edit anytime. A real differentiator for people who need them.
- **Review Summaries** are LLM-generated from your reviews and shown on your page. Monitor them; report a concern if inaccurate.

### Metrics to follow — trust & compliance

| Metric | Where | What it tells you | Watch for |
|---|---|---|---|
| **Onboarding completion rate, step by step** | Your app telemetry | Where forced sign-in or field bloat kills activation | Biggest single drop is usually the registration screen |
| **Permission grant rate per resource** | Your app telemetry | Whether your purpose strings and timing work | Low grant rate = asking too early, not asking wrong |
| **Fallback-path usage rate** | Your app telemetry | How many people decline and still succeed | If the fallback is never used, it's probably broken or hidden |
| **Optional-field completion rate** | Your app telemetry | Whether an "optional" field is worth keeping | — |
| **App Review rejection rate and reason mix** | App Store Connect | Process cost of privacy and metadata mistakes | Privacy (5.1.1) rejections are the avoidable ones |
| **Review Summary sentiment shifts** | Your product page | What the store is telling prospects about you | Shifts after a release are an early quality warning |
| **Rating and review volume/average** | App Store Connect | Trust signal that feeds conversion | — |
| **TestFlight feedback volume and crash logs** | App Store Connect app | Pre-launch quality | Catching it here is far cheaper than in reviews |
| **Accessibility label coverage per device** | App Store Connect | Reach among users who filter on it | — |

---

## The one-page scorecard

If you track nothing else, track these nine, at this cadence.

| # | Metric | Cadence | Funnel stage | Why it made the cut |
|---|---|---|---|---|
| 1 | App Store conversion rate (+ percentile) | Weekly | Discovery | Headline top-of-funnel number, benchmarked |
| 2 | Download-to-Paid Conversion (D30) | Weekly | Monetization | Fastest read on whether acquisition is bringing the right people |
| 3 | Average Proceeds per Download | Monthly | Monetization | Separates spend depth from payer count |
| 4 | Net paid plans | Weekly | Retention | Growth after all churn — the honest number |
| 5 | Voluntary churn rate | Monthly | Retention | Product and pricing signal |
| 6 | Involuntary churn rate | Monthly | Retention | Should be near-zero once configured; pure leakage otherwise |
| 7 | Save rate at cancellation | Monthly | Retention | Direct read on Retention Messaging |
| 8 | D7 usage retention (+ percentile) | Weekly | Engagement | Leading indicator of churn |
| 9 | % of subscribers past 12 months | Quarterly | LTV | Share of revenue at the 85% proceeds tier |

**Review rule:** each cycle, find the metric where you sit at your lowest benchmark percentile and fix that stage before optimizing anything else.

---

## Suggested sequence

**Do this month (low effort, direct revenue impact)**
1. Enable **billing grace period** at 28 days.
2. Set up **Retention Messaging** in App Store Connect for every subscription.
3. Audit your **App Store tags** and fix your **age rating** answers.
4. Verify you're **checking entitlement status before merchandising** and listening for transactions at launch.

**Next quarter**
5. Stand up a **PPO testing cadence** — one variable, 7-day increments, continuous.
6. Build **2–4 custom product pages** with unique keyword sets, matched to your top acquisition segments.
7. Upload **creative assets** to the Asset Library and get them pre-approved for header + search results.
8. Design **cohort-based subscription offers** for the three churn stages.
9. Decide on **Family Sharing** — it's one-way, so model it first.

**Ongoing / platform work**
10. Migrate fully to **StoreKit 2** and standardize on `appTransactionId`.
11. Complete **App Store Server Notifications V2** coverage with correct revocation handling.
12. Move **SKAdNetwork → AdAttributionKit** with configured windows and cooldowns.
13. Establish a **benchmark review rhythm** — check your percentile per metric, and fix the funnel stage where you sit lowest.

---

## Principles to hold onto

- **Your hypothesis will often be wrong.** All three of Apple's PPO case studies disproved theirs. Design to learn, not to confirm.
- **Test one thing at a time**, or you learn nothing attributable.
- **Involuntary churn is free money.** It has nothing to do with your product and is largely solved by configuration.
- **Benchmarks tell you where to look**; your own cohort data tells you what to fix.
- **Less data collected, more trust earned** — and fewer review delays.
- **Irreversible decisions deserve modeling**: Family Sharing enablement is permanent.
