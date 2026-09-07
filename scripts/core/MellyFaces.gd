class_name MellyFaces
extends RefCounted
## The faces Melly wears while talking, drawn rather than painted.
##
## Four faces ship as textures - idle, happy, very, sad - and they are the
## reactions the game already had: a hit, a miss, a win. A conversation needs
## more than that and needs them to mean different things, so the rest are
## built here in the same hand: two dots and a mouth, dark brown on nothing,
## on the same 256-square grid the drawn ones use.
##
## Made in code because they are two dots and a mouth. An expression that turns
## out wrong is a number here rather than a round trip through an image editor,
## and there is no fifth file to keep in step with the other four.

const SIZE := 256
const SS := 3                       # drawn this many times over, then averaged
const INK := Color(0.161, 0.082, 0.094)

## Where the features sit, measured off the shipped faces so a new expression
## lines up with an old one when they are swapped mid-sentence.
const EYE_L := Vector2(76.0, 90.0)
const EYE_R := Vector2(180.0, 90.0)
const EYE_R_PX := 18.0
const MOUTH_Y := 166.0
const MOUTH_HALF := 57.0

static var _cache := {}


## The face for a name, drawn once and kept.
static func get_face(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img := Image.create(SIZE * SS, SIZE * SS, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	_draw(img, kind)
	# drawn large and shrunk: the engine's resize averages, which is what makes
	# a hand-plotted circle come out with a soft edge instead of a staircase
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func _draw(img: Image, kind: String) -> void:
	match kind:
		"talk":
			_eye_dot(img, EYE_L)
			_eye_dot(img, EYE_R)
			_mouth_open(img, 0.62, 30.0)
		"think":
			# eyes up and to one side, the way a thought looks
			_eye_dot(img, EYE_L + Vector2(6, -12))
			_eye_dot(img, EYE_R + Vector2(6, -12))
			_mouth_bar(img, 0.5, 8.0)
		"surprised":
			_eye_ring(img, EYE_L, 24.0)
			_eye_ring(img, EYE_R, 24.0)
			_mouth_open(img, 0.34, 44.0)
		"smug":
			_eye_bar(img, EYE_L, 20.0)
			_eye_bar(img, EYE_R, 20.0)
			_smirk(img)
		"flat":
			_eye_dot(img, EYE_L)
			_eye_dot(img, EYE_R)
			_mouth_bar(img, 0.72, 10.0)
		"wink":
			_eye_bar(img, EYE_L, 20.0)
			_eye_dot(img, EYE_R)
			_curve(img, MOUTH_HALF * 0.86, 26.0, 11.0)
		_:
			_eye_dot(img, EYE_L)
			_eye_dot(img, EYE_R)
			_mouth_bar(img, 1.0, 10.0)


# ---------------------------------------------------------------- features
static func _eye_dot(img: Image, at: Vector2) -> void:
	_disc(img, at, EYE_R_PX)


## A wide open eye: a ring, so surprise reads as the eye getting bigger rather
## than as a bigger blob.
static func _eye_ring(img: Image, at: Vector2, r: float) -> void:
	_disc(img, at, r)
	_disc(img, at, r * 0.46, true)


## A closed or narrowed eye.
static func _eye_bar(img: Image, at: Vector2, half: float) -> void:
	_rod(img, at + Vector2(-half, 0), at + Vector2(half, 0), 7.0)


static func _mouth_bar(img: Image, span: float, thick: float) -> void:
	var half := MOUTH_HALF * span
	_rod(img, Vector2(SIZE * 0.5 - half, MOUTH_Y),
		Vector2(SIZE * 0.5 + half, MOUTH_Y), thick * 0.5)


## An open mouth: a filled oval, which is what all four shipped faces use for
## anything other than a line.
static func _mouth_open(img: Image, span: float, height: float) -> void:
	var rx := MOUTH_HALF * span
	var ry := height * 0.5
	var c := Vector2(SIZE * 0.5, MOUTH_Y + 2.0)
	_ellipse(img, c, rx, ry)


## Up at one end, down at the other.
static func _smirk(img: Image) -> void:
	var y := MOUTH_Y
	var pts: Array[Vector2] = []
	for i in 25:
		var t: float = float(i) / 24.0
		var x: float = lerpf(-MOUTH_HALF * 0.8, MOUTH_HALF * 0.8, t)
		pts.append(Vector2(SIZE * 0.5 + x, y - 16.0 * t * t))
	for i in pts.size() - 1:
		_rod(img, pts[i], pts[i + 1], 5.5)


## A smile, as an arc struck below the eyes.
static func _curve(img: Image, half: float, drop: float, thick: float) -> void:
	var pts: Array[Vector2] = []
	for i in 33:
		var t: float = float(i) / 32.0
		var x: float = lerpf(-half, half, t)
		pts.append(Vector2(SIZE * 0.5 + x, MOUTH_Y - 10.0 + drop * sin(PI * t)))
	for i in pts.size() - 1:
		_rod(img, pts[i], pts[i + 1], thick * 0.5)


# ---------------------------------------------------------------- plotting
static func _disc(img: Image, at: Vector2, r: float, erase := false) -> void:
	_ellipse(img, at, r, r, erase)


static func _ellipse(img: Image, at: Vector2, rx: float, ry: float, erase := false) -> void:
	var c := at * SS
	var ax := rx * SS
	var ay := ry * SS
	var col: Color = Color(1, 1, 1, 0) if erase else INK
	var x0 := maxi(0, int(c.x - ax) - 1)
	var x1 := mini(img.get_width() - 1, int(c.x + ax) + 1)
	var y0 := maxi(0, int(c.y - ay) - 1)
	var y1 := mini(img.get_height() - 1, int(c.y + ay) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = (x + 0.5 - c.x) / ax
			var dy: float = (y + 0.5 - c.y) / ay
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


## A line with round ends, which is every mouth and every narrowed eye.
static func _rod(img: Image, a: Vector2, b: Vector2, r: float) -> void:
	var pa := a * SS
	var pb := b * SS
	var rr := r * SS
	var d := pb - pa
	var len2: float = maxf(d.length_squared(), 0.0001)
	var x0 := maxi(0, int(minf(pa.x, pb.x) - rr) - 1)
	var x1 := mini(img.get_width() - 1, int(maxf(pa.x, pb.x) + rr) + 1)
	var y0 := maxi(0, int(minf(pa.y, pb.y) - rr) - 1)
	var y1 := mini(img.get_height() - 1, int(maxf(pa.y, pb.y) + rr) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - pa).dot(d) / len2, 0.0, 1.0)
			if p.distance_to(pa + d * t) <= rr:
				img.set_pixel(x, y, INK)
