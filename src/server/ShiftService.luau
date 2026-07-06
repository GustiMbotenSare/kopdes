--!strict
-- src/server/ShiftService.luau
-- ENG-5: THE vertical-slice core, session 2 = concurrency-real.
-- Design bar (GDD Fable QA): the player must have to abandon the customer in
-- front of them because the room moved behind them. So:
--   * a serve-loop LEASH occupies the player (customers at the counter)
--   * Counter anomalies anchor to the active customer (ctx.customer)
--   * Ambient anomalies anchor to the room (ctx.room.Flag) and INTRUDE while a
--     Counter anomaly is live -> 1 Counter + 1 Ambient = concurrentMax(2)
--   * verbCost.seconds is a REAL lockout: while your hands are full the OTHER
--     anomaly keeps escalating + draining -- that is the cost
--   * escalation is REAL: server owns an escalation level (attribute the client
--     renders) with a resource bite each step
-- Server-authoritative: client sends verb INTENT only; server owns truth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local AnomalyService = require(script.Parent.AnomalyService)
local RuleCardService = require(script.Parent.RuleCardService)
local ResourceService = require(script.Parent.ResourceService)
local SanityService = require(script.Parent.SanityService)

local ShiftService = {}

-- Tunables NOT in the schema (flagged to Brain to formalize later).
local ESC_INTERVAL = 4 -- seconds between escalation steps
local ESC_MAX = 3 -- escalation level cap
local SERVE_SECONDS = 9 -- the 3-beat leash for a plain customer
local CUSTOMER_GAP = 3 -- gap between customers at the counter
local AMBIENT_INTRUDE_MIN = 3 -- ambient intrudes this soon after a Counter goes live
local AMBIENT_INTRUDE_MAX = 6

type ActiveAnomaly = {
	uid: string,
	anomaly: Types.Anomaly,
	placement: string,
	context: Types.AnomalyContext,
	anchor: Instance?,
	customer: Instance?,
	spawnedAt: number,
	expiresAt: number?,
	resolved: boolean,
	escLevel: number,
	nextEscAt: number,
	escalating: boolean,
}

local running = false
local endingResolved: string? = nil
local active: { [string]: ActiveAnomaly } = {}
local uidCounter = 0
local lockedUntil = 0
local connected = false
local currentShift: Types.Shift? = nil
local currentRoom: Instance? = nil
local currentCustomer: Instance? = nil
local currentCustomerUid: string? = nil

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

-- Hand-built room named after shift.map (Workspace.Tambak) with a `Flag` child.
-- If missing, spawn a labelled PLACEHOLDER so the loop still proves out -- the
-- real wired room is still the Studio task.
local function ensureRoom(mapName: string): Instance
	local existing = Workspace:FindFirstChild(mapName)
	if existing then
		if not existing:FindFirstChild("Flag") then
			warn(("[ShiftService] Workspace.%s has no child named 'Flag' -- wrong_flag needs ctx.room.Flag"):format(mapName))
		end
		return existing
	end

	warn(("[ShiftService] Workspace.%s not found -- spawning PLACEHOLDER room. Build the real Tambak by hand."):format(mapName))
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

local function spawnCustomer(room: Instance): Instance
	local c = Instance.new("Part")
	c.Name = "Customer"
	c.Anchored = true
	c.Size = Vector3.new(2, 5, 1)
	c.Color = Color3.fromRGB(200, 200, 200)
	local spawnPoint = room:FindFirstChild("CustomerSpawn")
	if spawnPoint and spawnPoint:IsA("BasePart") then
		c.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
	else
		c.Position = Vector3.new(0, 3, 6)
	end
	c.Parent = room
	return c
end

local function countActive(): number
	local n = 0
	for _ in pairs(active) do
		n += 1
	end
	return n
end

local function ambientActive(): boolean
	for _, e in pairs(active) do
		if e.placement == "Ambient" then
			return true
		end
	end
	return false
end

local function hasEscalatingTell(anomaly: Types.Anomaly): boolean
	for _, tell in ipairs(anomaly.tells) do
		if tell.escalates then
			return true
		end
	end
	return false
end

local function resolveEnding(id: string): ()
	if endingResolved then
		return
	end
	endingResolved = id
