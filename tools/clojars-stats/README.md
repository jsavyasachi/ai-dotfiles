# clojars-stats

Watch download stats for the `net.clojars.savya` Clojars artifacts and surface the
only signal that matters: a version pulling ahead of its siblings (the fingerprint of
a real dependent, vs. the uniform per-version floor a crawler/cljdoc leaves behind).

## Stack

<a href="https://clojure.org"><img src="https://img.shields.io/badge/Clojure-5881D8?style=flat&logo=clojure&logoColor=fff" alt="Clojure" /></a>

## Usage

```bash
bb clojars-stats.bb            # snapshot table + adoption-signal check
bb clojars-stats.bb --feed 12  # + per-day pulls for the last 12 UTC days
# from this dir you can also: bb pull --feed 12   /   bb test
```

Exit code is `1` when an adoption signal fires, `0` otherwise, so it composes with a
scheduled job (alert only on a real breakaway).

## Data sources

- API: `https://clojars.org/api/artifacts/<group>/<artifact>` — lifetime + per-version totals.
- Feed: `https://clojars.org/stats/downloads-YYYYMMDD.edn` — daily Fastly-CDN log (302 → S3).
  Parsed as EDN (keys are `["group" "artifact"]` vectors), so version digits never leak
  into counts.

## Known limitation

The baseline-breaker check runs on **lifetime** per-version totals, which conflates
dev/deploy/cljdoc churn on a lib's inaugural version with real adoption (e.g. `hier-set`
1.2.0). The trustworthy signal is a breakaway in the **daily feed on a quiet day** — tune
the detector to daily deltas before wiring it to anything that pages you.
