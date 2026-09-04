class_name Judge
extends RefCounted
## Judgement: the rank comes from WHERE inside the cell the cursor sits when the
## cube lands, not from timing. A cube does not wait - miss it on landing and
## it is gone. Hold notes add a second stage: stay in the cell for their length.

const LEAD := 0.06          # a cube may be taken slightly before it lands
const LAND_GRACE := 0.15    # how long a landed cube waits before it counts as a miss

# Zone thresholds on p_acc (1 at the cell centre, 0 at the edge of the catch zone).
# Generous on purpose: PERFECT covers more than half the cell.
const P_PERFECT := 0.52
const P_GREAT := 0.26
const P_GOOD := 0.10
# below GOOD is BULLSHIT: caught, but only just

## While holding, the cursor may drift this much further than the catch zone
## before the hold breaks.
const HOLD_SLACK := 1.55

const ACC_FLOOR := {
	"PERFECT": 0.90, "GREAT": 0.65, "GOOD": 0.35, "BULLSHIT": 0.08,
}


static func pos_acc(cursor_local: Vector2, hit: Vector2, half: float) -> float:
	# zones are wider on a phone - a finger is less precise than a mouse
	var k := 1.45 if _mobile() else 1.0
	return 1.0 - clampf(cursor_local.distance_to(hit) / (half * 1.35 * k), 0.0, 1.0)


static func _mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("ios")


## True while the cursor is still close enough to keep a hold alive.
static func holding(cursor_local: Vector2, hit: Vector2, half: float) -> bool:
	var k := 1.45 if _mobile() else 1.0
	return cursor_local.distance_to(hit) <= half * 1.35 * k * HOLD_SLACK


## Accuracy: almost entirely the zone, with a small bonus for landing on time.
static func acc_for(dt: float, p_acc: float) -> float:
	var t_bonus := 1.0 - clampf(absf(dt) / LAND_GRACE, 0.0, 1.0)
	return clampf(p_acc * 0.92 + t_bonus * 0.08, 0.0, 1.0)


## A hold is worth its landing accuracy weighted by how much of it was held.
static func hold_acc(base_acc: float, held_frac: float) -> float:
	return clampf(base_acc * (0.4 + 0.6 * clampf(held_frac, 0.0, 1.0)), 0.0, 1.0)


## Rank from the hit zone alone.
static func label_for(_dt: float, p_acc: float) -> String:
	if p_acc >= P_PERFECT:
		return "PERFECT"
	if p_acc >= P_GREAT:
		return "GREAT"
	if p_acc >= P_GOOD:
		return "GOOD"
	return "BULLSHIT"


## Drop a hold's rank by one step when a good chunk of it was dropped.
static func degrade(label: String, held_frac: float) -> String:
	if held_frac >= 0.9:
		return label
	match label:
		"PERFECT": return "GREAT" if held_frac >= 0.5 else "GOOD"
		"GREAT": return "GOOD" if held_frac >= 0.5 else "BULLSHIT"
		"GOOD": return "BULLSHIT"
	return label


static func rank_for(acc: float) -> String:
	if acc >= 0.95:
		return "SS"
	if acc >= 0.90:
		return "S"
	if acc >= 0.80:
		return "A"
	if acc >= 0.70:
		return "B"
	if acc >= 0.60:
		return "C"
	return "D"


static func rank_color(rank: String) -> Color:
	match rank:
		"SS": return Color("ffd700")
		"S": return Color("ff2b3a")
		"A": return Color("ff7a45")
		"B": return Color("ffb547")
		"C": return Color("c9584f")
		_: return Color("8d96a0")
