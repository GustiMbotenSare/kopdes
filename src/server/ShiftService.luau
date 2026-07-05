--!strict
-- src/server/ShiftService.luau
-- ENG-5: THE vertical-slice core. Run one shift on a real clock.
--   * start durationSeconds countdown
--   * spawn customers; fire anomalies respecting concurrentMax + spawnGapSeconds
--   * accept player verbs; apply verbCost + onWrongVerb/onCorrectVerb/onTimeout
--   * resolve an ending id and report it
-- Server-authoritative. Depends on AnomalyService, RuleCardService,
-- SanityService, ResourceService. STATUS: stub — Engineer implements.
local ShiftService = {}

function ShiftService.start(_shiftId: string): ()
	-- TODO(ENG-5): the loop. This is the first thing that should run in Studio.
end

return ShiftService
