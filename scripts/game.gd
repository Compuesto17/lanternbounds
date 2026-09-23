extends Node
##
## Global game state for Lanternbound: The Last Light.
## Registered as the autoload singleton "Game" (see project.godot).
##

signal health_changed(current: int, maximum: int)
signal energy_changed(current: float, maximum: float)
signal fragments_changed(collected: int, total: int)
signal lantern_changed(type: int)
signal player_died
signal level_completed
signal toast(text: String)

enum Lantern { WARM, SPIRIT, FIRE }

const SAVE_PATH := "user://lanternbound.save"

# Each lantern type trades radius, energy cost and burn power against each other.
const LANTERN_DATA := {
	Lantern.WARM: {
		"name": "Warm Lantern",
		"color": Color(1.0, 0.78, 0.42),
		"radius": 195.0,
		"drain": 9.0,
		"reveal": true,
		"burn": 0.7,
	},
	Lantern.SPIRIT: {
		"name": "Spirit Lantern",
		"color": Color(0.55, 0.86, 1.0),
		"radius": 275.0,
		"drain": 15.0,
		"reveal": true,
		"burn": 0.15,
	},
	Lantern.FIRE: {
		"name": "Fire Lantern",
		"color": Color(1.0, 0.46, 0.20),
		"radius": 150.0,
		"drain": 17.0,
		"reveal": false,
		"burn": 2.4,
	},
}

# ---------------------------------------------------------------- run state
var max_health := 4
var health := 4
var max_energy := 100.0
var energy := 100.0
var lantern_type: int = Lantern.WARM
var unlocked_lanterns := [Lantern.WARM]

var current_level := 0
var checkpoint_index := -1
var collected_fragments := {}      # "level:id" -> true
var level_fragment_total := 0

# Live lantern info, written by the player every frame and read by anything
# that cares about light (hidden platforms, shadow enemies, runes...).
var lantern_on := false
var lantern_pos := Vector2.ZERO
var lantern_radius := 0.0
var lantern_reveals := false
var lantern_burn := 0.0

var settings := {
	"music": 0.7,
	"sfx": 0.8,
	"brightness": 1.0,
	"fullscreen": false,
}


func _ready() -> void:
	_setup_input()
	_load_settings()


# ---------------------------------------------------------------- input map
func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("jump", [KEY_SPACE, KEY_Z])
	_bind("run", [KEY_SHIFT])
	_bind("lantern", [KEY_F])
	_bind("focus_beam", [KEY_R])
	_bind("interact", [KEY_E])
	_bind("cycle_lantern", [KEY_TAB, KEY_Q])
	_bind("pause", [KEY_ESCAPE, KEY_P])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- lantern
func lantern_info() -> Dictionary:
	return LANTERN_DATA[lantern_type]


func set_lantern(type: int) -> void:
	if not unlocked_lanterns.has(type):
		return
	lantern_type = type
	lantern_changed.emit(type)
	toast.emit(str(LANTERN_DATA[type]["name"]) + " equipped")


func cycle_lantern() -> void:
	if unlocked_lanterns.size() <= 1:
		return
	var i := unlocked_lanterns.find(lantern_type)
	i = (i + 1) % unlocked_lanterns.size()
	set_lantern(unlocked_lanterns[i])


func unlock_lantern(type: int) -> void:
	if not unlocked_lanterns.has(type):
		unlocked_lanterns.append(type)
		toast.emit("Unlocked: " + str(LANTERN_DATA[type]["name"]))


func is_lit(world_pos: Vector2, slack: float = 0.0) -> bool:
	if not lantern_on:
		return false
	return lantern_pos.distance_to(world_pos) <= lantern_radius + slack


func reveals_at(world_pos: Vector2) -> bool:
	return lantern_reveals and is_lit(world_pos)


# ---------------------------------------------------------------- resources
func spend_energy(amount: float) -> bool:
	if energy <= 0.0:
		return false
	energy = max(0.0, energy - amount)
	energy_changed.emit(energy, max_energy)
	return true


func restore_energy(amount: float) -> void:
	energy = min(max_energy, energy + amount)
	energy_changed.emit(energy, max_energy)


func damage(amount: int) -> void:
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		player_died.emit()


func heal_full() -> void:
	health = max_health
	energy = max_energy
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)


# ---------------------------------------------------------------- fragments
func fragment_key(id: String) -> String:
	return str(current_level) + ":" + id


func has_fragment(id: String) -> bool:
	return collected_fragments.has(fragment_key(id))


func collect_fragment(id: String) -> void:
	collected_fragments[fragment_key(id)] = true
	fragments_changed.emit(fragments_in_level(), level_fragment_total)
	toast.emit("Memory Fragment recovered")


func fragments_in_level() -> int:
	var n := 0
	var prefix := str(current_level) + ":"
	for k in collected_fragments.keys():
		if str(k).begins_with(prefix):
			n += 1
	return n


func total_fragments() -> int:
	return collected_fragments.size()


# ---------------------------------------------------------------- new game
func new_game() -> void:
	health = max_health
	energy = max_energy
	lantern_type = Lantern.WARM
	unlocked_lanterns = [Lantern.WARM]
	current_level = 0
	checkpoint_index = -1
	collected_fragments.clear()


# ---------------------------------------------------------------- save/load
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var payload := {
		"level": current_level,
		"checkpoint": checkpoint_index,
		"health": health,
		"energy": energy,
		"lantern": lantern_type,
		"unlocked": unlocked_lanterns,
		"fragments": collected_fragments.keys(),
		"settings": settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload))
		f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	current_level = int(parsed.get("level", 0))
	checkpoint_index = int(parsed.get("checkpoint", -1))
	health = int(parsed.get("health", max_health))
	energy = float(parsed.get("energy", max_energy))
	lantern_type = int(parsed.get("lantern", Lantern.WARM))
	unlocked_lanterns = []
	for u in parsed.get("unlocked", [Lantern.WARM]):
		unlocked_lanterns.append(int(u))
	if unlocked_lanterns.is_empty():
		unlocked_lanterns = [Lantern.WARM]
	collected_fragments.clear()
	for k in parsed.get("fragments", []):
		collected_fragments[str(k)] = true
	var s = parsed.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		for key in s.keys():
			settings[str(key)] = s[key]
	_apply_settings()
	return true


func _load_settings() -> void:
	if has_save():
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("settings")) == TYPE_DICTIONARY:
				for key in parsed["settings"].keys():
					settings[str(key)] = parsed["settings"][key]
	_apply_settings()


func _apply_settings() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(clamp(float(settings["music"]), 0.001, 1.0)))
	if bool(settings["fullscreen"]):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