end

local function resolveActive(uid: string): ()
	local entry = active[uid]
	if not entry then
		return
	end
	entry.resolved = true
	local ok, err = pcall(entry.anomaly.cleanup, entry.context)
	if not ok then
		warn(("[ShiftService] cleanup error for '%s': %s"):format(uid, tostring(err)))
	end
	if entry.anchor then
		entry.anchor:SetAttribute("EscalationLevel", 0)
	end
	active[uid] = nil
end

local function activate(anomaly: Types.Anomaly, placement: string, customer: Instance?): ActiveAnomaly
	uidCounter += 1
	local uid = string.format("%s#%d", anomaly.id, uidCounter)
	local room = currentRoom
	local now = os.clock()
	local anchor: Instance?
	if placement == "Counter" then
		anchor = customer
	else
		anchor = (room and room:FindFirstChild("Flag")) or room
	end
	local ctx: Types.AnomalyContext = {
		room = room,
		customer = customer,
		seed = math.random(1, 2147483647),
		shiftId = (currentShift :: Types.Shift).id,
	}
	local entry: ActiveAnomaly = {
		uid = uid,
		anomaly = anomaly,
		placement = placement,
		context = ctx,
		anchor = anchor,
		customer = customer,
		spawnedAt = now,
		expiresAt = if anomaly.timeoutSeconds then now + anomaly.timeoutSeconds else nil,
		resolved = false,
		escLevel = 0,
		nextEscAt = now + ESC_INTERVAL,
		escalating = hasEscalatingTell(anomaly),
	}
	active[uid] = entry

	local ok, err = pcall(anomaly.setup, ctx)
	if not ok then
		warn(("[ShiftService] setup error for '%s': %s"):format(uid, tostring(err)))
	end

	print(("[SPAWN] %s \"%s\" (%s) expected=%s"):format(uid, anomaly.name, placement, tostring(RuleCardService.expectedVerb(anomaly.id))))
	for _, tell in ipairs(anomaly.tells) do
		print(("        tell(%s, subtlety %d%s): %s"):format(tell.channel, tell.subtlety, if tell.escalates then ", escalates" else "", tell.cue))
	end
	if countActive() >= 2 then
		print("[CONCURRENCY] 2 anomalies live at once -- TRIAGE NOW (break off one, pay the cost)")
	end
	return entry
end

local function snapshot(clockRemaining: number)
	local counters = {}
	local ambients = {}
	for uid, e in pairs(active) do
		local item = {
			uid = uid,
			anomalyId = e.anomaly.id,
			name = e.anomaly.name,
			placement = e.placement,
			escalation = e.escLevel,
			expiresIn = if e.expiresAt then math.max(0, e.expiresAt - os.clock()) else -1,
		}
		if e.placement == "Counter" then
			table.insert(counters, item)
		else
			table.insert(ambients, item)
		end
	end
	local list = {}
	for _, x in ipairs(counters) do
		table.insert(list, x)
	end
	for _, x in ipairs(ambients) do
		table.insert(list, x)
	end
	return {
		active = list,
		Electricity = ResourceService.get("Electricity"),
		Patience = ResourceService.get("Patience"),
		sanity = SanityService.get(),
		strikes = SanityService.getStrikes(),
		clock = clockRemaining,
		locked = os.clock() < lockedUntil,
	}
end

