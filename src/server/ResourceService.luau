--!strict
-- src/server/ResourceService.luau
-- ENG-6 (minimal -- required by ENG-5): per-shift ResourceMeters that drain over
-- time and via verbCost/escalation. M1 SCOPE: Electricity + Patience only.
-- On depletion, routes via the registered handler per ResourceMeter.onDepleted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local ResourceService = {}

type MeterState = {
	def: Types.ResourceMeter,
	value: number,
	depleted: boolean,
}

local meters: { [string]: MeterState } = {}
local depletedHandler: ((meter: Types.ResourceMeter) -> ())? = nil

function ResourceService.init(defs: { Types.ResourceMeter }): ()
	meters = {}
	for _, def in ipairs(defs) do
		meters[def.id] = { def = def, value = def.start, depleted = false }
	end
end

function ResourceService.onDepleted(handler: (meter: Types.ResourceMeter) -> ()): ()
	depletedHandler = handler
end

local function checkDepleted(state: MeterState): ()
	if not state.depleted and state.value <= 0 then
		state.value = 0
		state.depleted = true
		if depletedHandler then
			depletedHandler(state.def)
		end
	end
end

-- Called by verbCost / escalation handling.
function ResourceService.spend(id: string, amount: number): ()
	local state = meters[id]
	if not state or amount == 0 then
		return
	end
	state.value = math.clamp(state.value - amount, 0, state.def.max)
	checkDepleted(state)
end

-- Passive drain; call once per frame with delta seconds.
function ResourceService.tick(dt: number): ()
	for _, state in pairs(meters) do
		if not state.depleted and state.def.drainPerSec > 0 then
			state.value = math.clamp(state.value - state.def.drainPerSec * dt, 0, state.def.max)
			checkDepleted(state)
		end
	end
end

function ResourceService.get(id: string): number
	local state = meters[id]
	return if state then state.value else 0
end

return ResourceService
