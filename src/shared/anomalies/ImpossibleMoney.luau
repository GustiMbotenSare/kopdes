--!strict
-- src/shared/anomalies/ImpossibleMoney.luau
-- Hero anomaly (M1). The COUNTER counterpart to wrong_flag (Ambient), so the
-- slice can actually exercise concurrentMax=2 across both placements.
-- LOCKED guardrail: SENSORY ONLY. Never arithmetic. If it can only be caught
-- by doing math on the payment, it is disqualified. Pressure axis =
-- time-pressure: the transaction will not close while you're staring at it.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local anomaly: Types.Anomaly = {
	id = "impossible_money",
	name = "Cursed payment at the till",
	domain = "Customer",
	placement = "Counter", -- foreground; happens in your hands mid-serve
	weight = 10,
	minShift = 1,
	tells = {
		-- All sensory. The player never counts change; they FEEL the wrongness.
		{ channel = "Visual", cue = "Bills are wet/dripping; ink runs when handled.", subtlety = 2, escalates = true },
		{ channel = "Audio", cue = "Register chime plays reversed / detuned when the drawer opens.", assetId = "rbxassetid://0", subtlety = 3 },
		{ channel = "Visual", cue = "An impossible denomination (a note that shows Rp 0, or a face that blinks).", subtlety = 3 },
	},
	correctVerb = "RefuseAlarm", -- refuse the payment and sound the alarm
	verbCost = { seconds = 2, patience = 5 }, -- Counter handling makes the queue wait
	onWrongVerb = { sanity = -25, strike = true }, -- accepting the cursed money
	onCorrectVerb = { sanity = 0, reward = 10 },
	timeoutSeconds = 18, -- the sale won't close; standing there is the pressure
	onTimeout = { sanity = -15, strike = true },
	tags = { "customer", "payment" },
	setup = function(ctx)
		local customer = ctx.customer
		if customer then
			customer:SetAttribute("CursedPayment", true)
		end
	end,
	cleanup = function(ctx)
		local customer = ctx.customer
		if customer then
			customer:SetAttribute("CursedPayment", false)
		end
	end,
}

return anomaly