-- SERVER-AUTHORITATIVE verb resolution. Input is only (uid, verb) intent; the
-- outcome is computed here. A wrong or spoofed verb is just handled as wrong.
function ShiftService.submitVerb(uid: string, verb: string): ()
	if not running then
		return
	end
	local now = os.clock()
	if now < lockedUntil then
		print(("[LOCK] hands full (%.1fs) -- verb '%s' on %s rejected"):format(lockedUntil - now, verb, uid))
		return
	end
	local entry = active[uid]
	if not entry or entry.resolved then
		warn(("[ShiftService] verb '%s' ignored -- '%s' is not active"):format(verb, uid))
		return
	end
	local anomaly = entry.anomaly

	-- Acting costs: lockout seconds (blocks the OTHER anomaly) + resource spend.
	local cost = anomaly.verbCost
	local lock = if cost and cost.seconds then cost.seconds else 0
	lockedUntil = now + lock
	if cost then
		if cost.electricity then
			ResourceService.spend("Electricity", cost.electricity)
		end
		if cost.patience then
			ResourceService.spend("Patience", cost.patience)
		end
	end

	local expected = RuleCardService.expectedVerb(anomaly.id)
	if verb == expected then
		local oc = anomaly.onCorrectVerb
		SanityService.apply(oc.sanity)
		print(("[OK] %s correct '%s' (+%d, sanity %+d) lock=%.1fs -- sanity=%d"):format(uid, verb, oc.reward, oc.sanity, lock, SanityService.get()))
	else
		local ow = anomaly.onWrongVerb
		SanityService.apply(ow.sanity)
		if ow.strike then
			SanityService.addStrike()
		end
		print(("[X] %s wrong '%s' (expected '%s') sanity %+d strike=%s -- sanity=%d strikes=%d"):format(uid, verb, tostring(expected), ow.sanity, tostring(ow.strike), SanityService.get(), SanityService.getStrikes()))
		if ow.triggersEnding then
			resolveEnding(ow.triggersEnding)
		end
	end

	resolveActive(uid)
end

