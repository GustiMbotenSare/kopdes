--!strict
-- src/server/Bootstrap.server.luau
-- Server entry point (Rojo compiles *.server.luau into a Script). Boots the
-- anomaly registry and runs the M1 Tambak slice when the first player joins.
local Players = game:GetService("Players")

local AnomalyService = require(script.Parent.AnomalyService)
local ShiftService = require(script.Parent.ShiftService)

AnomalyService.init()
print("[Bootstrap] KOPDES server online. Waiting for a player to run the Tambak slice...")

local started = false
local function beginSlice(player: Player)
	if started then
		return
	end
	started = true
	task.wait(2) -- let the client + room settle
	print(("[Bootstrap] >> Running shift01_tambak for %s"):format(player.Name))
	local ending = ShiftService.start("shift01_tambak")
	print(("[Bootstrap] == shift01_tambak resolved: %s"):format(ending))
end

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(beginSlice, p)
end
Players.PlayerAdded:Connect(beginSlice)
