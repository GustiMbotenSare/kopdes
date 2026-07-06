--!strict
-- src/server/RuleCardService.luau
-- ENG-4: load a Shift (Types.Shift) from ReplicatedStorage.Shared.shifts, expose
-- its posted rules (for the in-world rule card UI) AND expectedVerb(anomalyId)
-- for server-side validation -- BOTH from the SAME table so they never diverge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local AnomalyService = require(script.Parent.AnomalyService)

local RuleCardService = {}

local currentShift: Types.Shift? = nil
local overrides: { [string]: Types.Verb } = {}

function RuleCardService.load(shiftId: string): Types.Shift
	local folder = Shared:WaitForChild("shifts")
	local loaded: Types.Shift? = nil
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok and typeof(result) == "table" and (result :: any).id == shiftId then
				loaded = result :: Types.Shift
				break
			end
		end
	end

	if not loaded then
		error(("[RuleCardService] shift '%s' not found in Shared.shifts"):format(shiftId))
	end
	local shift = loaded :: Types.Shift

	currentShift = shift
	overrides = {}
	for _, rule in ipairs(shift.rules) do
		local ov = rule.overrideVerb
		if ov then
			overrides[ov.anomalyId] = ov.verb
		end
	end

	print(("[RuleCardService] loaded '%s' (%s) -- %d posted rules"):format(shift.id, shift.displayName, #shift.rules))
	return shift
end

function RuleCardService.getShift(): Types.Shift?
	return currentShift
end

-- Posted rules for the UI: the verbatim text the player reads on the card.
function RuleCardService.getRules(): { Types.Rule }
	local shift = currentShift
	return if shift then shift.rules else {}
end

-- expectedVerb = the anomaly's own correctVerb, UNLESS tonight's rule card remaps
-- it via Rule.overrideVerb. Same source of truth as getRules().
function RuleCardService.expectedVerb(anomalyId: string): Types.Verb?
	local override = overrides[anomalyId]
	if override then
		return override
	end
	local anomaly = AnomalyService.get(anomalyId)
	return if anomaly then anomaly.correctVerb else nil
end

return RuleCardService
