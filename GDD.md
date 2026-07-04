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

## Core loop
Clock in -> read Rule Card -> serve customers (scan membership, take order, take payment) -> detect anomalies (customer / product / environment) -> apply correct handling verb -> survive shift -> payout -> lobby. Harder each shift.
Failure: Sanity meter + rule strikes -> bad ending.

## Handling verbs
Serve, RefuseAlarm, DontLook/Shutter, Restock, CallKades, CloseSign.

## Anomaly domains
Customer (Papers-Please layer), Product/register, Environment. Third-Eye limited-use tell (optional v1).

## Maps
Tambak (hero) -> Mountain slope -> Deep forest -> Empty highway -> "Supermarket" upgrade (late).

## Endings (target 10-20+)
Koperasi Sehat (good), Naik Kelas jadi Supermarket (bittersweet), Dana Habis (bankrupt), Diambil (death), Jadi Maskot (secret), Latsar Selamanya (secret).

## Characters
You (Manajer Kopdes), Pak Kades (phone boss), sleeping senior clerk, Pak Satpam, Si Merah & Si Putih (mascots -> antagonists), night customers, the Auditor (BPKP role-reversal).

## Lore
A cooperative rushed onto cursed/flooded ground to hit a national quota. Its charter accidentally bound it to the land's prior residents: stay open, stay stocked, never break the rules, or the debt (banjir dana) comes due. You are the collateral. The mascot knows.

## Monetization (fairness firewall)
Cosmetic/convenience/flair only, never anything that solves an anomaly or buys safety. Soft currency + Robux cosmetics, VIP pass, gacha (disclosed odds + pity), seasonal battle pass, opt-in rewarded ads.

## Live-ops
Biweekly meme drops; news-to-anomaly pipeline (new anomaly = 1 config file + art + 1 rule line); seasonal events (Ramadhan, 17 Agustus).

## Architecture
Hub-and-spoke: light social lobby + reserved shift instances (solo=1, co-op 2-4). Server-authoritative anomaly state. Data-driven anomalies (src/shared/anomalies/*) and shifts/rule cards (src/shared/shifts/*). DataStore (progress/currency/endings), OrderedDataStore (leaderboards), MemoryStore (matchmaking).

## Schemas (see Notion Engineer Kickoff for full detail)
Anomaly = { id, name, domain(Customer|Product|Environment), weight, minShift, tell, correctVerb, onWrongVerb{sanity,strike,triggersEnding?}, onCorrectVerb{sanity,reward}, timeoutSeconds?, tags[], setup(ctx), cleanup(ctx) }.
Shift/RuleCard = { id, map, displayName, rules[{id,text,overrideVerb?}], anomalyPool[], anomalyCount, customerCount, parSanity, endings{good,bankrupt,taken} }.
Design rule: posted rules and validation read the SAME Shift table. Never hardcode a rule in a script.

## Roadmap
M0 GDD -> M1 prototype (Tambak, 6 anomalies, rule card, sanity+strikes, 2 endings) -> M2 core content -> M3 co-op -> M4 live-ops framework -> M5 soft launch -> M6+ meme cadence.

M1 hero anomalies: wrong_flag, impossible_money, bad_member_card, mascot_walking, shelf_shift, plank_gone.

## Tooling
Brain (Notion AI) / Engineer (2nd session) / Studio + Assistant. Antigravity IDE -> Rojo -> Studio. Repo is the contract; GDD.md is the synced snapshot.
