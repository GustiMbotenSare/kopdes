--!strict
-- src/server/ShiftService.luau
-- ENG-5: THE vertical-slice core. Runs one shift on a real clock.
--   * durationSeconds countdown
--   * spawn customers; fire anomalies respecting concurrentMax + spawnGapSeconds
--     (gaps tighten late-shift)
--   * accept player verbs (SERVER-AUTHORITATIVE), apply verbCost then
--     onCorrectVerb / onWrongVerb; handle timeoutSeconds -> onTimeout
--   * resolve + return an ending id
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local AnomalyService = require(script.Parent.AnomalyService)
local RuleCardService = require(script.Parent.RuleCardService)
local ResourceService = require(script.Parent.ResourceService)
local SanityService = require(script.Parent.SanityService)

local ShiftService = {}

type ActiveAnomaly = {
	anomaly: Types.Anomaly,
	context: Types.AnomalyContext,
	spawnedAt: number,
	expiresAt: number?,
	resolved: boolean,
}

local running = false
local active: { [string]: ActiveAnomaly } = {}
local endingResolved: string? = nil
local connected = false

-- Net: created at runtime so the ENG-7/8 client HUD can bind later. For the M1
-- console proof, verbs can also be driven via ShiftService.submitVerb(...).
local function ensureRemotes(): (RemoteEvent, RemoteEvent)
	local net = ReplicatedStorage:FindFirstChild("Net")
	if not net then
		local folder = Instance.new("Folder")
		folder.Name = "Net"
		folder.Parent = ReplicatedStorage
		net = folder
	end
	assert(net, "Net folder missing")

	local submit = net:FindFirstChild("SubmitVerb")
	if not submit then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "SubmitVerb"
		ev.Parent = net
		submit = ev
	end

	local broadcast = net:FindFirstChild("ShiftEvent")
	if not broadcast then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "ShiftEvent"
		ev.Parent = net
		broadcast = ev
	end

	return submit :: RemoteEvent, broadcast :: RemoteEvent
end

-- The room is a hand-built model named after shift.map (e.g. Workspace.Tambak)
-- containing a `Flag` instance (WrongFlag.setup needs ctx.room.Flag). If it's
-- missing we spawn a labelled PLACEHOLDER so the loop still proves out -- but the
-- real art/room is still the Studio task.
local function ensureRoom(mapName: string): Instance
	local existing = Workspace:FindFirstChild(mapName)
	if existing then
		if not existing:FindFirstChild("Flag") then
			warn(("[ShiftService] Workspace.%s has no child named 'Flag' -- WrongFlag needs ctx.room.Flag"):format(mapName))
		end
		return existing
	end

	warn(("[ShiftService] Workspace.%s not found -- spawning a PLACEHOLDER room. Build the real Tambak model by hand."):format(mapName))
	local model = Instance.new("Model")
	model.Name = mapName
	local function makePart(name: string, y: number): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(4, 4, 4)
		p.Position = Vector3.new(0, y, 0)
		p.Parent = model
		return p
	end
	makePart("Flag", 8)
	makePart("Counter", 2)
	model.PrimaryPart = makePart("CustomerSpawn", 1)
	model.Parent = Workspace
	return model
end

local function resolveEnding(id: string): ()
	if endingResolved then
		return
	end
	endingResolved = id
end

local function cleanupActive(id: string): ()
	local entry = active[id]
	if not entry then
		return
	end
	entry.resolved = true
	local ok, err = pcall(entry.anomaly.cleanup, entry.context)
	if not ok then
		warn(("[ShiftService] cleanup error for '%s': %s"):format(id, tostring(err)))
	end
	active[id] = nil
end

