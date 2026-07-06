--!strict
-- src/server/AnomalyService.luau
-- ENG-3: auto-load every ModuleScript under ReplicatedStorage.Shared.anomalies,
-- build a weighted registry, expose pickForShift(shift).
-- Contract: Types.Anomaly. Data-driven: a new file in anomalies/ registers
-- itself with ZERO edits here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local AnomalyService = {}

local registry: { [string]: Types.Anomaly } = {}
local initialized = false

function AnomalyService.init(): ()
	if initialized then
		return
	end
	initialized = true

	local folder = Shared:WaitForChild("anomalies")
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if not ok then
				warn(("[AnomalyService] failed to require '%s': %s"):format(child.Name, tostring(result)))
			elseif typeof(result) ~= "table" or type((result :: any).id) ~= "string" then
				warn(("[AnomalyService] '%s' did not return a valid Anomaly (missing string id)"):format(child.Name))
			else
				local anomaly = result :: Types.Anomaly
				if registry[anomaly.id] then
					warn(("[AnomalyService] duplicate anomaly id '%s' from '%s' -- overwriting"):format(anomaly.id, child.Name))
				end
				registry[anomaly.id] = anomaly
			end
		end
	end

	local count = 0
	for _ in pairs(registry) do
		count += 1
	end
	print(("[AnomalyService] registered %d anomalies"):format(count))
end

function AnomalyService.get(id: string): Types.Anomaly?
	return registry[id]
end

function AnomalyService.all(): { [string]: Types.Anomaly }
	return registry
end

-- CONTRACT NOTE (flagged to Brain): Types.Shift has no explicit ordinal, but
-- Anomaly.minShift needs the shift's number. Until the spec adds Shift.number,
-- we derive it from the digits in the id ("shift01_tambak" -> 1). Fallback = 1.
local function shiftNumber(shift: Types.Shift): number
	local digits = string.match(shift.id, "%d+")
	return (digits and tonumber(digits)) or 1
end

-- pickForShift(shift): draw `anomalyCount` activations from the shift's eligible
-- pool. WITH REPLACEMENT and weighted -- a 2-item pool with anomalyCount=6 is a
-- deliberate signal to produce 6 activations (repeats allowed) so the shift has
-- enough events, across BOTH placements, to exercise concurrentMax. Filtered by
-- minShift; unknown ids warn (not yet authored) and are skipped.
function AnomalyService.pickForShift(shift: Types.Shift): { Types.Anomaly }
	AnomalyService.init()
	local shiftNo = shiftNumber(shift)

	local eligible: { Types.Anomaly } = {}
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(shift.anomalyPool) do
		local anomaly = registry[id]
		if not anomaly then
			warn(("[AnomalyService] shift '%s' references unknown anomaly '%s' (not authored yet?)"):format(shift.id, id))
		elseif seen[id] then
			-- ignore duplicate ids in the pool
		elseif anomaly.minShift > shiftNo then
			-- not eligible until a later shift
		else
			seen[id] = true
			table.insert(eligible, anomaly)
		end
	end

	local out: { Types.Anomaly } = {}
	if #eligible == 0 then
		return out
	end

	local total = 0
	for _, anomaly in ipairs(eligible) do
		total += math.max(anomaly.weight, 0)
	end

	for _ = 1, math.max(shift.anomalyCount, 0) do
		local pick = eligible[#eligible]
		if total > 0 then
			local roll = math.random() * total
			local acc = 0
			for _, anomaly in ipairs(eligible) do
				acc += math.max(anomaly.weight, 0)
				if roll <= acc then
					pick = anomaly
					break
				end
			end
		end
		table.insert(out, pick)
	end

	return out
end

return AnomalyService
