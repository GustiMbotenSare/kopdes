--!strict
-- src/server/ResourceService.luau
-- ENG-6: per-shift ResourceMeters that drain over time and via verbCost.
-- M1 SCOPE: Electricity + Patience only (do not add more meters yet).
-- On depletion, route to sanity / strike / ending per ResourceMeter.onDepleted.
-- STATUS: stub — Engineer implements.
local ResourceService = {}

function ResourceService.init(_meters: {}): ()
	-- TODO(ENG-6)
end

function ResourceService.spend(_id: string, _amount: number): ()
	-- TODO(ENG-6): called by verbCost handling.
end

return ResourceService
