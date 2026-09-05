class_name Binds
extends RefCounted
## Rebindable input actions, registered into InputMap at runtime so the map is
## never out of sync with the save file. Gamepad events are attached alongside
## the keyboard ones and are not rebindable from the UI yet.

const CURSOR_LEFT := "or_cursor_left"
const CURSOR_RIGHT := "or_cursor_right"
const CURSOR_UP := "or_cursor_up"
const CURSOR_DOWN := "or_cursor_down"
const PAUSE := "or_pause"
const RESTART := "or_restart"
const SKIP := "or_skip"
const HIT := "or_hit"

## label: shown in the rebind UI. keys: default keycodes. pad: gamepad buttons.
const ACTIONS := {
	CURSOR_LEFT: {"label": "Cursor left", "keys": [KEY_A, KEY_LEFT]},
	CURSOR_RIGHT: {"label": "Cursor right", "keys": [KEY_D, KEY_RIGHT]},
	CURSOR_UP: {"label": "Cursor up", "keys": [KEY_W, KEY_UP]},
	CURSOR_DOWN: {"label": "Cursor down", "keys": [KEY_S, KEY_DOWN]},
	PAUSE: {"label": "Pause", "keys": [KEY_ESCAPE], "pad": [JOY_BUTTON_START]},
	RESTART: {"label": "Restart", "keys": [KEY_R], "pad": [JOY_BUTTON_Y]},
	SKIP: {"label": "Skip intro", "keys": [KEY_SPACE], "pad": [JOY_BUTTON_X]},
	HIT: {"label": "Confirm / advance", "keys": [KEY_ENTER, KEY_SPACE], "pad": [JOY_BUTTON_A]},
}

## The left stick is read straight from the axes in UICursor, with a radial
## deadzone. Binding it to the four cursor actions as well would double-count a
## resting stick and pull the cursor in whichever direction it drifts.
const STICK_DEADZONE := 0.28


## Rebuild every action from defaults plus the player's overrides.
## overrides: {action_name: [keycode, ...]}
static func apply(overrides: Dictionary) -> void:
	for name in ACTIONS:
		var cfg: Dictionary = ACTIONS[name]
		if not InputMap.has_action(name):
			InputMap.add_action(name, 0.2)
		InputMap.action_erase_events(name)
		var keys: Array = overrides.get(name, cfg.get("keys", []))
		for kc in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(kc)
			InputMap.action_add_event(name, ev)
		for btn in cfg.get("pad", []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(btn)
			InputMap.action_add_event(name, jb)
	# Esc, the gamepad B button and the Android hardware back key all mean
	# "back" everywhere in the UI.
	if InputMap.has_action("ui_cancel"):
		var has_b := false
		var has_back := false
		for ev in InputMap.action_get_events("ui_cancel"):
			if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_B:
				has_b = true
			if ev is InputEventKey and ev.physical_keycode == KEY_BACK:
				has_back = true
		if not has_b:
			var b := InputEventJoypadButton.new()
			b.button_index = JOY_BUTTON_B
			InputMap.action_add_event("ui_cancel", b)
		if not has_back:
			var k := InputEventKey.new()
			k.physical_keycode = KEY_BACK
			InputMap.action_add_event("ui_cancel", k)


static func default_keys(action: String) -> Array:
	return ACTIONS.get(action, {}).get("keys", [])


static func label_of(action: String) -> String:
	return str(ACTIONS.get(action, {}).get("label", action))


## Human-readable list of the keys currently bound to an action.
static func keys_text(overrides: Dictionary, action: String) -> String:
	var keys: Array = overrides.get(action, default_keys(action))
	var parts: PackedStringArray = []
	for kc in keys:
		parts.append(OS.get_keycode_string(int(kc)))
	return " / ".join(parts) if parts.size() > 0 else "—"
