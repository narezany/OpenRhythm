class_name MellyShop
extends RefCounted
## Melly's wardrobe: what there is, what it costs, and what it is made of.
##
## Every item is built out of primitives in code, the way the achievement
## badges and the mode icons are. That is not thrift - it is so an item can be
## added in one place, scales to any resolution, and cannot arrive as a texture
## that does not match the four faces and the blocky body it has to sit on.
##
## Positions are offsets from a bone of the model, in model units. The head
## bone sits at y 4.0 and the head runs to 5.33; the torso bone is at y 2.0 and
## the shoulders are at 3.88. Anything that has to sit on top of the head is
## about 1.3 above its bone.

const SLOTS := ["head", "face", "neck", "back", "arm"]

## bone: 0 torso, 1 head. Prices are in purple coins - see Coins for what a
## clear is worth: the cheapest thing here is about ten clears of a hard chart
## at a rank worth having, and the dearest is a season of them. That is on
## purpose - a wardrobe you can buy out in an evening is not a reward.
const ITEMS := [
	{"id": "cap", "name": "Cap", "slot": "head", "bone": 1, "price": 300,
	 "desc": "A soft cap, worn straight."},
	{"id": "horns", "name": "Little horns", "slot": "head", "bone": 1, "price": 520,
	 "desc": "Not load-bearing."},
	{"id": "headphones", "name": "Headphones", "slot": "head", "bone": 1, "price": 620,
	 "desc": "For hearing the beat you keep missing."},
	{"id": "halo", "name": "Halo", "slot": "head", "bone": 1, "price": 760,
	 "desc": "Floats. Does not judge."},
	{"id": "crown", "name": "Crown", "slot": "head", "bone": 1, "price": 860,
	 "desc": "Heavy is the head."},
	{"id": "glasses", "name": "Glasses", "slot": "face", "bone": 1, "price": 340,
	 "desc": "For reading charts."},
	{"id": "shades", "name": "Shades", "slot": "face", "bone": 1, "price": 460,
	 "desc": "For not reading anything."},
	{"id": "scarf", "name": "Scarf", "slot": "neck", "bone": 0, "price": 380,
	 "desc": "Long enough to mean it."},
	{"id": "bowtie", "name": "Bow tie", "slot": "neck", "bone": 0, "price": 430,
	 "desc": "Formal, for a cube game."},
	{"id": "cape", "name": "Cape", "slot": "back", "bone": 0, "price": 980,
	 "desc": "It does nothing. It is a cape."},
	{"id": "dutch_band", "name": "Dutch armband", "slot": "arm", "bone": 2,
	 "price": 1500, "desc": "Red, white and blue, worn high on the arm."},
]


static func def_of(id: String) -> Dictionary:
	for it in ITEMS:
		if str(it.id) == id:
			return it
	return {}


static func in_slot(slot: String) -> Array:
	var out: Array = []
	for it in ITEMS:
		if str(it.slot) == slot:
			out.append(it)
	return out


## The item as a node, ready to be hung off its bone.
static func build(id: String) -> Node3D:
	match id:
		"cap": return _cap()
		"horns": return _horns()
		"headphones": return _headphones()
		"halo": return _halo()
		"crown": return _crown()
		"glasses": return _glasses(Color(0.16, 0.15, 0.18), 0.55)
		"shades": return _glasses(Color(0.04, 0.03, 0.05), 0.95)
		"scarf": return _scarf()
		"bowtie": return _bowtie()
		"cape": return _cape()
		"dutch_band": return _armband()
	return null


# ---------------------------------------------------------------- the items
static func _cap() -> Node3D:
	var root := Node3D.new()
	var crown := _box(Vector3(1.34, 0.34, 1.30), Color("2b3a8f"))
	crown.position = Vector3(0, 1.44, 0)
	root.add_child(crown)
	var peak := _box(Vector3(1.20, 0.10, 0.62), Color("1d2a6b"))
	peak.position = Vector3(0, 1.30, 0.86)
	root.add_child(peak)
	var button := _sphere(0.11, Color("f2e8e4"))
	button.position = Vector3(0, 1.62, 0)
	root.add_child(button)
	return root


static func _horns() -> Node3D:
	var root := Node3D.new()
	for side in [-1.0, 1.0]:
		var h := _cone(0.20, 0.52, Color("b03a4a"))
		h.position = Vector3(0.42 * side, 1.46, 0.0)
		h.rotation_degrees = Vector3(0, 0, -16.0 * side)
		root.add_child(h)
	return root


static func _headphones() -> Node3D:
	var root := Node3D.new()
	var band := _torus(0.70, 0.80, Color("26262b"))
	band.position = Vector3(0, 1.20, 0)
	band.rotation_degrees = Vector3(90, 0, 0)   # stand the ring up over the head
	root.add_child(band)
	for side in [-1.0, 1.0]:
		var cup := _cylinder(0.30, 0.22, Color("3a3a42"))
		cup.position = Vector3(0.78 * side, 0.72, 0)
		cup.rotation_degrees = Vector3(0, 0, 90)
		root.add_child(cup)
	return root


