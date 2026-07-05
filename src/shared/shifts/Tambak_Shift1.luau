--!strict
-- src/shared/shifts/Tambak_Shift1.luau
-- M1 prototype shift. RuleCardService loads this; posted rules AND validation
-- read from the SAME table. Never hardcode a rule in a script.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local shift: Types.Shift = {
	id = "shift01_tambak",
	map = "Tambak",
	displayName = "Malam Pertama — Tambak",
	rules = {
		{ id = "r1", text = "Layani hanya anggota dengan kartu sah." },
		{ id = "r2", text = "Bendera terbalik? JANGAN layani. Bunyikan alarm.", overrideVerb = { anomalyId = "wrong_flag", verb = "RefuseAlarm" } },
		{ id = "r3", text = "Jangan menatap sesuatu yang tidak seharusnya bergerak." },
	},
	resources = {
		{ id = "Electricity", max = 100, start = 100, drainPerSec = 0.6, onDepleted = "ending", onDepletedEnding = "diambil" },
		{ id = "Patience", max = 100, start = 100, drainPerSec = 0.3, onDepleted = "strike" },
	},
	anomalyPool = { "wrong_flag", "impossible_money", "bad_member_card", "mascot_walking", "shelf_shift", "plank_gone" },
	anomalyCount = 6,
	concurrentMax = 2,
	spawnGapSeconds = { min = 12, max = 20 },
	durationSeconds = 300,
	customerCount = 8,
	parSanity = 100,
	endings = { good = "koperasi_sehat", bankrupt = "dana_habis", taken = "diambil" },
}

return shift
