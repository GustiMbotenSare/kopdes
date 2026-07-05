--!strict
-- src/shared/anomalies/WrongFlag.luau
-- Hero anomaly (M1). Data-driven; AnomalyService auto-loads this folder.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local anomaly: Types.Anomaly = {
	id = "wrong_flag",
	name = "Merah-Putih flag colors swapped",
	domain = "Environment",
	placement = "Ambient", -- lives in the room; player must glance up
	weight = 10,
	minShift = 1,
	tells = {
		{ channel = "Visual", cue = "Wall flag is white-over-red (inverted).", subtlety = 2, escalates = true },
		{ channel = "Audio", cue = "Faint anthem plays slightly out of tune.", assetId = "rbxassetid://0", subtlety = 4 },
	},
	correctVerb = "RefuseAlarm",
	verbCost = { seconds = 2, electricity = 1 },
	onWrongVerb = { sanity = -25, strike = true },
	onCorrectVerb = { sanity = 0, reward = 10 },
	timeoutSeconds = 20,
	onTimeout = { sanity = -15, strike = true },
	tags = { "environment", "branding" },
	setup = function(ctx)
		ctx.room.Flag:SetAttribute("Inverted", true)
	end,
	cleanup = function(ctx)
		ctx.room.Flag:SetAttribute("Inverted", false)
	end,
}

return anomaly
