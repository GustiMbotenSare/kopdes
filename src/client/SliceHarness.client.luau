--!nonstrict
-- src/client/SliceHarness.client.luau
-- THROWAWAY slice harness -- NOT the real HUD/renderer (those are ENG-7/8).
-- Its only job: let a human perform the acceptance test in Studio and record a
-- clip. It renders server-owned tells (reads attributes + broadcast state) and
-- sends verb INTENT to the server. The server remains the sole authority.
--
-- Controls:
--   [1] RefuseAlarm the Counter anomaly (slot 1)
--   [2] RefuseAlarm the Ambient anomaly (slot 2)
--   [Q] send a WRONG verb (Serve) to slot 1  -- to test onWrongVerb
--   [E] send a WRONG verb (Serve) to slot 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local net = ReplicatedStorage:WaitForChild("Net")
local submit = net:WaitForChild("SubmitVerb")
local broadcast = net:WaitForChild("ShiftEvent")

local latest = { active = {} }

local function renderWorld()
	local room = Workspace:FindFirstChild("Tambak")
	if not room then
		return
	end
	local flag = room:FindFirstChild("Flag")
	if flag and flag:IsA("BasePart") then
		local inverted = flag:GetAttribute("Inverted")
		local esc = flag:GetAttribute("EscalationLevel") or 0
		if inverted then
			flag.Color = Color3.fromRGB(255, math.max(0, 120 - 40 * esc), 60)
		else
			flag.Color = Color3.fromRGB(230, 230, 230)
		end
	end
	local customer = room:FindFirstChild("Customer")
	if customer and customer:IsA("BasePart") then
		local cursed = customer:GetAttribute("CursedPayment")
		customer.Color = if cursed then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(200, 200, 200)
	end
end

local function fire(slot, verb)
	local a = latest.active[slot]
	if a then
		submit:FireServer(a.uid, verb)
		print(("[intent] %s -> %s (%s)"):format(verb, a.uid, a.placement))
	else
		print(("[intent] no anomaly in slot %d"):format(slot))
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.One then
		fire(1, "RefuseAlarm")
	elseif kc == Enum.KeyCode.Two then
		fire(2, "RefuseAlarm")
	elseif kc == Enum.KeyCode.Q then
		fire(1, "Serve")
	elseif kc == Enum.KeyCode.E then
		fire(2, "Serve")
	end
end)

broadcast.OnClientEvent:Connect(function(kind, payload)
	if kind == "State" then
		latest = payload
		local header = string.format(
			"[%.0fs] Electricity=%.0f Patience=%.0f Sanity=%d Strikes=%d %s",
			payload.clock or 0,
			payload.Electricity or 0,
			payload.Patience or 0,
			payload.sanity or 0,
			payload.strikes or 0,
			if payload.locked then "[HANDS FULL]" else ""
		)
		print(header)
		for i, a in ipairs(payload.active) do
			print(string.format(
				"   [%d] %s (%s) esc=%d exp=%.0fs  -> press %d = RefuseAlarm",
				i, a.name, a.placement, a.escalation or 0, a.expiresIn or -1, i
			))
		end
		renderWorld()
	elseif kind == "ShiftStarted" then
		print("[SLICE] Shift started. Controls: 1=RefuseAlarm Counter, 2=RefuseAlarm Ambient, Q/E=wrong verb.")
		if payload and payload.rules then
			for _, r in ipairs(payload.rules) do
				print(("   RULE %s: %s"):format(tostring(r.id), tostring(r.text)))
			end
		end
	elseif kind == "ShiftEnded" then
		print(("[SLICE] SHIFT ENDED -> %s"):format(tostring(payload and payload.ending)))
	end
end)
