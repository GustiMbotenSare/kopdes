--!nonstrict
-- src/client/KopdesHud.client.luau
-- ENG-7/8 (slice-scoped): the real on-screen HUD. Presentation + verb INTENT
-- only -- the server (ShiftService) stays authoritative. Consumes the existing
-- ReplicatedStorage.Net.ShiftEvent contract (State / ShiftStarted / ShiftEnded /
-- VerbResult) and sends intent via Net.SubmitVerb:FireServer(uid, verb).
-- Replaces the throwaway SliceHarness (its flag/customer world cues are folded
-- into renderWorld below).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local net = ReplicatedStorage:WaitForChild("Net")
local submitVerb = net:WaitForChild("SubmitVerb")
local shiftEvent = net:WaitForChild("ShiftEvent")

-- ---- palette ----------------------------------------------------------------
local COL_PANEL = Color3.fromRGB(22, 22, 30)
local COL_SLOT = Color3.fromRGB(28, 28, 40)
local COL_TEXT = Color3.fromRGB(235, 235, 240)
local COL_MUTE = Color3.fromRGB(150, 150, 162)
local COL_RED = Color3.fromRGB(205, 45, 45)
local COL_GREEN = Color3.fromRGB(60, 200, 95)
local COL_ORANGE = Color3.fromRGB(230, 150, 40)
local COL_GREY = Color3.fromRGB(120, 120, 132)
local COL_ELEC = Color3.fromRGB(95, 170, 255)
local COL_PATI = Color3.fromRGB(95, 210, 120)
local COL_TIMER = Color3.fromRGB(220, 200, 90)

-- ---- tiny builders ----------------------------------------------------------
local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
end
local function stroke(inst, col, t)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.fromRGB(0, 0, 0)
	s.Transparency = t or 0.4
	s.Thickness = 1
	s.Parent = inst
end
local function newFrame(parent, size, pos, color)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos or UDim2.fromOffset(0, 0)
	f.BackgroundColor3 = color or COL_PANEL
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end
local function newLabel(parent, text, size, pos, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos or UDim2.fromOffset(0, 0)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = opts.font or Enum.Font.GothamMedium
	l.TextSize = opts.textSize or 14
	l.TextColor3 = opts.color or COL_TEXT
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end
local function newButton(parent, text, size, pos, color)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or Color3.fromRGB(45, 45, 60)
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = COL_TEXT
	corner(b, 6)
	b.Parent = parent
	return b
end

-- ---- screen -----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "KopdesHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = playerGui

-- top bar
local topBar = newFrame(gui, UDim2.fromOffset(470, 46), UDim2.new(0.5, 0, 0, 10), COL_PANEL)
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.BackgroundTransparency = 0.08
corner(topBar, 10)
stroke(topBar, COL_RED, 0.45)
local titleLabel = newLabel(topBar, "KOPDES", UDim2.new(0, 250, 1, 0), UDim2.fromOffset(14, 0), { font = Enum.Font.GothamBold, textSize = 16 })
local clockLabel = newLabel(topBar, "0:00", UDim2.fromOffset(84, 30), UDim2.new(1, -108, 0.5, 0), { align = Enum.TextXAlignment.Right, font = Enum.Font.GothamBold, textSize = 18 })
clockLabel.AnchorPoint = Vector2.new(1, 0.5)
local rulesBtn = newButton(topBar, "Rules", UDim2.fromOffset(80, 30), UDim2.new(1, -10, 0.5, 0), Color3.fromRGB(70, 45, 45))
rulesBtn.AnchorPoint = Vector2.new(1, 0.5)

-- collapsible rule card
local rulePanel = newFrame(gui, UDim2.fromOffset(470, 0), UDim2.new(0.5, 0, 0, 60), COL_PANEL)
rulePanel.AnchorPoint = Vector2.new(0.5, 0)
rulePanel.BackgroundTransparency = 0.06
rulePanel.AutomaticSize = Enum.AutomaticSize.Y
rulePanel.Visible = false
corner(rulePanel, 10)
stroke(rulePanel, COL_RED, 0.55)
do
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rulePanel
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 12)
	p.PaddingRight = UDim.new(0, 12)
	p.Parent = rulePanel