-- SERVER-AUTHORITATIVE verb resolution. We take only (anomalyId, verb) and
-- compute the outcome here -- the client's opinion of correctness is ignored.
function ShiftService.submitVerb(anomalyId: string, verb: string): ()
	if not running then
		return
	end
	local entry = active[anomalyId]
	if not entry or entry.resolved then
		warn(("[ShiftService] verb '%s' ignored -- anomaly '%s' is not active"):format(verb, anomalyId))
		return
	end
	local anomaly = entry.anomaly

	-- Acting costs regardless of correctness (triage, not a free click).
	local cost = anomaly.verbCost
	if cost then
		if cost.electricity then
			ResourceService.spend("Electricity", cost.electricity)
		end
		if cost.patience then
			ResourceService.spend("Patience", cost.patience)
		end
		-- cost.seconds (action lockout) + cost.cash deferred: no lockout in the
		-- console proof, and Cash isn't an M1 meter.
	end

	local expected = RuleCardService.expectedVerb(anomalyId)
	if verb == expected then
		local oc = anomaly.onCorrectVerb
		SanityService.apply(oc.sanity)
		print(("[OK] [%s] correct verb '%s' (+%d reward, sanity %+d) -- sanity=%d"):format(anomalyId, verb, oc.reward, oc.sanity, SanityService.get()))
	else
		local ow = anomaly.onWrongVerb
		SanityService.apply(ow.sanity)
		if ow.strike then
			SanityService.addStrike()
		end
		print(("[X] [%s] wrong verb '%s' (expected '%s') -- sanity %+d, strike=%s (sanity=%d strikes=%d)"):format(anomalyId, verb, tostring(expected), ow.sanity, tostring(ow.strike), SanityService.get(), SanityService.getStrikes()))
		if ow.triggersEnding then
			resolveEnding(ow.triggersEnding)
		end
	end

	cleanupActive(anomalyId)
end

local function spawnAnomaly(anomaly: Types.Anomaly, shift: Types.Shift, room: Instance): ()
	local context: Types.AnomalyContext = {
		room = room,
		customer = nil, -- Counter customer wiring is ENG-7; Ambient tells don't need it
		seed = math.random(1, 2147483647),
		shiftId = shift.id,
	}
	local entry: ActiveAnomaly = {
		anomaly = anomaly,
		context = context,
		spawnedAt = os.clock(),
		expiresAt = if anomaly.timeoutSeconds then os.clock() + anomaly.timeoutSeconds else nil,
		resolved = false,
	}
	active[anomaly.id] = entry

	local ok, err = pcall(anomaly.setup, context)
	if not ok then
		warn(("[ShiftService] setup error for '%s': %s"):format(anomaly.id, tostring(err)))
	end

	print(("[SPAWN] [%s] \"%s\" (%s / %s) -- expected verb: %s"):format(anomaly.id, anomaly.name, anomaly.domain, anomaly.placement, tostring(RuleCardService.expectedVerb(anomaly.id))))
	for _, tell in ipairs(anomaly.tells) do
		print(("      tell(%s, subtlety %d%s): %s"):format(tell.channel, tell.subtlety, if tell.escalates then ", escalates" else "", tell.cue))
	end
end

local function handleTimeouts(): ()
	local now = os.clock()
	for id, entry in pairs(active) do
		if not entry.resolved and entry.expiresAt and now >= entry.expiresAt then
			local ot = entry.anomaly.onTimeout
			if ot then
				SanityService.apply(ot.sanity)
				if ot.strike then
					SanityService.addStrike()
				end
				if ot.triggersEnding then
					resolveEnding(ot.triggersEnding)
				end
				print(("[TIMEOUT] [%s] -- sanity %+d, strike=%s (sanity=%d strikes=%d)"):format(id, ot.sanity, tostring(ot.strike), SanityService.get(), SanityService.getStrikes()))
			else
				print(("[TIMEOUT] [%s] (no onTimeout defined)"):format(id))
			end
			cleanupActive(id)
		end
	end
end

local function countActive(): number
	local n = 0
	for _ in pairs(active) do
		n += 1
	end
	return n
end