static func _halo() -> Node3D:
	var root := Node3D.new()
	var ring := _torus(0.44, 0.56, Color("ffd23f"))
	ring.position = Vector3(0, 1.86, 0)
	root.add_child(ring)
	# unshaded, so it reads as light rather than as a gold hoop
	var m := ring.material_override as StandardMaterial3D
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color("ffd23f")
	return root


static func _crown() -> Node3D:
	var root := Node3D.new()
	var band := _cylinder(0.74, 0.26, Color("ffd23f"))
	band.position = Vector3(0, 1.42, 0)
	root.add_child(band)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var spike := _cone(0.14, 0.34, Color("ffd23f"))
		spike.position = Vector3(cos(a) * 0.62, 1.68, sin(a) * 0.62)
		root.add_child(spike)
	return root


static func _glasses(tint: Color, opacity: float) -> Node3D:
	var root := Node3D.new()
	for side in [-1.0, 1.0]:
		var lens := _box(Vector3(0.46, 0.32, 0.06), tint)
		lens.position = Vector3(0.30 * side, 0.72, 0.74)
		var m := lens.material_override as StandardMaterial3D
		m.albedo_color.a = opacity
		if opacity < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		root.add_child(lens)
	var bridge := _box(Vector3(0.18, 0.06, 0.05), tint)
	bridge.position = Vector3(0, 0.72, 0.74)
	root.add_child(bridge)
	for side in [-1.0, 1.0]:
		var arm := _box(Vector3(0.06, 0.05, 0.52), tint)
		arm.position = Vector3(0.54 * side, 0.72, 0.48)
		root.add_child(arm)
	return root


static func _scarf() -> Node3D:
	var root := Node3D.new()
	# A torus lies flat by default, which is exactly how a scarf goes round a
	# neck. Standing it on its edge - which is what it was doing - makes a hoop
	# through the shoulders instead, and sized to clear the head it read as a
	# horseshoe somebody had put on backwards.
	var wrap := _torus(0.40, 0.62, Color("c0392b"))
	wrap.position = Vector3(0, 1.92, 0)
	root.add_child(wrap)
	var tail := _box(Vector3(0.30, 1.10, 0.14), Color("a5322a"))
	tail.position = Vector3(0.34, 1.36, 0.52)
	tail.rotation_degrees = Vector3(0, 0, 7)
	root.add_child(tail)
	return root


static func _bowtie() -> Node3D:
	var root := Node3D.new()
	for side in [-1.0, 1.0]:
		var wing := _cone(0.22, 0.34, Color("9c1022"))
		wing.position = Vector3(0.22 * side, 1.78, 0.66)
		wing.rotation_degrees = Vector3(90, 0, 90.0 * side)
		root.add_child(wing)
	var knot := _box(Vector3(0.14, 0.16, 0.14), Color("6d0b17"))
	knot.position = Vector3(0, 1.78, 0.70)
	root.add_child(knot)
	return root


static func _cape() -> Node3D:
	var root := Node3D.new()
	# wider than the body, or a cape is a thing you can only see from behind
	var cloth := _box(Vector3(2.16, 1.95, 0.10), Color("6d1030"))
	cloth.position = Vector3(0, 0.92, -0.58)
	cloth.rotation_degrees = Vector3(-7, 0, 0)
	root.add_child(cloth)
	var collar := _box(Vector3(1.42, 0.22, 0.30), Color("8e1740"))
	collar.position = Vector3(0, 1.88, -0.30)
	root.add_child(collar)
	return root


## Three stripes round the upper arm.
##
## The bone is not in the middle of the limb it drives: measured off the mesh,
## the left arm's vertices run from x 0.791 to 1.629 - centre 1.210 - while the
## bone sits at 1.000. A band centred on the bone therefore hangs off the inside
## edge of the arm, which is exactly what it was doing. The offset below is that
## difference, and the radius is a little wider than the arm is thick so the
## band wraps it rather than sinking into it.
const ARM_OFFSET := 0.21
const ARM_RADIUS := 0.47

static func _armband() -> Node3D:
	var root := Node3D.new()
	var stripes := [Color("ae1c28"), Color("ffffff"), Color("21468b")]
	for i in stripes.size():
		var band := _cylinder(ARM_RADIUS, 0.12, stripes[i])
		band.position = Vector3(ARM_OFFSET, -0.44 - 0.12 * float(i), 0)
		root.add_child(band)
	return root


# ---------------------------------------------------------------- shapes
static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.72
	return m


static func _box(size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	return mi


static func _sphere(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _mat(c)
	return mi


static func _cone(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = _mat(c)
	return mi


static func _cylinder(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = _mat(c)
	return mi


static func _torus(inner: float, outer: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	mi.mesh = tm
	mi.material_override = _mat(c)
	return mi
