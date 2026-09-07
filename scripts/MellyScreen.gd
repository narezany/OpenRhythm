class_name MellyScreen
extends Control
## Melly's own screen: what they look like and what they are wearing.
##
## The colours used to live at the bottom of the settings, as six rows of
## sixteen swatches with no way to see what you were doing - ninety-six squares
## and a thumbnail. The choice is the same choice; what was missing was being
## able to look at it. So: Melly big on the left, one body part chosen at a
## time on the right, and a palette that fills the panel instead of a strip.
##
## The wardrobe shares the screen because it is the same question - what does
## Melly look like - and because a shop nobody can find is a shop nobody uses.

const PALETTE := [
	"f2e8e4", "d7ccc6", "8a8a92", "4a4a52", "26262b", "1a1a1d",
	"ff2b3a", "9c1022", "ff6fa8", "b04ad9", "8a3fd1", "5a2ea6",
	"ff7a45", "ffb547", "ffd23f", "9ade3b", "46c46e", "2ec4b6",
	"4a7dff", "27408b", "7a4a2a", "3f2a1e", "e8c8a0", "ffffff",
]

var _rig: MellyRig
var _part := "torso"
var _part_btns := {}
var _coin_lbl: Label
var _wardrobe: GridContainer
var _tab := "paint"
var _paint_panel: Control
var _shop_panel: Control
var _toast: Label


func _ready() -> void:
	G.anchor_full(self)
	add_child(BackgroundFX.new(true))

	var title := G.label("MELLY", 42, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 24, 54)

	_coin_lbl = G.label("", 26, G.C_GOLD, true)
	_coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_coin_lbl)
	G.anchor_corner(_coin_lbl, true, false, 26, 26, Vector2(260, 34))
	_refresh_coins()

	# Melly, big, on the left - the whole point is seeing the change
	_rig = MellyRig.new()
	_rig.size = Vector2(430, 470)
	_rig.position = Vector2(84, 120)
	add_child(_rig)
	_rig.set_mood("happy", 0.0)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	tabs.position = Vector2(560, 96)
	for t in [["paint", "COLOURS"], ["shop", "WARDROBE"]]:
		var id := str(t[0])
		var b := G.button(str(t[1]), func(): _switch(id), 22)
		b.custom_minimum_size = Vector2(180, 0)
		tabs.add_child(b)

	_paint_panel = _build_paint()
	_shop_panel = _build_shop()
	_switch("paint")

	_toast = G.label("", 19, G.C_GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)
	G.anchor_bottom_wide(_toast, 96, 28, 120)

	var back := G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_menu(), 22)
	add_child(back)
	G.anchor_corner(back, false, true, 30, 34, Vector2(180, 46))
	Conductor.ensure_menu_music()


func _switch(tab: String) -> void:
	_tab = tab
	G.play_sfx("click", 1.2, -8.0)
	_paint_panel.visible = tab == "paint"
	_shop_panel.visible = tab == "shop"


# ---------------------------------------------------------------- colours
func _build_paint() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	G.anchor_margins(root, 560, 150, 60, 110)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	root.add_child(vb)
	G.anchor_full(vb)

	vb.add_child(G.label("Which part", 18, G.C_MUTED))
	var parts := HBoxContainer.new()
	parts.add_theme_constant_override("separation", 6)
	vb.add_child(parts)
	for part in MellyRig.PARTS:
		var id := str(part)
		var b := G.button(str(MellyRig.PART_NAMES[part]), func(): _pick_part(id), 15)
		b.custom_minimum_size = Vector2(96, 38)
		parts.add_child(b)
		_part_btns[id] = b

	vb.add_child(G.label("Colour", 18, G.C_MUTED))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for hex in PALETTE:
		grid.add_child(_swatch(str(hex)))

	var note := G.label("Everything here is free. The wardrobe is not.", 15, G.C_MUTED)
	vb.add_child(note)
	_pick_part(_part)
	return root


func _pick_part(part: String) -> void:
	_part = part
	for id in _part_btns:
		var b: Button = _part_btns[id]
		b.add_theme_color_override("font_color",
			G.C_GOLD if id == part else G.C_MUTED)


func _swatch(hex: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 44)
	var col := Color(hex)
	var rect := ColorRect.new()
	rect.color = col
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 4
	rect.offset_top = 4
	rect.offset_right = -4
	rect.offset_bottom = -4
	b.add_child(rect)
	b.pressed.connect(func():
		G.play_sfx("click", 1.3, -10.0)
		G.melly_colors[_part] = col
		G.save_all()
		Achievements.unlock("melly_paint")
		if _rig != null and is_instance_valid(_rig):
			_rig.apply_colors())
	return b


# ---------------------------------------------------------------- wardrobe
func _build_shop() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	G.anchor_margins(root, 560, 150, 60, 110)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	G.anchor_full(scroll)
	DragScroll.attach(scroll)

	_wardrobe = GridContainer.new()
	_wardrobe.columns = 2
	_wardrobe.add_theme_constant_override("h_separation", 12)
	_wardrobe.add_theme_constant_override("v_separation", 12)
	_wardrobe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_wardrobe)
	_fill_shop()
	return root


func _fill_shop() -> void:
	for c in _wardrobe.get_children():
		c.queue_free()
	for item in MellyShop.ITEMS:
		_wardrobe.add_child(_shop_card(item))


func _shop_card(item: Dictionary) -> PanelContainer:
	var id := str(item.id)
	var owned: bool = G.melly_owned.has(id)
	var worn: bool = str(G.melly_worn.get(str(item.slot), "")) == id
	var edge: Color = G.C_GOLD if worn else (G.C_PRIMARY if owned else Color(0.5, 0.45, 0.5))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.panel_style(
		Color(edge.r, edge.g, edge.b, 0.7 if owned else 0.3)))
	p.custom_minimum_size = Vector2(0, 112)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	vb.add_child(G.label(str(item.name), 21, G.C_TEXT if owned else G.C_MUTED, true))
	var d := G.label(str(item.desc), 14, G.C_MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	if not owned:
		vb.add_child(G.label("%d coins" % int(item.price), 17, G.C_GOLD))
	var b := G.button(("WORN" if worn else ("WEAR" if owned else "BUY")), func():
		_act_on(id), 17)
	vb.add_child(b)
	return p


## Buy it if it is not owned, wear it if it is, take it off if it is on.
func _act_on(id: String) -> void:
	var item := MellyShop.def_of(id)
	if item.is_empty():
		return
	var slot := str(item.slot)
	if not G.melly_owned.has(id):
		if not G.spend_coins(int(item.price)):
			G.play_sfx("miss", 1.0, -6.0)
			_say("Not enough coins — play the game's own songs to earn them.")
			return
		G.melly_owned[id] = true
		G.melly_worn[slot] = id
		G.play_sfx("click", 1.4)
		_say("%s bought and put on." % tr(str(item.name)))
	elif str(G.melly_worn.get(slot, "")) == id:
		G.melly_worn[slot] = ""
		G.play_sfx("click", 0.9, -8.0)
	else:
		G.melly_worn[slot] = id
		G.play_sfx("click", 1.2)
	G.save_all()
	_refresh_coins()
	_fill_shop()
	if _rig != null and is_instance_valid(_rig):
		_rig.wear_accessories()


func _refresh_coins() -> void:
	if _coin_lbl != null and is_instance_valid(_coin_lbl):
		_coin_lbl.text = "%d ◆" % G.coins


func _say(text: String) -> void:
	if _toast == null or not is_instance_valid(_toast):
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func go_back() -> void:
	G.main.goto_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
