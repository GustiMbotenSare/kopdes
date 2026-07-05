# KOPDES: Merah Putih Anomalies — GDD (snapshot)

Source of truth: Notion Living Spec. This file is the repo-synced snapshot for the Engineer session. The Notion spec is master; keep this file in sync with it.

## Concept
Night-shift a Koperasi Desa Merah Putih built absurdly far from civilization (hero map: the middle of a fishpond / tambak). No real customers by day; at night the "other" villagers come. Serve them, follow the posted rules, spot anomalies, survive to the morning jingle.

## Pillars
1. The joke is the location (the real KopDes meme).
2. Rules are horror (Papers Please).
3. Cheerful mascot mask, rotten core (Amanda the Adventurer dissonance).
4. Built to be clipped (streamer-first).
5. Meme pipeline = retention (Bakso Malang model).

## Theme (LOCKED)
Cheerful red-white government-mascot aesthetic as the base; VHS/CCTV as a layer on the security monitor + anomaly events only.

## Design north star — triage under drain (LOCKED 2026-07-05)
NOT a reading simulator. Three structural rules:
1. **Sensory tells** — anomalies are found by noticing the world (visual/audio/environmental/CCTV), not by cross-referencing text. Tells have a subtlety level and can *escalate* the longer they're ignored (the streamer "IT'S GETTING CLOSER" spike).
2. **Verbs cost** — every handling verb costs time and/or resources (electricity, patience). Handling is triage, not a free click. Red-herring anomalies punish spamming alarms.
3. **Concurrency + clock** — multiple anomalies run at once (Counter = foreground, Ambient = background) against draining meters and a hard shift timer.

## Design Guardrails — Fable QA Pass (LOCKED 2026-07-05)
An external concept review ("Fable") stress-tested the slice. Verdict: concept strong, risk is 100% in execution. These are binding on every service review and content addition.

**The one-line test for every shift:** did the player have to abandon the customer in front of them because the room moved behind them? If that moment never happens in 3 minutes, the slice has FAILED.

### Non-negotiables
- **Counter vs. Ambient is the core.** Every anomaly is a Counter problem (customer/card/payment/order) or an Ambient problem (room/CCTV/flag/shelf/mascot/walkway). The horror is the divided attention between them. Spawn Ambient tells while the player is mid-Counter.
- **concurrentMax = 2 is a contract, not flavor.** If a build serializes anomalies one-at-a-time, reject it. Minimum viable = >=2 overlapping active problems.
- **Verbs cost OPPORTUNITY, not just seconds.** A 2s lockout is meaningless unless something can escalate during it. Cost is only real under concurrency + drain. Free verbs = whack-a-mole = dead game.
- **Fair-subtle, never invisible.** Good tell = "wait, was that always like that?" Bad tell = "how was I supposed to know?" Subtlety is never an excuse for unreadable; every hero anomaly must be catchable on a fair first encounter.
- **No-arithmetic rule (M1).** If a tell can ONLY be caught by math or close-reading, it is disqualified as a hero anomaly. Detection is sensory, not analytical. This keeps us out of "reading simulator" and "Papers-Please-but-shallower."
- **Comedy is load-bearing.** The KopDes absurdity is a pillar, not seasoning. Protect >=1 deliberately funny beat per shift (e.g. a Pak Kades spin-call: "itu bukan hantu, itu tamu prioritas"). Too-scary loses identity; too-meme loses longevity.
- **Server owns truth (Roblox reality).** Everything in ReplicatedStorage is client-readable, so shared anomaly data (correctVerb, outcomes, tells) is NOT secret — never design as if it is. Client renders + sends intent; server owns active anomalies, timing, and resource/sanity/ending resolution. Any "client says it solved anomaly X" is rejected.
- **M1 endings = exactly 2** (a clean survival + a taken/bankrupt). Ending quantity is deferred until the loop is proven fun.

### The serve loop = a leash, not a puzzle (LOCKED)
The counter is deliberately simple, because its job is to OCCUPY you, not challenge you. Serving is a fixed 3-beat rhythm you cannot pause — scan card -> bag item -> take payment (~8-12s, eyes + hands busy). Its purpose is to hold your attention when an Ambient anomaly spawns *during* it, forcing the triage choice: break off (lose patience / the sale) or finish (let the room escalate). Counter side generates Counter-anomalies; the room generates Ambient ones; the serve rhythm is the tether that makes Ambient anomalies scary. If serving becomes a skill test, pacing dies — keep it a rhythm, not a riddle.

### Hero anomaly pressure profiles (LOCKED — no two may share an axis)
Six is enough for M1 only because each occupies a different pressure axis. If two collapse onto the same axis, one is cut or redesigned.