local function ensureConnections(): ()
	if connected then
		return
	end
	connected = true
	local submit = ensureRemotes()
	submit.OnServerEvent:Connect(function(_player, uid, verb)
		if type(uid) ~= "string" or type(verb) ~= "string" then
			return
		end
		ShiftService.submitVerb(uid, verb)
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
	currentShift = shift
	local room = ensureRoom(shift.map)
	currentRoom = room

	ResourceService.init(shift.resources)
	SanityService.init(shift.parSanity)
	ensureConnections()

	active = {}
	uidCounter = 0
	lockedUntil = 0
	endingResolved = nil
	currentCustomer = nil
	currentCustomerUid = nil
	running = true

	SanityService.onFail(function(reason: string)
		print(("[ShiftService] fail: %s"):format(reason))
		if reason == "strikes" then
			resolveEnding(shift.endings.bankrupt)
		else
			resolveEnding(shift.endings.taken)
		end
	end)
	ResourceService.onDepleted(function(meter: Types.ResourceMeter)
		print(("[ShiftService] meter depleted: %s -> %s"):format(meter.id, meter.onDepleted))
		if meter.onDepleted == "ending" then
			resolveEnding(meter.onDepletedEnding or shift.endings.taken)
		elseif meter.onDepleted == "strike" then
			SanityService.addStrike()
		elseif meter.onDepleted == "sanity" then
			SanityService.apply(-20)
		end
	end)

	local picks = AnomalyService.pickForShift(shift)
	local counterQ: { Types.Anomaly } = {}
	local ambientQ: { Types.Anomaly } = {}
	for _, a in ipairs(picks) do
		if a.placement == "Counter" then
			table.insert(counterQ, a)
		else
			table.insert(ambientQ, a)
		end
	end
	print(("[ShiftService] >> START '%s' -- %ds clock, %d Counter + %d Ambient queued, concurrentMax=%d"):format(shift.displayName, shift.durationSeconds, #counterQ, #ambientQ, shift.concurrentMax))

	local _, broadcast = ensureRemotes()
	broadcast:FireAllClients("ShiftStarted", { shiftId = shift.id, rules = RuleCardService.getRules() })

	local startClock = os.clock()
	local endsAt = startClock + shift.durationSeconds

	local function gap(): number
		local progress = math.clamp((os.clock() - startClock) / shift.durationSeconds, 0, 1)
		local tighten = 1 - 0.5 * progress
		local span = shift.spawnGapSeconds.max - shift.spawnGapSeconds.min
		return (shift.spawnGapSeconds.min + math.random() * span) * tighten
	end

	local ci = 1
	local ai = 1
	local customersArrived = 0
	local customersServed = 0
	local nextCustomerAt = startClock + 3
	local nextAmbientAt = startClock + 8
	local customerIsPlain = false
	local plainServeUntil = 0
	local lastTick = startClock
	local lastBroadcast = 0

	while running do
		local now = os.clock()
		local dt = now - lastTick
		lastTick = now

		ResourceService.tick(dt)

		-- escalation (real: level up, render via attribute, resource bite)
		for uid, e in pairs(active) do
			if e.escalating and not e.resolved and e.escLevel < ESC_MAX and now >= e.nextEscAt then
				e.escLevel += 1
				e.nextEscAt = now + ESC_INTERVAL
				if e.anchor then
					e.anchor:SetAttribute("EscalationLevel", e.escLevel)
				end
				if e.placement == "Ambient" then
					ResourceService.spend("Electricity", 3)
				else
					ResourceService.spend("Patience", 5)
				end
				if e.escLevel >= ESC_MAX then
					SanityService.apply(-5)
				end
				print(("[ESC] %s -> level %d (it is getting closer)"):format(uid, e.escLevel))
			end
		end

		-- timeouts
		for uid, e in pairs(active) do
			if not e.resolved and e.expiresAt and now >= e.expiresAt then
				local ot = e.anomaly.onTimeout
				if ot then
					SanityService.apply(ot.sanity)
					if ot.strike then
						SanityService.addStrike()
					end
					if ot.triggersEnding then
						resolveEnding(ot.triggersEnding)
					end
				end
				print(("[TIMEOUT] %s"):format(uid))
				resolveActive(uid)
			end
		end

		-- customer arrival (the leash)
		if currentCustomer == nil and now >= nextCustomerAt and customersArrived < shift.customerCount then
			currentCustomer = spawnCustomer(room)
			customersArrived += 1
			if ci <= #counterQ and countActive() < shift.concurrentMax then
				local a = counterQ[ci]
				ci += 1
				local entry = activate(a, "Counter", currentCustomer)
				currentCustomerUid = entry.uid
				customerIsPlain = false
				-- GDD guardrail: spawn the Ambient tell WHILE the player is mid-Counter
				if ai <= #ambientQ then
					local window = math.min(AMBIENT_INTRUDE_MAX, (a.timeoutSeconds or 12) - 2)
					nextAmbientAt = now + math.random(AMBIENT_INTRUDE_MIN, math.max(AMBIENT_INTRUDE_MIN, window))
				end
			else
				customerIsPlain = true
				plainServeUntil = now + SERVE_SECONDS
				currentCustomerUid = nil
			end
		end

		-- customer departure
		if currentCustomer then
			if customerIsPlain then
				if now >= plainServeUntil then
					currentCustomer:Destroy()
					currentCustomer = nil
					customersServed += 1
					nextCustomerAt = now + CUSTOMER_GAP
				end
			elseif currentCustomerUid == nil or active[currentCustomerUid] == nil then
				-- the cursed customer's Counter anomaly resolved (handled or timeout)
				currentCustomer:Destroy()
				currentCustomer = nil
				currentCustomerUid = nil
				customersServed += 1
				nextCustomerAt = now + CUSTOMER_GAP
			end
		end

		-- ambient scheduler (base cadence, but intrudes during Counter windows)
		if ai <= #ambientQ and now >= nextAmbientAt and countActive() < shift.concurrentMax and not ambientActive() then
			local a = ambientQ[ai]
			ai += 1
			activate(a, "Ambient", nil)
			nextAmbientAt = now + gap()
		end

		-- broadcast state to clients (render + intent targeting)
		if now - lastBroadcast >= 0.5 then
			lastBroadcast = now
			broadcast:FireAllClients("State", snapshot(math.max(0, endsAt - now)))
		end

		if endingResolved then
			break
		end
		if now >= endsAt then
			resolveEnding(shift.endings.good)
			break
		end

		task.wait(0.2)
	end

	for uid in pairs(active) do
		resolveActive(uid)
	end
	if currentCustomer then
		currentCustomer:Destroy()
		currentCustomer = nil
	end
	running = false

	local ending = endingResolved or shift.endings.good
	print(("[ShiftService] == SHIFT OVER -- ending='%s' | sanity=%d strikes=%d Electricity=%.0f Patience=%.0f served=%d"):format(ending, SanityService.get(), SanityService.getStrikes(), ResourceService.get("Electricity"), ResourceService.get("Patience"), customersServed))
	broadcast:FireAllClients("ShiftEnded", { ending = ending })
	return ending
end

function ShiftService.isRunning(): boolean
	return running
end

return ShiftService
