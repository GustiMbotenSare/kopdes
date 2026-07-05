--!strict
-- src/server/RuleCardService.luau
-- ENG-4: load a Shift (Types.Shift) from ReplicatedStorage.Shared.shifts,
-- expose its posted rules AND expectedVerb(anomalyId) from the SAME table
-- (apply Rule.overrideVerb over an anomaly's default correctVerb).
-- STATUS: stub — Engineer implements.
local RuleCardService = {}

function RuleCardService.load(_shiftId: string): ()
	-- TODO(ENG-4)
end

function RuleCardService.expectedVerb(_anomalyId: string): string?
	-- TODO(ENG-4): default correctVerb unless a rule overrides it tonight.
	return nil
end

return RuleCardService
