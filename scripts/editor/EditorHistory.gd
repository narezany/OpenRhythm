class_name EditorHistory
extends RefCounted
## Undo/redo for the map editor. Snapshots of the whole note list: a chart is
## small enough that snapshotting is simpler and far harder to get wrong than
## per-operation inverse commands.

const LIMIT := 80

var _undo: Array = []
var _redo: Array = []
var _label: Array = []


## Call before mutating the notes. `label` shows up in the status line.
func push(notes: Array, label := "") -> void:
	_undo.append(_snapshot(notes))
	_label.append(label)
	if _undo.size() > LIMIT:
		_undo.pop_front()
		_label.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## Returns the restored note list, or an empty array when there is nothing left.
func undo(current: Array) -> Array:
	if _undo.is_empty():
		return []
	_redo.append(_snapshot(current))
	if not _label.is_empty():
		_label.pop_back()
	return _undo.pop_back()


func redo(current: Array) -> Array:
	if _redo.is_empty():
		return []
	_undo.append(_snapshot(current))
	return _redo.pop_back()


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_label.clear()


## Plain data only - view nodes must never end up inside a snapshot.
static func _snapshot(notes: Array) -> Array:
	var out: Array = []
	for n in notes:
		out.append({
			"t": float(n.get("t", 0.0)),
			"cell": int(n.get("cell", 4)),
			"s": float(n.get("s", 1.0)),
			"h": float(n.get("h", 0.0)),
			"c": bool(n.get("c", false)),
		})
	return out
