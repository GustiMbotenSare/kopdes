# KOPDES: Merah Putih Anomalies

A rules-based anomaly-horror shift sim for Roblox. Night-shift a village cooperative (Koperasi Desa Merah Putih) built absurdly far from civilization; serve the night customers, obey the posted Rule Card, spot anomalies, survive to morning.

## Source of truth
- **Design master:** Notion Living Spec + Engineer Kickoff doc.
- **Repo snapshot:** `GDD.md` (keep in sync with the spec).
- **Code contract:** `src/shared/Types.luau` — the Anomaly / Shift schema. Do not diverge; if a shape is wrong, fix it in the spec first, then here.

## Design north star
Triage under drain, **not** a reading simulator. Anomalies are found via sensory *tells* (visual/audio/environmental); verbs *cost* time/resources; multiple anomalies run *concurrently* against draining meters + a shift clock.

## Layout
- `src/server` -> ServerScriptService (services; server-authoritative)
- `src/client` -> StarterPlayerScripts (UI, rendering)
- `src/shared` -> ReplicatedStorage (Types + data-driven `anomalies/` and `shifts/`)

## Dev setup
1. Install [Rojo](https://rojo.space/) + the Roblox Studio plugin.
2. `rojo serve` from the repo root (uses `default.project.json`).
3. Connect from Studio and build against the M1 backlog (GitHub Issues, `ENG-*`).

## Adding content
A new anomaly = one file in `src/shared/anomalies/`. A new shift = one file in `src/shared/shifts/`. Never hardcode a rule in a script — it comes from the `Shift` table.
