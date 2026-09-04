class_name Achievements
extends RefCounted
## Local achievements. Checked once per finished song against the run and the
## lifetime counters in G; unlocked ids live in the save file.

const LIST := [
	{"id": "first_song", "name": "First steps", "desc": "Finish your first song"},
	{"id": "combo_100", "name": "Chain reaction", "desc": "Reach a combo of 100"},
	{"id": "combo_500", "name": "Unbreakable", "desc": "Reach a combo of 500"},
	{"id": "rank_s", "name": "Sharp", "desc": "Finish a song with rank S"},
	{"id": "rank_ss", "name": "Flawless", "desc": "Finish a song with rank SS"},
	{"id": "full_combo", "name": "Full combo", "desc": "Finish a song without a single miss"},
	{"id": "notes_10k", "name": "Ten thousand cubes", "desc": "Hit 10 000 notes in total"},
	{"id": "plays_50", "name": "Regular", "desc": "Play 50 songs"},
	{"id": "modded", "name": "Handicap", "desc": "Finish a song with two or more modifiers"},
	{"id": "blackout", "name": "By heart", "desc": "Finish a song with BLACKOUT on"},
	{"id": "speedrun", "name": "Faster", "desc": "Finish a song with SPEED UP on"},
	{"id": "mapper", "name": "Mapper", "desc": "Save a map in the editor"},
	{"id": "importer", "name": "Collector", "desc": "Import a map from another game"},
	{"id": "calibrated", "name": "In time", "desc": "Run the offset calibration"},
]


static func def_of(id: String) -> Dictionary:
	for a in LIST:
		if str(a.id) == id:
			return a
	return {}


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
	var candidates: Array = ["first_song"]
	if int(res.get("max_combo", 0)) >= 100:
		candidates.append("combo_100")
	if int(res.get("max_combo", 0)) >= 500:
		candidates.append("combo_500")
	if str(res.get("rank", "")) == "S":
		candidates.append("rank_s")
	if str(res.get("rank", "")) == "SS":
		candidates.append("rank_ss")
	if int(counts.get("MISS", 0)) == 0 and int(res.get("max_combo", 0)) > 0:
		candidates.append("full_combo")
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
	for id in candidates:
		if unlock(id):
			got.append(id)
	return got
