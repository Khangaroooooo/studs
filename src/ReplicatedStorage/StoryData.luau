-- StoryData: every word of the "Seven Ways Home" story mode, in one module.
-- Shared by StorySystem (server: decides WHEN a beat fires, once per save)
-- and StoryUI / StudDexUI (client: decides HOW it looks).
--
-- The story is fully ambient: margin-notes, asides, and dex sub-text.
-- It never gates the catch loop. Casual mode hides all of it; the game is
-- complete and identical without it. Voice rules: warm/witty/kind, 1-2
-- sentences per note, mundane on first read, devastating in hindsight.
--
-- Canon: the town was OUTGROWN — everyone grew up and left. The seven
-- regions are one valley remembered under seven moods; the studs are the
-- townspeople, remembered; catching = remembering; you are the resident
-- who left and forgot. Nobody is dead, nothing is evil, both endings are
-- warm. Kept whispered — attentive players assemble it, others just catch.

local StoryData = {}

-- ─── SPEAKERS ──────────────────────────────────────────────────────────
-- "Registry" notes render as handwriting in the margins of your dex.
-- "Merle" is the caretaker who never left (and knew you when).

StoryData.SPEAKER_REGISTRY = "the Registry"
StoryData.SPEAKER_MERLE = "Merle"

-- ─── CHAPTERS (one per world — the seven weathers) ─────────────────────
-- intro fires once per save on first entry to the world (Studville: at the
-- start of a new game). Order = the emotional arc of a town emptying out.

StoryData.Chapters = {
	Studville = {
		chapter = 1,
		title = "The Last Good Summer",
		intro = {
			"Studville. The green, the fence, a porch light somebody left on. It's all exactly how you'd remember it — funny way to put it, for a place you've never been.",
			'Carved into the fence by the green: "there are seven ways home."',
		},
	},
	TidepoolCove = {
		chapter = 2,
		title = "The First Goodbyes",
		intro = {
			"Tidepool Cove — where the first goodbyes happened. The tide goes out; some of it comes back.",
			"That leaning fence by the dunes, half-sunk in sand... you'd swear it's the one from the green.",
		},
	},
	Emberpeak = {
		chapter = 3,
		title = "Itching to Go",
		intro = {
			"Emberpeak — the town in a hurry to be anywhere else. Doors left swinging, a room packed up in one night.",
			"Everything here left loud. Some of it is still leaving.",
		},
	},
	VoltWasteland = {
		chapter = 4,
		title = "The World Moved On",
		intro = {
			"Volt Wasteland — the lights stayed on long after everyone left. Machinery humming to an empty house.",
			"A clock still ticking. A radio playing to no one. Nobody asked them to stop.",
		},
	},
	CanyonDepths = {
		chapter = 5,
		title = "How Deep It Goes",
		intro = {
			"Canyon Depths — the town's foundations, layer under layer. The deeper you go, the more familiar it gets.",
			"There are names carved in the stone down here. Old ones, under older ones.",
		},
	},
	FrostbiteTundra = {
		chapter = 6,
		title = "The Quiet After",
		intro = {
			"Frostbite Tundra — everything here is kept exactly as it was the day it was last loved.",
			"A table under the aurora, set for two. Frost on one window that never melts. You know the window.",
		},
	},
	DuskwoodHollow = {
		chapter = 7,
		title = "Letting the Light Go",
		intro = {
			"Duskwood Hollow — the last of the light. Nothing here to defeat; just a goodbye that hasn't decided how to be said.",
			"From the hill you can see the whole valley at dusk. Every road out of it curves back. Seven ways home.",
		},
	},
}

-- ─── ONE-SHOT BEATS ────────────────────────────────────────────────────
-- The twist ladder, delivered as skippable margin-notes. Each beat fires
-- once per save; StorySystem owns the triggers (listed here as comments).
-- Every line reads fine as small-town flavor — only in hindsight do they turn.

