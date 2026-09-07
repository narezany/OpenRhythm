class_name Coins
extends RefCounted
## Purple coins: what clearing the game's own songs is worth, and what Melly's
## wardrobe costs.
##
## Only the songs and stories that ship with the game pay. A map you wrote
## yourself, or one you downloaded, does not - not because those are worth
## less, but because a currency you can mint by generating a chart with the
## auto button and clearing it on easy is not a currency. The same reason
## repeats pay half: the first time you clear something you were finding out
## whether you could, and every time after that you already knew.
##
## The rank decides the rest. A run that scraped through pays a fraction of one
## that did not, so a wardrobe is bought by playing well rather than by playing
## often - and a player who barely engages with the game earns nothing at all,
## which is the honest answer to "what do I get for doing almost nothing".

## What one clear is worth, before the rank is taken into account. Read from
## where the difficulty sits among the song's own rather than from its name.
const BASE_EASIEST := 9.0
const BASE_HARDEST := 30.0
## Finishing a story chapter, on top of the songs inside it - per song in it,
## not a flat sum. A flat bonus paid the same for the one-song tutorial as for
## a three-song set, which made the tutorial the best-value thing in the game
## and is not what "clearing a chapter" is worth.
const STORY_BONUS_PER_SONG := 15
## Every clear after the first.
const REPEAT_SHARE := 0.5

## How much of it a rank actually collects. A D is a pass, but only just.
const BY_RANK := {
	"SS": 1.00, "S": 0.88, "A": 0.72, "B": 0.55, "C": 0.38, "D": 0.20,
}


static func story_bonus(song_count: int) -> int:
	return STORY_BONUS_PER_SONG * maxi(song_count, 1)


## What a finished run pays. Zero for anything that is not one of ours, for a
## replay, for a run that was lost, and for a chart the player wrote.
static func for_run(official: bool, rank: String, diff_index: int,
		diff_count: int, first_time: bool) -> int:
	if not official or Judge.failed(rank):
		return 0
	var share: float = float(BY_RANK.get(rank, 0.0))
	if share <= 0.0:
		return 0
	var hardness := 0.0 if diff_count < 2 else \
		float(clampi(diff_index, 0, diff_count - 1)) / float(diff_count - 1)
	var base := lerpf(BASE_EASIEST, BASE_HARDEST, hardness)
	if not first_time:
		base *= REPEAT_SHARE
	return int(round(base * share))


## The key a clear is remembered under, so a second clear of the same chart
## knows it is a second one.
static func key_for(song_id: String, diff_name: String) -> String:
	return "%s|%s" % [song_id, diff_name]


## What the records already in the save are worth, paid once.
##
## Somebody who has been playing since before coins existed should not start at
## zero, and somebody who opened the game twice should not be handed a
## wardrobe. So the backlog is paid at the same rates as a first clear, off the
## rank that is actually stored against each record - which is exactly as
## generous as the play that earned it was.
static func backlog(best: Dictionary, songs: Array) -> Dictionary:
	var total := 0
	var keys: Dictionary = {}
	for song in songs:
		if RhythmMap.is_user_song(song):
			continue
		var sid := str(song.get("id", ""))
		if not best.has(sid):
			continue
		var entry = best[sid]
		if not (entry is Dictionary):
			continue
		var diffs := RhythmMap.diffs_of(song)
		for i in diffs.size():
			var dname := str(diffs[i].get("name", ""))
			if not (entry as Dictionary).has(dname):
				continue
			var rec = (entry as Dictionary)[dname]
			if not (rec is Dictionary):
				continue
			var rank := str((rec as Dictionary).get("rank", ""))
			if rank == "":
				rank = Judge.rank_for(float((rec as Dictionary).get("acc", 0.0)))
			var paid := for_run(true, rank, i, diffs.size(), true)
			if paid > 0:
				total += paid
				keys[key_for(sid, dname)] = true
	return {"coins": total, "keys": keys}
