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

-- ─── MODE SELECT (SaveLoadUI's New Game → Story/Casual screen) ─────────
-- Lives here (not in SaveLoadUI) so every word of story voice stays in this
-- module — reword the pitch once and the menu follows.

StoryData.ModeSelect = {
	caption = "WHICH WAY WILL YOU COME BACK?",
	hint = "STORY — walk in as someone the town never stopped expecting\nCASUAL — just the collecting, clean and quiet, no one watching",
}

-- ─── CHAPTERS (one per world — the seven weathers) ─────────────────────
-- intro fires once per save on first entry to the world (Studville: at the
-- start of a new game). Order = the emotional arc of a town emptying out.

StoryData.Chapters = {
	Studville = {
		chapter = 1,
		title = "The Last Good Summer",
		intro = {
			"Studville: the green still combed by the wind, the fence still leaning the way it always leaned, a porch light burning at noon for no reason anyone can name. It fits you like a coat left in a familiar closet — strange, for a town your feet have never touched.",
			"Someone took a knife to the fence by the green a long time ago, and the letters have gone soft with weather: there are seven ways home.",
		},
	},
	TidepoolCove = {
		chapter = 2,
		title = "The First Goodbyes",
		intro = {
			"Tidepool Cove, where the town first learned that people could leave. The tide taught the lesson gently: it goes out completely, and it comes back — but never with quite everything it took.",
			"There's a fence half-drowned in the dunes, tilting the exact tired angle of the one on the green. A town only builds a fence one way. You already know it's the same fence.",
		},
	},
	Emberpeak = {
		chapter = 3,
		title = "Itching to Go",
		intro = {
			"Emberpeak, where wanting-to-be-elsewhere caught like a fever and nobody thought to put it out. Doors still swing on their hinges. One whole room was folded into boxes between dusk and dawn, the way you only pack when staying has started to hurt.",
			"Everything here made its exit at a shout. Listen close and you'll notice some of it never finished leaving — the loudness is just an echo that hasn't found the door.",
		},
	},
	VoltWasteland = {
		chapter = 4,
		title = "The World Moved On",
		intro = {
			"Volt Wasteland, where the power outlasted the people. The machines never got the news; they go on humming their one devoted note to rooms that emptied years ago, faithful the way only things without hearts can afford to be.",
			"A clock keeps time nobody spends. A radio plays to an audience of dust. No one thought to tell them it was over — and so, in the only way that's left, it isn't.",
		},
	},
	CanyonDepths = {
		chapter = 5,
		title = "How Deep It Goes",
		intro = {
			"Canyon Depths, where the town keeps what it was built on — every year of itself pressed flat and stacked beneath the last. Strangely, the farther down you climb, the less like a stranger you feel; some things you recognize with your feet before your mind agrees.",
			"People carved their names into this stone to outlast themselves. Read down the wall and the names get older, and under the old ones are older ones still, until you reach the ones cut by hands that wanted, more than anything, to be remembered by someone exactly like you.",
		},
	},
	FrostbiteTundra = {
		chapter = 6,
		title = "The Quiet After",
		intro = {
			"Frostbite Tundra, where the cold does the work grief can't: it holds everything at the temperature of the day it was last loved, and refuses, out of loyalty, to let a single thing move on.",
			"A table stands set for two beneath a sky quietly on fire. One windowpane wears a frost that has never once considered melting. You knew which window it would be before you looked — you always know the window you left the light on in.",
		},
	},
	DuskwoodHollow = {
		chapter = 7,
		title = "Letting the Light Go",
		intro = {
			"Duskwood Hollow, where the day spends its last coin of light. There is no enemy here, nothing to conquer or survive — only a goodbye that has been standing at the door for years, still working up the courage to choose its words.",
			"Climb the hill and the whole valley lies under you in the failing light, and here is the thing you were never meant to notice until now: every road that leaves it bends, sooner or later, back. Seven roads out, seven roads home. They were always the same roads.",
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
			"Well, would you look at that. A green this size only really needs one more pair of feet to feel finished, and it's been standing here unfinished a good while.",
			"You squint at those hills the exact way your mother used to — like they owe you an answer and you've got all afternoon to collect it. ...Anyway. Listen to me.",
			"Welcome back— welcome, I meant to say. Welcome. Go on out and meet folks; they don't bite, and most of them really are folks. That's the town's one bit of honesty and I'll let you keep it.",
		},
	},
	-- First wild catch of the save.
	first_catch = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"First one's down in the book, ink still wet. They didn't fight it at all — they went easy, almost grateful, the way a name goes when it's been afraid of being forgotten and finally isn't.",
		},
	},
	-- Twist rung 1 (5 unique species): the studs had lives.
	note_lives = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Odd — the entries keep slipping in the small furniture of a life. A job someone was proud of. A porch someone swept. A bake sale, of all things. Wild creatures aren't supposed to leave that kind of paperwork behind.",
		},
	},
	-- Twist rung 2 (12 unique species): souls recur across types.
	note_shared = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Two different creatures, two different natures, and yet the same porch turns up on both pages, the same summer, warm in the same handwriting. Whatever a soul is, it doesn't check what body it woke up in — it just goes on loving the things it always loved.",
		},
	},
	-- First catch in Tidepool Cove: the quiet wrongness begins.
	note_handwriting = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"A slip of paper is folded into this page, soft at the creases from being folded and unfolded by someone: \"gone to the coast — write soon.\" You have no memory of setting those words down. That does nothing to change the fact that the hand which wrote them was yours.",
		},
	},
	-- First catch in Emberpeak: the personal thread. Last remembered mid-argument — with you.
	note_argument = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"The margin holds one line, pressed hard enough to score the page: \"we shouted. the reason's long gone. the person never will be.\" That's how you can tell a fight mattered — the words burn off and only the face is left.",
		},
	},
	-- First catch in Volt Wasteland: twist rung 5 — the Registry isn't yours.
	note_keeper = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"This Registry came to you already lived-in. Someone carried it for years before it was ever yours, filled its early pages, wore a shine into its spine — and left a message on the flyleaf for whoever came next.",
			"You already know whose hand wrote it. It's the same one that wrote all the others. It's yours.",
		},
	},
	-- First catch in Canyon Depths: twist rung 6 — your latent ability stirs.
	note_reflection = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"In the still water pooled on the stone, your reflection stuttered for half a breath — flickering the exact way the wild ones flicker just before the book takes them. It's been a long day, you tell yourself, and you're almost sure that's the whole of it.",
		},
	},
	-- Fifth catch in Canyon Depths: the carving.
	note_carving = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Low on the wall, where the weather never reaches, two names were cut side by side to last forever. One of them is Bryan. The other has been scratched out — not by the weather, but by a hand that couldn't bear to be read there, and couldn't quite leave.",
		},
	},
	-- Eighth catch in Canyon Depths: twist rung 7 — Merle pays off "knew you when".
	merle_knew = {
		speaker = StoryData.SPEAKER_MERLE,
		lines = {
			"I taught the two of you to fish off the end of the green, back when your legs didn't reach the water. You and the one who never did leave — you were a matched set once.",
			"...It's really gone from you, isn't it. Don't look like that. That's no crime. Forgetting is just the tax a life charges for going on living — and the book, well, the book is how we pay it back.",
		},
	},
	-- First catch in Frostbite Tundra: twist rung 8, kept whispered.
	note_kept = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"The studs here don't bolt when your shadow falls over them. They shift, quiet, and make a space at their side — the way people only make room for someone they've been holding a place for all along.",
		},
	},
	-- First catch in Duskwood Hollow: twist rung 9 — the truth, and it's ordinary.
	note_truth = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"No one was stolen. Nothing was cursed. There was no dark thing at the bottom of any of it. Everyone simply grew, and grew past this place, and went — and the town stayed behind, not haunted, only remembered.",
			"That is the entire secret, and it was never a monster. The ache you've been carrying room to room is the plainest ache there is: the small, honest weight that every ending leaves in the hands of whoever loved the thing that ended.",
		},
	},
	-- All seven of Bryan's ways caught: the spine completes.
	ways_complete = {
		speaker = StoryData.SPEAKER_REGISTRY,
		lines = {
			"Seven ways, seven weathers, and every one of them the same person wearing a different season — Bryan, scattered across a whole valley and now gathered back into one face. That's what remembering someone whole finally means: refusing to leave any weather of them behind.",
			"Every page is written but one. It was never yours to fill for them — they kept it blank on purpose, the way you hold a door, and they left it waiting for you to decide what your own last word would be.",
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

-- Beat lines when a way is first caught. Way 6 (Frostbite) is the gut-punch:
-- you didn't lose Bryan — you left.
StoryData.WayBeats = {
	{ "This one wouldn't stop glancing back at you as you wrote, patient and expectant, as if you'd walked in mid-sentence of something the two of you had left unfinished. The margin was already waiting with its answer: \"...said they'd wait.\"" },
	{ "Brian, your hand writes — then hesitates over the vowel. Bryan? The pen knew before you did and tried to steer you home. So close to the right name that missing it is its own kind of confession.", "\"...said they'd wait.\"" },
	{ "The page came to you still warm, carrying the heat of an old argument — the kind someone throws on purpose so the fight will finally have somewhere to end, because ending it was the only way left to stay.", "\"...said they'd wait.\"" },
	{ "This one has held its charge for years without once being asked to. It answers every call on the first ring. There's only one call it's ever wanted, and it has never stopped keeping the line open for it.", "\"...said they'd wait.\"" },
	{ "The second name from the canyon wall — the one someone cut in beside yours to last forever, then couldn't decide whether to keep or scratch away.", "\"...said they'd wait.\"" },
	{
		"Kept. Unchanged. Waiting in the exact spot the door was closed on, as though the closing had been a promise instead of a goodbye.",
		"Here is the thing no earlier page dared say plainly: Bryan was never taken from you. You were the one who left. Every mile of this has been you walking back to the people you outgrew and quietly asking to be let in again.",
		"And there's no anger in it — that's the part that undoes you. They said they'd wait, and waiting, for them, was never a burden. It was just what love does when it's told to sit still.",
	},
	{ "The faintest way of them all, worn nearly to nothing, holding on by a thread against every reason to let go — saving that last thread, it turns out, for exactly this. For you. For being found before it finished fading.", "\"...said they'd wait.\"" },
}

-- ─── DEX ASIDES (story mode sub-text under the dex description) ────────
-- The persistent story surface: same stud, second reading. Only shown for
-- caught species while Story mode is on. Legendaries are the region's
-- most-remembered neighbors; the ways carry the tell; the rest is the
-- relationship web (the fence, the bakers' cold war, the last-stayers).

StoryData.DexAsides = {
	-- The web (everyday neighbors)
	steve = "Leaned on the green's fence at Bill's shoulder for forty years and named it friendship — which, it turns out, is the correct name for standing next to someone that long and never once needing a reason.",
	bill = "Insists he's only resting a minute. The fence has agreed, without a word, to go on needing him — because a thing that leans has to lean on something, and so does a man.",
	marge = "Her table and Ethel's sat a stubborn six feet apart for thirty years, and the whole town ate a little at each, out of a diplomacy so gentle nobody ever admitted it was keeping the peace.",
	earl = "Mended everyone's everything and let no one thank him too much for it. The town, if you traced its wiring, ran on two currents: casseroles, and Earl.",
	chad = "Fastest kid the seven roads ever carried, and he could have won any race he wanted. He never once raced anyone home — being the first to leave was never the prize; that part he understood before the rest of us did.",

	-- Bryan's seven ways (the tell)
	stan = "Hasn't left this spot since spring, and it isn't that his legs forgot how — someone promised to come back along this road, and staying put is the only way he knows to hold them to it. ...said they'd wait.",
	brian = "Meant to go with Ted and Barb every single spring, and every spring became next spring, until next spring was just the name he gave to staying. The coast road still keeps his place open, the way roads do for the ones who never quite take them. ...said they'd wait.",
	brenda = "The last argument anyone can remember her in, she lost on purpose — not from weakness, but because losing it was the only way to make it stop, and stopping it was the only way to keep the person on the other side. ...said they'd wait.",
	kim = "Answers every call before it rings twice. There is one call, years overdue now, that she has arranged her whole quiet life around not missing. ...said they'd wait.",
	bert = "Cut two names low into the canyon, down where no weather could ever wear them away. One got scratched out all the same — proof that the thing time can't reach, a person still can, and still might regret. ...said they'd wait.",
	brad = "Left everything precisely where it stood the day the door last closed. The table uncleared, the window unwiped, the chair by the door angled toward it — a whole house held at the exact posture of about-to-be-returned-to. ...said they'd wait.",
	boyd = "The neighbor hardest to hold in your mind, and the last one who would ever hold that against you. He left the porch light burning through every dark year, just in case — because 'just in case' is what hope sounds like when it's too tired to say more. ...said they'd wait.",

	-- The fourteen legendaries: the town's unforgettable few
	greg = "He wasn't just in the fields; he was the fields, and the fields were what summer meant, and summer was what home meant. Ask anyone where their memory of belonging begins and it begins standing in Greg, up to the knees in green.",
	ethel = "Ran the bake sale, and the green, and therefore — by a logic no one dared contest — the town itself. To be fussed over by Ethel was the closest thing this place had to being blessed, and the whole valley kept the faith.",
	ted = "First soul to trust the coast road all the way out. His letters thinned with every season until they were mostly the space where letters used to be. The town forgave him each spring anyway, on schedule, the way you forgive the tide for going.",
	barb = "Went with Ted and never once looked back — or so the tidy version goes. The wreck rusting out in the cove keeps a longer, truer account, the kind the water tells only to those who stay long enough to listen.",
	bob = "Arrived late to the single parade the town ever threw in his honor, missed his own applause, and then stayed behind in the emptying square to fold every last chair — which was, if you knew Bob, the truer parade.",
	karen = "Burned the brightest, left the hardest, and is somehow remembered louder than any of the ones who quietly stayed — a fame that is its own soft tragedy, since the town learned her name best by losing her.",
	chuck = "Kept the power running for a town of six, then four, then one, then only himself. He called it keeping the porch lit, said it with a straight face, and dared you with his eyes to find that foolish.",
	pam = "Gaveled the final town meeting to order before a gallery of empty chairs, put forward the motion to carry on regardless, and recorded it passed — unanimous, if you counted the way she counted, and she did.",
	al = "Was already here before the fence, before the green, before anyone thought to cut the roads. He intends to outlast even the remembering — not from pride, he'll tell you, but out of a kind of manners, so the place is never entirely alone.",
	doris = "The town's memory of its own self, kept in one person. When you needed to know how it truly went — not the polished version, the real one — you went to Doris. Everyone did, and Doris never once got it wrong.",
	gus = "Sets a table for two beneath the burning sky and keeps it set. He won't tell you who the second chair belongs to. He won't clear it away, either — and between those two refusals lives everyone he's ever loved.",
	edna = "Froze the whole garden solid the day the last neighbor walked out, so that nothing green would have to go on without them. It worked; it kept. She has not yet decided, all these winters on, whether keeping it was mercy or just a mercy's shape.",
	hal = "The faintest of all the faint, and wholly at peace with the fading. When the time comes, he'll be the one who sits beside you and says, in the plainest voice, that it is alright to let a thing go.",
	myrna = "Nearly gone now, and so gentle about the going that it steadies you instead of the other way round. When the moment arrives she'll place the pen in your hand herself — and she means the gesture kindly, the way you'd hand someone the last light before dark.",
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
		"The Registry is full at last — every neighbor found, every weather of every soul written back into the book. The valley has gone soft and dim around you, and the porch light is guttering, down to its final honest flicker. Whether it goes dark or goes on burning is the one thing left that only your hand can decide.",
		"Bryan is here at your side, all seven ways of them gathered into one quiet presence. The last blank page in the whole Registry isn't theirs, or the town's. It has your name at the top of it and nothing underneath.",
		"So here is the question the whole valley has been walking you toward: how do you say goodbye to a place you didn't lose, but simply outgrew?",
	},
	choices = {
		rest = {
			label = "LET IT REST",
			blurb = "Write the last page and close the book. The town is given the peaceful goodbye it was always owed.",
			title = "At Peace",
			epilogue = {
				"You set down the final words and close the cover. The porch light doesn't die so much as exhale — going out the grateful, unhurried way a house lets go of the day, every board settling, everything finally allowed to be over.",
				"To outgrow a place you loved was never a betrayal of it. It's the one thing love reliably does when you give it a whole life to move through — it carries you onward, and asks only that you remember where it started.",
			},
		},
		alive = {
			label = "KEEP IT ALIVE",
			blurb = "Leave the last page unwritten. The town stays open — a place a person can always turn back toward.",
			title = "Keeper of the Light",
			epilogue = {
				"You leave the page bare and let the light go on burning — for yourself, for Bryan, for every soul who might someday stand at the far end of a road and need to believe there's still something lit at the other end of it.",
				"A door you refuse to close isn't a door you failed to walk through. It's a promise, kept in the only tense that matters: there are seven ways home, after all, and now not one of them is dark.",
			},
		},
	},
	-- Shown under the epilogue either way; Merle gets the last word.
	closingLine = '"There are seven ways home," Merle says, to no one in particular, to the whole valley, to you. "There always were. The only trick was ever letting yourself believe you were still allowed to take one."',
}

return StoryData