StoryData.Beats = {
	-- New game, just after the starter pick. The slip is the first thread.
	merle_welcome = {
		speaker = StoryData.SPEAKER_MERLE,
		lines = {
			"Well, look at you. The green's been short one pair of feet, y'know.",
			"You've got your mother's way of squinting at the hills. ...Anyway.",
			"Welcome back— welcome, I mean. Welcome. Go on, the neighbors don't bite. Most of them are neighbors.",
		},
	},
	-- First wild catch of the save.
	first_catch = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"First one's in the book. They seemed glad about it — like being remembered was the whole point.",
		},
	},
	-- Twist rung 1 (5 unique species): the studs had lives.
	note_lives = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"These entries keep mentioning jobs. Porches. A bake sale. Funny things to write about wild creatures.",
		},
	},
	-- Twist rung 2 (12 unique species): souls recur across types.
	note_shared = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Two entries, two types, one memory — both pages mention the same porch, the same summer. Souls don't seem to care what they're made of.",
		},
	},
	-- First catch in Tidepool Cove: the quiet wrongness begins.
	note_handwriting = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"A note tucked into this page: \"gone to the coast — write soon.\" You don't remember writing it. It's your handwriting.",
		},
	},
	-- First catch in Emberpeak: the personal thread. Last remembered mid-argument — with you.
	note_argument = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"The margin here just says: \"we shouted. I don't remember what about. I remember who with.\"",
		},
	},
	-- First catch in Volt Wasteland: twist rung 5 — the Registry isn't yours.
	note_keeper = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"This Registry wasn't blank when you got it. Someone kept it for years before you — there's a message on the flyleaf.",
			"It's in your handwriting too.",
		},
	},
	-- First catch in Canyon Depths: twist rung 6 — your latent ability stirs.
	note_reflection = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"For a second, in the still water on the stone, your reflection flickered — the way the wild ones do. Long day. Probably.",
		},
	},
	-- Fifth catch in Canyon Depths: the carving.
	note_carving = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Near the bottom of the carvings, two names together. One of them is Bryan. The other one is scratched out.",
		},
	},
	-- Eighth catch in Canyon Depths: twist rung 7 — Merle pays off "knew you when".
	merle_knew = {
		speaker = StoryData.SPEAKER_MERLE,
		lines = {
			"I taught the pair of you to fish off the green, y'know. You and the one who stayed.",
			"...You really don't remember, do you. That's alright. That's what the book is for.",
		},
	},
	-- First catch in Frostbite Tundra: twist rung 8, kept whispered.
	note_kept = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"The studs here don't startle when you come close. They make room, like you never left.",
		},
	},
	-- First catch in Duskwood Hollow: twist rung 9 — the truth, and it's ordinary.
	note_truth = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Nobody was taken. Nothing was lost. Everyone just grew up, and left, and the town stayed here — remembered.",
			"That's all this ever was. The ache is just the ordinary kind, the kind things ending make.",
		},
	},
	-- All seven of Bryan's ways caught: the spine completes.
	ways_complete = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Seven ways, seven weathers, one Bryan — remembered whole.",
			"The page they saved for you is the only blank one left.",
		},
	},
}

-- ─── BRYAN'S SEVEN WAYS ────────────────────────────────────────────────
-- The recurring-soul law made collectible: you remember Bryan in every
-- weather, so Bryan surfaces once per region as a different-typed stud.
-- The constant tell is the phrase "...said they'd wait." in each dex aside
-- (plus the near-name B-pattern where the roster allows it: Brian, Brenda,
-- Bert, Brad, Boyd). Catching all seven = remembering Bryan whole.
-- Species picks are the name-ledger call left open in the design docs:
-- brian was locked (the Brian≈Bryan tell); the other six chosen here.

StoryData.BryanWays = {
	{ world = "Studville",       studId = "stan" },   -- the friend from the Last Good Summer, still where you left him
	{ world = "TidepoolCove",    studId = "brian" },  -- the near-name tell; meant to leave, kept not going
	{ world = "Emberpeak",       studId = "brenda" }, -- the argument right before you left
	{ world = "VoltWasteland",   studId = "kim" },    -- the keeper who wrote your page, waiting on a call
	{ world = "CanyonDepths",    studId = "bert" },   -- the second name carved beside your scratched-out one
	{ world = "FrostbiteTundra", studId = "brad" },   -- the one you finally find, kept, unchanged
	{ world = "DuskwoodHollow",  studId = "boyd" },   -- the faintest Bryan, nearly gone, present for the choice
}

