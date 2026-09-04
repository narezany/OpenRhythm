class_name Achievements
extends RefCounted
## Local achievements. Checked once per finished song against the run and the
## lifetime counters in G; unlocked ids live in the save file. Ids are stable -
## rename a title freely, never an id, or somebody loses a badge.

const LIST := [
	{"id": "first_song", "icon": "note", "name": "And so it begins",
		"desc": "Finish your first song"},
	{"id": "combo_100", "icon": "bolt", "name": "Cannot be stopped",
		"desc": "Reach a combo of 100"},
	{"id": "combo_500", "icon": "flame", "name": "Absolutely locked in",
		"desc": "Reach a combo of 500"},
	{"id": "rank_s", "icon": "star", "name": "Sharp",
		"desc": "Finish a song with rank S"},
	{"id": "rank_ss", "icon": "crown", "name": "No thoughts, head empty, only SS",
		"desc": "Finish a song with rank SS"},
	{"id": "full_combo", "icon": "heart", "name": "Not a single cube was harmed",
		"desc": "Finish a song without a miss"},
	{"id": "notes_10k", "icon": "cube", "name": "Ten thousand cubes later",
		"desc": "Hit 10 000 notes in total"},
	{"id": "plays_50", "icon": "clock", "name": "Touch grass? never heard of it",
		"desc": "Play 50 songs"},
	{"id": "modded", "icon": "skull", "name": "Why do you do this to yourself",
		"desc": "Finish a song with two or more modifiers"},
	{"id": "blackout", "icon": "eye", "name": "Trust me bro, I know the chart",
		"desc": "Finish a song with BLACKOUT on"},
	{"id": "speedrun", "icon": "flame", "name": "Gotta go fast",
		"desc": "Finish a song with SPEED UP on"},
	{"id": "slowpoke", "icon": "turtle", "name": "We have time at home",
		"desc": "Finish a song with SLOW DOWN on"},
	{"id": "mirrored", "icon": "mirror", "name": "Everything is backwards",
		"desc": "Finish a song with MIRROR on"},
	{"id": "mapper", "icon": "grid", "name": "Certified chart cook",
		"desc": "Save a map in the editor"},
	{"id": "importer", "icon": "box", "name": "Borrowed from the neighbours",
		"desc": "Import a map from another game"},
	{"id": "calibrated", "icon": "clock", "name": "It was never lag",
		"desc": "Run the offset calibration"},
	{"id": "melly_paint", "icon": "palette", "name": "is that a silly gubby",
		"desc": "Repaint Melly in the settings"},
	{"id": "replay_saved", "icon": "disc", "name": "Evidence, your honour",
		"desc": "Save a replay"},
	{"id": "night_owl", "icon": "moon", "name": "It is 4 AM and I am fine",
		"desc": "Play between 3 and 5 in the morning"},
	{"id": "bullshit", "icon": "skull", "name": "Certified BULLSHIT enjoyer",
		"desc": "Collect 10 BULLSHIT judgements in one song"},
	{"id": "airball", "icon": "ghost", "name": "Perfectly balanced, as all things",
		"desc": "Finish a song without hitting a single note"},
	{"id": "polyglot", "icon": "globe", "name": "Reading in another tongue",
		"desc": "Switch the game language"},
	{"id": "story_done", "icon": "book", "name": "Sat through the whole thing",
		"desc": "Finish a story"},
]


static func def_of(id: String) -> Dictionary:
	for a in LIST:
		if str(a.id) == id:
			return a
	return {}


static func icon_of(id: String) -> String:
	return str(def_of(id).get("icon", "star"))


static func has(id: String) -> bool:
	return id in G.unlocked


## Unlock one achievement. Returns true when it was actually new.
static func unlock(id: String) -> bool:
	if has(id) or def_of(id).is_empty():
		return false
	G.unlocked.append(id)
	G.save_all()
	return true


## Check everything a finished run can unlock. Returns the new ids.
static func check_results(res: Dictionary) -> Array:
	var got: Array = []
	var counts: Dictionary = res.get("counts", {})
	var mods: Array = res.get("mods", [])
	var combo := int(res.get("max_combo", 0))
	var hits := int(counts.get("PERFECT", 0)) + int(counts.get("GREAT", 0)) \
		+ int(counts.get("GOOD", 0)) + int(counts.get("BULLSHIT", 0))
	var candidates: Array = ["first_song"]
	if combo >= 100:
		candidates.append("combo_100")
	if combo >= 500:
		candidates.append("combo_500")
	if str(res.get("rank", "")) == "S":
		candidates.append("rank_s")
	if str(res.get("rank", "")) == "SS":
		candidates.append("rank_ss")
	if int(counts.get("MISS", 0)) == 0 and combo > 0:
		candidates.append("full_combo")
	if hits == 0 and int(counts.get("MISS", 0)) > 0:
		candidates.append("airball")
	if int(counts.get("BULLSHIT", 0)) >= 10:
		candidates.append("bullshit")
	if G.stat_notes >= 10000:
		candidates.append("notes_10k")
	if G.stat_plays >= 50:
		candidates.append("plays_50")
	if mods.size() >= 2:
		candidates.append("modded")
	if "fade" in mods:
		candidates.append("blackout")
	if "speed" in mods:
		candidates.append("speedrun")
	if "slow" in mods:
		candidates.append("slowpoke")
	if "mirror" in mods:
		candidates.append("mirrored")
	if res.get("story_complete", false):
		candidates.append("story_done")
	var hour: int = Time.get_time_dict_from_system().get("hour", 12)
	if hour >= 3 and hour < 5:
		candidates.append("night_owl")
	for id in candidates:
		if unlock(id):
			got.append(id)
	return got