local function ensureConnections(): ()
	if connected then
		return
	end
	connected = true
	local submit = ensureRemotes()
	submit.OnServerEvent:Connect(function(_player, anomalyId, verb)
		if type(anomalyId) ~= "string" or type(verb) ~= "string" then
			return
		end
		ShiftService.submitVerb(anomalyId, verb)
	end)
end

-- Runs one shift to completion and returns the resolved ending id.
function ShiftService.start(shiftId: string): string
	if running then
		warn("[ShiftService] a shift is already running")
		return ""
	end

	AnomalyService.init()
	local shift = RuleCardService.load(shiftId)
	local room = ensureRoom(shift.map)

	ResourceService.init(shift.resources)
	SanityService.init(shift.parSanity)
	ensureConnections()

	active = {}
	endingResolved = nil
	running = true

	SanityService.onFail(function(reason: string)
		print(("[ShiftService] sanity failure (%s)"):format(reason))
		resolveEnding(shift.endings.taken)
	end)
	ResourceService.onDepleted(function(meter: Types.ResourceMeter)
		print(("[ShiftService] meter depleted: %s -> %s"):format(meter.id, meter.onDepleted))
		if meter.onDepleted == "ending" then
			resolveEnding(meter.onDepletedEnding or shift.endings.taken)
		elseif meter.onDepleted == "strike" then
			SanityService.addStrike()
		elseif meter.onDepleted == "sanity" then
			SanityService.apply(-20) -- damage amount unspecified in spec; tunable
		end
	end)

	local queue = AnomalyService.pickForShift(shift)
	print(("[ShiftService] >> START '%s' -- %ds clock, %d anomalies queued, concurrentMax=%d"):format(shift.displayName, shift.durationSeconds, #queue, shift.concurrentMax))
	local _, broadcast = ensureRemotes()
	broadcast:FireAllClients("ShiftStarted", { shiftId = shift.id, rules = RuleCardService.getRules() })

	local startClock = os.clock()
	local endsAt = startClock + shift.durationSeconds

	local function nextGap(): number
		local progress = math.clamp((os.clock() - startClock) / shift.durationSeconds, 0, 1)
		local tighten = 1 - 0.5 * progress -- up to 50% faster by end of shift
		local span = shift.spawnGapSeconds.max - shift.spawnGapSeconds.min
		return (shift.spawnGapSeconds.min + math.random() * span) * tighten
	end

	local queueIndex = 1
	local nextSpawnAt = startClock + nextGap()
	local customerGap = shift.durationSeconds / math.max(shift.customerCount, 1)
	local nextCustomerAt = startClock + customerGap
	local customerN = 0
	local lastTick = startClock

	while running do
		local now = os.clock()
		local dt = now - lastTick
		lastTick = now

		ResourceService.tick(dt)
		handleTimeouts()

		if now >= nextSpawnAt and countActive() < shift.concurrentMax and queueIndex <= #queue then
			spawnAnomaly(queue[queueIndex], shift, room)
			queueIndex += 1
			nextSpawnAt = now + nextGap()
		end

		if now >= nextCustomerAt and customerN < shift.customerCount then
			customerN += 1
			print(("[CUSTOMER] %d/%d approaches the counter."):format(customerN, shift.customerCount))
			nextCustomerAt = now + customerGap
		end

		if endingResolved then
			break
		end
		if now >= endsAt then
			-- Survived the clock with sanity + meters intact.
			resolveEnding(shift.endings.good)
			break
		end

		task.wait(0.2)
	end

	for id in pairs(active) do
		cleanupActive(id)
	end
	running = false

	local ending = endingResolved or shift.endings.good
	print(("[ShiftService] == SHIFT OVER -- ending='%s' | sanity=%d strikes=%d Electricity=%.0f Patience=%.0f"):format(ending, SanityService.get(), SanityService.getStrikes(), ResourceService.get("Electricity"), ResourceService.get("Patience")))
	broadcast:FireAllClients("ShiftEnded", { ending = ending })
	return ending
end

function ShiftService.isRunning(): boolean
	return running
end

return ShiftService
