--!strict
-- src/shared/Types.luau
-- Shared type CONTRACT for KOPDES: Merah Putih Anomalies.
-- Master = Notion Living Spec + Engineer Kickoff. Keep this file in sync.
-- Design north star: triage under drain, not a reading simulator.

export type Domain = "Customer" | "Product" | "Environment"

export type Verb =
	"Serve" | "RefuseAlarm" | "DontLook" | "Shutter"
	| "Restock" | "CallKades" | "CloseSign"

-- HOW the player perceives an anomaly. Every anomaly needs >=1 sensory tell,
-- so detection is "notice the world", not "cross-reference a text list".
export type TellChannel = "Visual" | "Audio" | "Environmental" | "CCTV" | "Document"

export type Tell = {
	channel: TellChannel,
	cue: string, -- designer/QA description of the perceivable signal
	assetId: string?, -- sound / decal / particle / animation to play
	subtlety: number, -- 1 = obvious across the room .. 5 = needs Third-Eye
	escalates: boolean?, -- does the cue intensify the longer it's ignored?
}

-- What a verb COSTS to perform. Makes handling a triage decision, not a free click.
export type VerbCost = {
	seconds: number?, -- you're locked out of other actions this long
	electricity: number?, -- e.g. CCTV / DontLook / lights burn power
	patience: number?, -- slow handling drains the queue's patience
	cash: number?, -- e.g. CallKades costs money
}

export type Outcome = {
	sanity: number, -- negative = damage
	strike: boolean,
	triggersEnding: string?, -- optional instant ending id
}

-- Passed to setup/cleanup at runtime (server-authoritative).
export type AnomalyContext = {
	room: any, -- model root for the active shift room
	customer: any?, -- the active customer model, if this is a Counter anomaly
	seed: number, -- deterministic RNG seed for this activation
	shiftId: string,
}

export type Anomaly = {
	id: string,
	name: string,
	domain: Domain,
	placement: "Counter" | "Ambient", -- foreground (desk) vs background (concurrent)
	weight: number,
	minShift: number,
	tells: { Tell }, -- REQUIRED, >=1
	isRedHerring: boolean?, -- looks wrong but is fine; punishes over-reacting
	correctVerb: Verb,
	verbCost: VerbCost?,
	onWrongVerb: Outcome,
	onCorrectVerb: { sanity: number, reward: number },
	timeoutSeconds: number?,
	onTimeout: Outcome?,
	tags: { string },
	setup: (context: AnomalyContext) -> (),
	cleanup: (context: AnomalyContext) -> (),
}

export type Rule = {
	id: string,
	text: string, -- shown verbatim on the in-world rule card
	overrideVerb: { anomalyId: string, verb: Verb }?,
}

export type ResourceId = "Electricity" | "Patience" | "Stock" | "Cash"

export type ResourceMeter = {
	id: ResourceId,
	max: number,
	start: number,
	drainPerSec: number,
	onDepleted: "sanity" | "strike" | "ending",
	onDepletedEnding: string?, -- required if onDepleted == "ending"
}

export type Shift = {
	id: string,
	map: string,
	displayName: string,
	rules: { Rule },
	resources: { ResourceMeter },
	anomalyPool: { string },
	anomalyCount: number,
	concurrentMax: number, -- how many can be live AT ONCE (the tension dial)
	spawnGapSeconds: { min: number, max: number },
	durationSeconds: number, -- hard shift length; the clock is pressure
	customerCount: number,
	parSanity: number,
	endings: { good: string, bankrupt: string, taken: string },
}

return {}