end
rulesBtn.MouseButton1Click:Connect(function()
	rulePanel.Visible = not rulePanel.Visible
end)

-- meters panel
local meters = newFrame(gui, UDim2.fromOffset(250, 150), UDim2.new(0, 12, 0, 64), COL_PANEL)
meters.BackgroundTransparency = 0.1
corner(meters, 10)
stroke(meters, Color3.fromRGB(0, 0, 0), 0.6)
local function buildMeter(yLabel, name, barColor)
	newLabel(meters, name, UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, yLabel), { textSize = 12, color = COL_MUTE })
	local valLbl = newLabel(meters, "100", UDim2.new(0, 60, 0, 16), UDim2.new(1, -72, 0, yLabel), { align = Enum.TextXAlignment.Right, textSize = 12 })
	local bg = newFrame(meters, UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, yLabel + 18), Color3.fromRGB(14, 14, 20))
	corner(bg, 7)
	local fill = newFrame(bg, UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0), barColor)
	corner(fill, 7)
	return { fill = fill, val = valLbl, color = barColor }
end
local elecMeter = buildMeter(8, "ELECTRICITY", COL_ELEC)
local patiMeter = buildMeter(52, "PATIENCE", COL_PATI)
local sanityLabel = newLabel(meters, "Sanity  100", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 96), { textSize = 14, font = Enum.Font.GothamBold })
local strikesLabel = newLabel(meters, "Strikes  ", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 118), { textSize = 14, font = Enum.Font.GothamBold })
local function updateMeter(m, value)
	local frac = math.clamp(value / 100, 0, 1)
	m.fill.Size = UDim2.new(frac, 0, 1, 0)
	m.fill.BackgroundColor3 = if frac < 0.25 then COL_RED else m.color
	m.val.Text = string.format("%d", math.floor(value + 0.5))
end

-- anomaly slots
local slotsWrap = newFrame(gui, UDim2.fromOffset(660, 160), UDim2.new(0.5, 0, 1, -14), nil)
slotsWrap.AnchorPoint = Vector2.new(0.5, 1)
slotsWrap.BackgroundTransparency = 1

local slots = {}
local locked = false

local function keyFire(placement, verb)
	local slot = slots[placement]
	if slot and slot.uid then
		submitVerb:FireServer(slot.uid, verb)
	end
end
local function buttonFire(placement, verb)
	if locked then
		return
	end
	keyFire(placement, verb)
end

local function buildSlot(placement, x)
	local accent = if placement == "Counter" then COL_ORANGE else COL_RED
	local f = newFrame(slotsWrap, UDim2.fromOffset(320, 160), UDim2.fromOffset(x, 0), COL_SLOT)
	f.BackgroundTransparency = 0.05
	corner(f, 12)
	stroke(f, accent, 0.5)
	newLabel(f, string.upper(placement), UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 10), { font = Enum.Font.GothamBold, textSize = 13, color = accent })
	local nameLbl = newLabel(f, "— clear —", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 30), { font = Enum.Font.GothamBold, textSize = 16, color = COL_MUTE })
	local escLbl = newLabel(f, "", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 56), { textSize = 13, color = COL_ORANGE })
	local tbg = newFrame(f, UDim2.new(1, -24, 0, 10), UDim2.fromOffset(12, 78), Color3.fromRGB(14, 14, 20))
	corner(tbg, 5)
	local tfill = newFrame(tbg, UDim2.new(0, 0, 1, 0), UDim2.fromOffset(0, 0), COL_TIMER)
	corner(tfill, 5)

	local buttons = {}
	local raKey = if placement == "Counter" then "1" else "2"
	local ra = newButton(f, string.format("RefuseAlarm (%s)", raKey), UDim2.new(0, 150, 0, 30), UDim2.fromOffset(12, 118), COL_RED)
	ra.MouseButton1Click:Connect(function()
		buttonFire(placement, "RefuseAlarm")
	end)
	table.insert(buttons, ra)
	if placement == "Counter" then
		local sv = newButton(f, "Serve (Q)", UDim2.new(0, 130, 0, 30), UDim2.fromOffset(174, 118), Color3.fromRGB(55, 90, 55))
		sv.MouseButton1Click:Connect(function()
			buttonFire(placement, "Serve")
		end)
		table.insert(buttons, sv)
	end

	slots[placement] = { frame = f, name = nameLbl, esc = escLbl, timer = tfill, buttons = buttons, uid = nil, denom = nil, default = COL_SLOT }