StoryData.WayIndexById = {}
for i, way in ipairs(StoryData.BryanWays) do
	StoryData.WayIndexById[way.studId] = i
end

-- Beat lines when a way is first caught. Way 6 (Frostbite) is the gut-punch:
-- you didn't lose Bryan — you left.
StoryData.WayBeats = {
	{ "This one kept looking back at you while you wrote, like you'd forgotten something. The margin already had a note: \"...said they'd wait.\"" },
	{ "Brian. Bryan? The pen slipped. Funny — it's almost the right name.", "\"...said they'd wait.\"" },
	{ "This page came with heat on it — an argument someone lost on purpose, just so it would end.", "\"...said they'd wait.\"" },
	{ "This one's been holding a charge for years. Never misses a call. Still waiting on one.", "\"...said they'd wait.\"" },
	{ "The second name from the canyon wall — the one carved next to yours.", "\"...said they'd wait.\"" },
	{
		"Kept. Unchanged. Still waiting — right where you left them.",
		"You didn't lose Bryan. You left. This whole journey is you coming back to the people you moved on from.",
		"They're not angry. They said they'd wait, and they meant it.",
	},
	{ "The faintest way of all — almost let go, holding on for one last thing. For this, it turns out.", "\"...said they'd wait.\"" },
}

-- ─── DEX ASIDES (story mode sub-text under the dex description) ────────
-- The persistent story surface: same stud, second reading. Only shown for
-- caught species while Story mode is on. Legendaries are the region's
-- most-remembered neighbors; the ways carry the tell; the rest is the
-- relationship web (the fence, the bakers' cold war, the last-stayers).

StoryData.DexAsides = {
	-- The web (everyday neighbors)
	steve = "Leaned on the town-green fence beside Bill for forty years and called it a friendship. Correctly.",
	bill = "Says he's just resting. The fence, quietly, agrees to need him.",
	marge = "Her table and Ethel's sat six feet apart for thirty years, and the whole town ate at both out of diplomacy.",
	earl = "Fixed everyone's everything. The town ran on casseroles and Earl.",
	chad = "Fastest kid on the seven roads, once. Never raced anyone home — that part mattered to him.",

	-- Bryan's seven ways (the tell)
	stan = "Hasn't moved since spring. Not because he can't — somebody promised to come back this way. ...said they'd wait.",
	brian = "Meant to leave with Ted and Barb. Every spring, next spring. The coast road still keeps his spot. ...said they'd wait.",
	brenda = "The last argument anyone remembers her having, she lost on purpose so it would end. ...said they'd wait.",
	kim = "Never misses a call. There's one she's been waiting on for years. ...said they'd wait.",
	bert = "Carved two names low in the canyon where the weather can't reach them. One got scratched out anyway. ...said they'd wait.",
	brad = "Kept everything exactly where it was. The table. The window. The chair by the door. ...said they'd wait.",
	boyd = "The hardest neighbor to keep in mind, and he doesn't blame you. Left the porch light burning, just in case. ...said they'd wait.",

	-- The fourteen legendaries: the town's unforgettable few
	greg = "He was the fields, and the fields were the summer. Nobody's memory of home starts anywhere else.",
	ethel = "Ran the bake sale, the green, and by extension the town. Being fussed over by Ethel was the local religion.",
	ted = "First one down the coast road. Wrote less each season. The town forgave him every spring, on schedule.",
	barb = "Left with Ted and never looked back — that's the story, anyway. The wreck in the cove knows a longer one.",
	bob = "Showed up late to the one parade the town ever threw him, and stayed after to fold the chairs.",
	karen = "Burned brightest, left hardest, and is remembered louder than anyone who stayed — which is its own kind of sad.",
	chuck = "Kept the power on for a town of six, then four, then one. Called it keeping the porch lit, and dared you to laugh.",
	pam = "Ran the last town meeting to an audience of chairs. Motion to keep going: carried, unanimously.",
	al = "Was here before the fence, the green, the roads. Plans to outlast the remembering, out of politeness.",
	doris = "The town's memory of itself. If you wanted to know how it really happened, you asked Doris. Everyone did.",
	gus = "Keeps a table set for two under the aurora. Won't say who the second chair is for. Won't clear it, either.",
	edna = "Froze the garden the day the last neighbor left, so it would keep. It kept. She's still deciding if that was mercy.",
	hal = "The faintest of the faint, and at peace with it. He'll be the one who tells you it's okay to let go.",
	myrna = "Almost gone, and gentle about it. When it's time, she hands you the pen — and she means it kindly.",
}

-- Legendary catches also fire their aside as a one-shot "re-meet" beat.
StoryData.LegendaryIds = {
	greg = true, ethel = true, ted = true, barb = true, bob = true, karen = true,
	chuck = true, pam = true, al = true, doris = true, gus = true, edna = true,
	hal = true, myrna = true,
}

-- ─── UNIQUE-DEX THRESHOLD NOTES ────────────────────────────────────────
-- { uniqueCount required, beatId } — checked on every catch, so a Casual
-- player who switches to Story mid-save still picks these up.

StoryData.UniqueNotes = {
	{ count = 5, beatId = "note_lives" },
	{ count = 12, beatId = "note_shared" },
}

-- ─── PER-WORLD CATCH NOTES ─────────────────────────────────────────────
-- { world, catches-in-that-world required, beatId } — the region's deep
-- notes, spaced so they land after the player has settled in.

StoryData.WorldNotes = {
	{ world = "TidepoolCove", count = 1, beatId = "note_handwriting" },
	{ world = "Emberpeak", count = 1, beatId = "note_argument" },
	{ world = "VoltWasteland", count = 1, beatId = "note_keeper" },
	{ world = "CanyonDepths", count = 1, beatId = "note_reflection" },
	{ world = "CanyonDepths", count = 5, beatId = "note_carving" },
	{ world = "CanyonDepths", count = 8, beatId = "merle_knew" },
	{ world = "FrostbiteTundra", count = 1, beatId = "note_kept" },
	{ world = "DuskwoodHollow", count = 1, beatId = "note_truth" },
}

-- ─── THE ENDING (The Last Page) ────────────────────────────────────────
-- Reached when the Registry is complete (every species remembered).
-- Two-way choice; both warm, neither correct. Rewards are cosmetic titles
-- only — the tentative progression-buff idea (3x EXP / 2x damage) is
-- deliberately NOT built: it collides with the fair-collector/PvP economy
-- and was flagged "don't make it permanent yet" in the design docs.

StoryData.Ending = {
	offerTitle = "The Last Page",
	offerLines = {
		"The Registry is full. Every neighbor, remembered. The valley is dim now, and the porch light is flickering — yours to turn off or leave on.",
		"Bryan is beside you. The last blank page is your own.",
		"How do you say goodbye to a place you outgrew?",
	},
	choices = {
		rest = {
			label = "LET IT REST",
			blurb = "Finish the last page. The town gets a peaceful goodbye.",
			title = "At Peace",
			epilogue = {
				"You finish the page. The light goes out gently — grateful, like a house settling for the night.",
				"Outgrowing a place you loved was never a betrayal. It's what love in a life does.",
			},
		},
		alive = {
			label = "KEEP IT ALIVE",
			blurb = "Leave the page blank. The town stays a place people can return to.",
			title = "Keeper of the Light",
			epilogue = {
				"You leave the page blank, and the light stays on — for you, for Bryan, for anyone who ever wants a way back.",
				"There are seven, after all.",
			},
		},
	},
	-- Shown under the epilogue either way; Merle gets the last word.
	closingLine = '"There are seven ways home," Merle says, to nobody in particular. "Always were."',
}

return StoryData
