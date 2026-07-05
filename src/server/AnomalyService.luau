--!strict
-- src/server/AnomalyService.luau
-- ENG-3: auto-load every ModuleScript under ReplicatedStorage.Shared.anomalies,
-- build a weighted registry, expose pickForShift(shift) honoring weight + minShift.
-- Contract: Types.Anomaly. STATUS: stub — Engineer implements.
local AnomalyService = {}

function AnomalyService.init(): ()
	-- TODO(ENG-3): require + register all anomalies by id.
end

function AnomalyService.pickForShift(_shiftId: string): {}
	-- TODO(ENG-3): return a weighted selection of Anomaly for this shift.
	return {}
end

return AnomalyService
