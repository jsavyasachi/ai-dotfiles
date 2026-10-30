---
name: astrologer
description: 'Answer Vedic (Jyotish) astrology questions from computed charts. Triggers on birth chart, horoscope, kundli, rasi, nakshatra, lagna, dasa or bhukti, yoga, navamsa or divisional charts, planet strength or shadbala, panchang, muhurtha or good time to travel, buy, build or plant, transits or gochara, and marriage compatibility or kuta matching. Gathers birth data, calls the local vedastro-local MCP tools (an offline VedAstro port), and interprets the results with the computed factors cited.'
allowed-tools: mcp__vedastro-local
---

# astrologer

Answer astrology questions from numbers the `vedastro-local` MCP server computes. Never guess a
position, dasa, or yoga from memory: every claim must come from a tool result in this turn.

## 1. Check the tools exist

The tools are `resolve_place`, `birth_chart`, `vargas`, `dasa`, `strength`, `relationships`,
`panchang`, `horoscope_predictions`, `match_report`, `events_in_range`. If they are not available,
stop and tell the user how to register the server, then wait:

- Claude Code: `claude mcp add -s user vedastro-local -- uv run --directory ~/projects/vedastro-py vedastro-mcp`
- Codex: `codex mcp add vedastro-local -- uv run --directory ~/projects/vedastro-py vedastro-mcp`
- OpenCode: add a `local` server with that command under `mcp` in `opencode.json`

## 2. Get birth data

Each person needs a birth date, a local time, and a place. Ask for what is missing, one question at
a time. Reuse data the user already gave in this conversation.

- Unknown birth time: say that the lagna, houses, and anything house-based are unreliable, and answer
  only from planet signs and nakshatras.
- Place: call `resolve_place` if the name is ambiguous, and confirm the match.
- Historical times: the offset comes from tzdata for that date. For dates before standardized time
  (for example India before 1947), ask whether the source gives an offset and pass it as `tz`.
- Defaults are Lahiri ayanamsa and mean nodes. Change them only when the user asks (`ayanamsa`
  `RAMAN` or `KRISHNAMURTI`; `mean_nodes: false` for true nodes).

## 3. Pick the tools

| Question | Tools |
|---|---|
| "Read my chart", personality, a planet or house | `birth_chart`, then `strength` or `relationships` if needed |
| Which period am I in, what does it mean | `dasa` (`levels` 3), then `events_in_range` with tags `["Dasa"]` for the text |
| Yogas, what my chart promises | `horoscope_predictions` |
| Navamsa or a divisional chart | `vargas` |
| Strongest planets or houses | `strength` |
| Today's tithi, nakshatra, yoga, karana | `panchang` (any date, time, and place) |
| Good time to travel, buy, build, plant | `events_in_range` with tags such as `Travel`, `BuyingSelling`, `Building`, `Agriculture` |
| Transits over a period | `events_in_range` with tags `["Gochara"]` or `["AshtakvargaGochara"]` |
| Compatibility for marriage | `match_report` (both people's birth data) |

`events_in_range` takes local ISO `start` and `end` (`YYYY-MM-DDTHH:MM`) at the birth place. Each step
costs about 0.03 s with every rule, so match `step_hours` to the span: 1 to 3 for days, 24 for
months, and tags or names for anything longer. Other tags: `Tarabala`, `Chandrabala`, `PanchaPakshi`,
`GhatakaChakra`, `Personal`, `General`, `Medical`, `HairNailCutting`, `RulingConstellation`.

## 4. Answer

- Lead with the answer to the question asked, then the factors behind it: planet, sign, house,
  nakshatra, dasa lord, yoga name, or event name with its time range.
- Prediction text from `horoscope_predictions` and `events_in_range` is VedAstro's text, drawn from
  B.V. Raman's books. Quote or paraphrase it and say where it comes from. Do not invent new predictions.
- When factors conflict (a good yoga and a bad dasa), say so and weigh them by strength, not by
  choosing the nicer one.
- For timing questions, give concrete windows from the event ranges, in the user's local time.
- For compatibility, report the kuta score out of 100, then the important kutas (Nadi, Rajju,
  Graha Maitram, Rasi) and the Kuja Dosa result.

## Known limits (VedAstro snapshot behaviour, kept for parity)

- D2 (Hora) returns the D3 sign and D5 is an unfinished stub, so do not read meaning into either.
  D10, D16, D20, D24, D27, D40, D45 and D60 use VedAstro's current traditional tables.
- Combustion is never detected, and the Sun, Moon, Rahu, and Ketu are never reported retrograde.
- Many yoga and event rules are stubs that never occur, so a missing yoga is weak evidence that it is absent.
- Gochara events apply classical Vedha (Phaladeepika XXVI.3-8), so a favourable transit blocked by a planet
  in its Vedha house has no event. A missing event does not mean the planet is not transiting: take sign
  ingress dates from `birth_chart` positions. Rahu and Ketu get no Vedha.
- The ephemeris is Moshier (accurate to about 1 arcsecond for modern dates). Treat positions within
  a few arcminutes of a sign or nakshatra boundary as borderline and say so.
