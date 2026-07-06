--!strict
-- src/server/SanityService.luau
-- ENG-6 (minimal -- required by ENG-5): sanity meter + rule strikes. On sanity
-- death or strike-out, notifies the registered fail handler with a reason so
-- ShiftService can resolve the matching ending.
local SanityService = {}

-- CONTRACT NOTE (flagged to Brain): max strikes isn't in Types.Shift yet.
-- Using 3 as a tunable default; consider adding Shift.maxStrikes to the spec.
local MAX_STRIKES = 3

local sanity = 100
local maxSanity = 100
local strikes = 0
local failed = false
local failHandler: ((reason: string) -> ())? = nil

function SanityService.init(parSanity: number): ()
	maxSanity = parSanity
	sanity = parSanity
	strikes = 0
	failed = false
end

function SanityService.onFail(handler: (reason: string) -> ()): ()
	failHandler = handler
end

function SanityService.get(): number
	return sanity
end

function SanityService.getStrikes(): number
	return strikes
end

function SanityService.apply(delta: number): ()
	if failed then
		return
	end
	sanity = math.clamp(sanity + delta, 0, maxSanity)
	if sanity <= 0 then
		failed = true
		if failHandler then
			failHandler("sanity")
		end
	end
end

function SanityService.addStrike(): ()
	if failed then
		return
	end
	strikes += 1
	if strikes >= MAX_STRIKES then
		failed = true
		if failHandler then
			failHandler("strikes")
		end
	end
end

return SanityService