| Anomaly | Placement | Pressure axis | Target feeling | M1 build note |
| --- | --- | --- | --- | --- |
| wrong_flag | Ambient | Attention-steal + escalation | "it changed while I was serving" | anthem swells; not always in view; escalates if ignored |
| impossible_money | Counter | Time-pressure (transaction won't close) | "deal with this NOW, hands full" | SENSORY ONLY — wet bills / impossible denomination / register chime reversed. Never arithmetic. |
| bad_member_card | Counter | Snap-judgment / red-herring bait | "is it wrong, or am I panicking?" | quick VISUAL tell — photo blinks, laminate warm, the name is yours. Never a long-read. |
| mascot_walking | Ambient | Approach dread + verb-cost | "getting closer, can't look away from the till" | KopDes-specific behavior (see below) |
| shelf_shift | Ambient | Slow-burn noise / false-positive bait | "was that always like that... ignore it... was it?" | low-stakes distractor that manufactures doubt |
| plank_gone | Ambient | Spatial / lockout | "a path just stopped existing" | weaponizes the tambak map; blocks a route/escape |

**mascot_walking gets KopDes-specific behavior (Fable note):** it does not just "creepy-move." It follows cooperative procedure INCORRECTLY — waits in the customer queue, presents an expired membership card, tries to "restock" a shelf with the wrong goods. Rule-violation as horror. The mascots are terrifying because they are doing their job, by the paperwork (see Character & Lore Bible).

## Core loop
Clock in -> read Rule Card -> serve customers (scan membership, take order, take payment; the 3-beat leash) while ambient anomalies brew -> detect anomalies via tells -> apply the correct handling verb (paying its cost) -> keep the meters alive -> survive to the shift clock -> payout -> lobby. Harder each shift (more concurrency, faster spawns, tighter drain).
Failure: Sanity meter, rule strikes, or a depleted resource -> bad ending.

## Handling verbs
Serve, RefuseAlarm, DontLook/Shutter, Restock, CallKades, CloseSign.

## Anomaly domains
Customer (Papers-Please layer), Product/register, Environment. Third-Eye limited-use tell (optional v1).

## Maps
Tambak (hero) -> Mountain slope -> Deep forest -> Empty highway -> "Supermarket" upgrade (late).

## Endings (target 10-20+)
Koperasi Sehat (good), Naik Kelas jadi Supermarket (bittersweet), Dana Habis (bankrupt), Diambil (death), Jadi Maskot (secret), Latsar Selamanya (secret). M1 ships exactly 2 (Koperasi Sehat + Diambil/Dana Habis).

## Characters
You (Manajer Kopdes) — trapped-by-debt, not heroic; named in the charter as surety; procedurally obedient because the rules are the only leverage left. Pak Kades (phone boss, spins disaster as procedure). Sleeping senior clerk (DontLook tutor; the previous manager who survived). Pak Satpam — CUT FROM M1 (reserved later as the plank/outside alarm). Si Merah & Si Putih (mascots -> antagonists). Night customers. The Auditor (BPKP role-reversal; recurring + escalating). Full detail in the Character & Lore Bible (Notion).

### Si Merah & Si Putih — locked identity
The paket sembako personified: the subsidized staples the co-op exists to hand out (red-and-white of the village pantry). A PAIR because the program's promise is always a pair. NOT ghosts in suits — they are what the tambak's hunger wears now that the state gave it a logo and a jingle. They keep serving forever because the program has no "closed" state. They speak ONLY in cheerful slogans / yel-yel, never overt menace — the diction gap is the scare.

## Lore
A cooperative rushed onto cursed/flooded ground to hit a national quota. Its charter accidentally bound it to the land's prior residents: stay open, stay stocked, never break the rules, or the debt (banjir dana) comes due. You are the collateral. The mascot knows.

**Lore north star (LOCKED):** the angle is NOT "cursed land + spooky mascots." It is "a government program tried to overwrite a haunted place with branding, paperwork, and fluorescent lighting — and the place answered using the same rules." Keep the horror in receipts, ledgers, announcements, signage, audit language, and impossible customer-service obligations. Do not explain the curse; let the player infer the rot from the forms.

## Monetization (fairness firewall)
Cosmetic/convenience/flair only, never anything that solves an anomaly or buys safety. Soft currency + Robux cosmetics, VIP pass, gacha (disclosed odds + pity), seasonal battle pass, opt-in rewarded ads.

## Live-ops
Biweekly meme drops; news-to-anomaly pipeline (new anomaly = 1 config file + art + 1 rule line); seasonal events (Ramadhan, 17 Agustus).

## Architecture
Hub-and-spoke: light social lobby + reserved shift instances (solo=1, co-op 2-4). Server-authoritative anomaly state. Data-driven anomalies (src/shared/anomalies/*) and shifts/rule cards (src/shared/shifts/*). DataStore (progress/currency/endings), OrderedDataStore (leaderboards), MemoryStore (matchmaking).

## Schemas
The code contract lives in `src/shared/Types.luau`. Anomaly = { id, name, domain, placement(Counter|Ambient), weight, minShift, tells{channel,cue,assetId,subtlety,escalates}, isRedHerring, correctVerb, verbCost{seconds,electricity,patience,cash}, onWrongVerb, onCorrectVerb, timeoutSeconds, onTimeout, tags, setup, cleanup }. Shift = { id, map, displayName, rules[{id,text,overrideVerb}], resources[ResourceMeter], anomalyPool, anomalyCount, concurrentMax, spawnGapSeconds, durationSeconds, customerCount, parSanity, endings }. Posted rules and validation read the SAME Shift table.

## Roadmap
M0 GDD -> M1 vertical slice (Tambak, 6 anomalies, rule card, sanity+strikes, Electricity+Patience meters, concurrency, 2 endings) -> M2 core content -> M3 co-op -> M4 live-ops framework -> M5 soft launch -> M6+ meme cadence.

M1 hero anomalies: wrong_flag, impossible_money, bad_member_card, mascot_walking, shelf_shift, plank_gone. M1 meters: Electricity + Patience only.

## Tooling
Brain (Notion AI) / Engineer (2nd session) / Studio + Assistant. Antigravity IDE -> Rojo -> Studio. Repo is the contract; GDD.md is the synced snapshot.
