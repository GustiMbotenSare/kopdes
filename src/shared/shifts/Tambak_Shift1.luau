--!strict
-- src/shared/shifts/Tambak_Shift1.luau
-- M1 prototype shift. RuleCardService loads this; posted rules AND validation
-- read from the SAME table. Never hardcode a rule in a script.
-- SLICE SCOPE: pool is restricted to the anomalies that have data files today
-- (wrong_flag = Ambient, impossible_money = Counter) so the slice runs clean
-- AND actually exercises concurrentMax=2 across both placements. Full 6-anomaly
-- pool is the M2 target (see GDD.md / Notion Living Spec):
--   wrong_flag, impossible_money, bad_member_card, mascot_walking, shelf_shift, plank_gone
--
-- METER BALANCE (2026-07-06, first-pass playtest values):
-- Both endings must be reachable. Base drain alone must NOT decide the run --
-- it leaves headroom that the escalation bites (Ambient->Electricity 3/step,
-- Counter->Patience 5/step) and verb costs eat into. So survival = handle things
-- promptly; failure = let anomalies ride. Tune after the first Studio playtest.
--   Electricity: 0.2/s -> 60 over 300s, ~40 headroom (was 0.6 = unreachable good ending)
--   Patience:    0.15/s -> 45 over 300s, ~55 headroom (was 0.3 = near-guaranteed auto-strike)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local shift: Types.Shift = {
	id = "shift01_tambak",
	map = "Tambak",
	displayName = "Malam Pertama — Tambak",
	rules = {
		{ id = "r1", text = "Layani hanya anggota dengan kartu sah." },
		{ id = "r2", text = "Bendera terbalik? JANGAN layani. Bunyikan alarm.", overrideVerb = { anomalyId = "wrong_flag", verb = "RefuseAlarm" } },
		{ id = "r3", text = "Uang basah, lecek, atau nominal aneh? JANGAN terima. Bunyikan alarm.", overrideVerb = { anomalyId = "impossible_money", verb = "RefuseAlarm" } },
		{ id = "r4", text = "Jangan menatap sesuatu yang tidak seharusnya bergerak." },
	},
	resources = {
		{ id = "Electricity", max = 100, start = 100, drainPerSec = 0.2, onDepleted = "ending", onDepletedEnding = "diambil" },
		{ id = "Patience", max = 100, start = 100, drainPerSec = 0.15, onDepleted = "strike" },
	},
	anomalyPool = { "wrong_flag", "impossible_money" },
	anomalyCount = 6,
	concurrentMax = 2,
	spawnGapSeconds = { min = 12, max = 20 },
	durationSeconds = 300,
	customerCount = 8,
	parSanity = 100,
	endings = { good = "koperasi_sehat", bankrupt = "dana_habis", taken = "diambil" },
}

return shift