end
buildSlot("Counter", 0)
buildSlot("Ambient", 340)

local function setButtonsEnabled(enabled)
	for _, slot in pairs(slots) do
		for _, b in ipairs(slot.buttons) do
			b.Active = enabled
			b.AutoButtonColor = enabled
			b.TextTransparency = if enabled then 0 else 0.45
			b.BackgroundTransparency = if enabled then 0 else 0.55
		end
	end
end

-- lockout + toast + end banner
local lockLabel = newLabel(gui, "HANDS FULL", UDim2.fromOffset(220, 26), UDim2.new(0.5, 0, 1, -182), { align = Enum.TextXAlignment.Center, font = Enum.Font.GothamBlack, textSize = 16, color = COL_ORANGE })
lockLabel.AnchorPoint = Vector2.new(0.5, 1)
lockLabel.ZIndex = 20
lockLabel.Visible = false

local toast = newLabel(gui, "", UDim2.fromOffset(460, 28), UDim2.new(0.5, 0, 1, -208), { align = Enum.TextXAlignment.Center, font = Enum.Font.GothamBold, textSize = 16 })
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.ZIndex = 20
toast.Visible = false
local toastToken = 0
local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or COL_TEXT
	toast.Visible = true
	toastToken += 1
	local myToken = toastToken
	task.delay(1.6, function()
		if myToken == toastToken then
			toast.Visible = false
		end
	end)
end

local endBanner = newFrame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(0, 0, 0))
endBanner.BackgroundTransparency = 0.35
endBanner.ZIndex = 100
endBanner.Visible = false
local endLabel = newLabel(endBanner, "", UDim2.fromScale(0.82, 0.4), UDim2.new(0.5, 0, 0.5, 0), { align = Enum.TextXAlignment.Center, font = Enum.Font.GothamBlack, textSize = 40 })
endLabel.AnchorPoint = Vector2.new(0.5, 0.5)
endLabel.TextWrapped = true
endLabel.ZIndex = 101

-- ---- world cues (folded from SliceHarness) ---------------------------------
local function renderWorld()
	local room = Workspace:FindFirstChild("Tambak")
	if not room then
		return
	end
	local flag = room:FindFirstChild("Flag")
	if flag and flag:IsA("BasePart") then
		local inverted = flag:GetAttribute("Inverted")
		local esc = flag:GetAttribute("EscalationLevel") or 0
		flag.Color = if inverted then Color3.fromRGB(255, math.max(0, 120 - 40 * esc), 60) else Color3.fromRGB(230, 230, 230)
	end
	local customer = room:FindFirstChild("Customer")
	if customer and customer:IsA("BasePart") then
		customer.Color = if customer:GetAttribute("CursedPayment") then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(200, 200, 200)
	end
end

-- ---- render ----------------------------------------------------------------
local lastPayload = nil
local lastSlotForUid = {}

local function fmtClock(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
local function pips(n, total)
	local s = ""
	for i = 1, total do
		s = s .. (if i <= n then "\u{25CF}" else "\u{25CB}")
	end
	return s
end
local function clearSlot(slot)
	slot.uid = nil
	slot.denom = nil
	slot.name.Text = "— clear —"
	slot.name.TextColor3 = COL_MUTE
	slot.esc.Text = ""
	slot.timer.Size = UDim2.new(0, 0, 1, 0)
	slot.frame.BackgroundColor3 = slot.default
end

local function renderState(p)
	lastPayload = p
	clockLabel.Text = fmtClock(p.clock or 0)
	updateMeter(elecMeter, p.Electricity or 0)
	updateMeter(patiMeter, p.Patience or 0)
	sanityLabel.Text = string.format("Sanity  %d", p.sanity or 0)
	strikesLabel.Text = "Strikes  " .. pips(p.strikes or 0, 3)

	locked = p.locked == true
	lockLabel.Visible = locked
	setButtonsEnabled(not locked)

	local seen = { Counter = false, Ambient = false }
	local newSlotForUid = {}
	for _, item in ipairs(p.active or {}) do
		local slot = slots[item.placement]
		if slot then
			seen[item.placement] = true
			if slot.uid ~= item.uid then
				slot.uid = item.uid
				slot.denom = math.max(item.expiresIn or 0, 0.001)
			end
			newSlotForUid[item.uid] = item.placement
			slot.frame.BackgroundColor3 = slot.default
			slot.name.Text = item.name or item.anomalyId or "?"
			slot.name.TextColor3 = COL_TEXT
			slot.esc.Text = string.format("ESC %d/3   %s", item.escalation or 0, pips(item.escalation or 0, 3))
			local frac = 1
			if (item.expiresIn or -1) >= 0 and slot.denom and slot.denom > 0 then
				frac = math.clamp(item.expiresIn / slot.denom, 0, 1)
			end
			slot.timer.Size = UDim2.new(frac, 0, 1, 0)
			slot.timer.BackgroundColor3 = if frac < 0.34 then COL_RED else COL_TIMER
		end
	end
	if not seen.Counter then
		clearSlot(slots.Counter)
	end
	if not seen.Ambient then
		clearSlot(slots.Ambient)
	end
	lastSlotForUid = newSlotForUid
	renderWorld()
end

local function flashSlot(placement, color)
	local slot = slots[placement]
	if not slot then
		return
	end
	slot.frame.BackgroundColor3 = color
	task.delay(0.5, function()
		if lastPayload then
			renderState(lastPayload)
		else
			slot.frame.BackgroundColor3 = slot.default
		end
	end)
end

local function onVerbResult(res)
	local placement = lastSlotForUid[res.uid]
	local color, text
	if res.result == "correct" then
		color, text = COL_GREEN, "\u{2713} Alarm raised"
	elseif res.result == "wrong" then
		color, text = COL_RED, "\u{2717} Wrong — expected RefuseAlarm"
	elseif res.result == "locked" then
		color, text = COL_GREY, "Hands full — wait"
	elseif res.result == "timeout" then
		color, text = COL_ORANGE, "\u{231B} Timed out"
	else
		color, text = COL_GREY, tostring(res.result)
	end
	if placement then
		flashSlot(placement, color)
	end
	showToast(text, color)
end

local function prettyShift(id)
	if not id then
		return "KOPDES"
	end
	return "KOPDES — " .. (string.gsub(id, "_", " "))
end
local function onShiftStarted(p)
	titleLabel.Text = prettyShift(p and p.shiftId)
	for _, ch in ipairs(rulePanel:GetChildren()) do
		if ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end
	if p and p.rules then
		for i, r in ipairs(p.rules) do
			local lbl = newLabel(rulePanel, string.format("%s.  %s", tostring(r.id), tostring(r.text)), UDim2.new(1, -24, 0, 0), nil, { textSize = 13 })
			lbl.AutomaticSize = Enum.AutomaticSize.Y
			lbl.TextWrapped = true
			lbl.LayoutOrder = i
		end
	end
	endBanner.Visible = false
end

local END_LABELS = {
	koperasi_sehat = { "KOPERASI SEHAT\nyou survived the night", COL_GREEN },
	diambil = { "DIAMBIL\nyou were taken", COL_RED },
	dana_habis = { "DANA HABIS\nbankrupt", COL_ORANGE },
}
local function onShiftEnded(p)
	local id = p and p.ending
	local m = END_LABELS[id] or { tostring(id), COL_TEXT }
	endLabel.Text = m[1]
	endLabel.TextColor3 = m[2]
	endBanner.Visible = true
	locked = false
	lockLabel.Visible = false
end

-- ---- wiring ----------------------------------------------------------------
shiftEvent.OnClientEvent:Connect(function(kind, payload)
	if kind == "State" then
		renderState(payload)
	elseif kind == "ShiftStarted" then
		onShiftStarted(payload)
	elseif kind == "ShiftEnded" then
		onShiftEnded(payload)
	elseif kind == "VerbResult" then
		onVerbResult(payload)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.One then
		keyFire("Counter", "RefuseAlarm")
	elseif kc == Enum.KeyCode.Two then
		keyFire("Ambient", "RefuseAlarm")
	elseif kc == Enum.KeyCode.Q then
		keyFire("Counter", "Serve")
	elseif kc == Enum.KeyCode.E then
		keyFire("Ambient", "Serve")
	end
end)
