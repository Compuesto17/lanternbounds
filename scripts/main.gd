extends Node
##
## Entry point. Owns the screen flow:
##   Main Menu -> Level -> (Pause / Inventory / Options) -> Next Level -> Ending
##

const Levels = preload("res://scripts/levels.gd")
const LevelScript = preload("res://scripts/level.gd")
const HudScript = preload("res://scripts/hud.gd")

const BG := Color(0.043, 0.06, 0.11)
const PANEL := Color(0.07, 0.09, 0.15)
const GOLD := Color(0.93, 0.72, 0.30)
const CREAM := Color(0.95, 0.91, 0.80)

var world: Node2D
var ui: CanvasLayer
var screen: Control          # current fullscreen menu, if any
var level: Node2D
var hud: CanvasLayer

var state := "menu"
var _ending := false
var _death_timer := 0.0


func _ready() -> void:
	world = Node2D.new()
	add_child(world)

	ui = CanvasLayer.new()
	ui.layer = 20
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)

	process_mode = Node.PROCESS_MODE_ALWAYS

	Game.player_died.connect(_on_player_died)
	Game.level_completed.connect(_on_level_completed)

	show_main_menu()


func _process(delta: float) -> void:
	if _death_timer > 0.0:
		_death_timer -= delta
		if _death_timer <= 0.0:
			_show_death_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == "play":
			pause_game()
		elif state == "pause":
			resume_game()


# ============================================================ screen helpers
func _clear_screen() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null


func _new_screen(dim: float = 0.92) -> Control:
	_clear_screen()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(BG.r, BG.g, BG.b, dim)
	root.add_child(bg)

	ui.add_child(root)
	screen = root
	return root


func _column(parent: Control, offset := Vector2(0, 0)) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.position = offset
	parent.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	return col


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, callback: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))
	b.add_theme_stylebox_override("normal", _box(PANEL, GOLD.darkened(0.55)))
	b.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.10), GOLD))
	b.add_theme_stylebox_override("pressed", _box(PANEL.darkened(0.2), GOLD))
	b.add_theme_stylebox_override("disabled", _box(PANEL.darkened(0.3), Color(0.25, 0.25, 0.3)))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _spacer(parent: Control, h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	parent.add_child(c)


# ================================================================ main menu
func show_main_menu() -> void:
	state = "menu"
	_ending = false
	get_tree().paused = false
	_unload_level()

	var root := _new_screen(1.0)
	_menu_backdrop(root)
	var col := _column(root)

	_label(col, "LANTERNBOUND", 64, CREAM)
	_label(col, "T H E   L A S T   L I G H T", 22, GOLD)
	_spacer(col, 26)

	_button(col, "CONTINUE", _continue_game, Game.has_save())
	_button(col, "NEW GAME", _new_game)
	_button(col, "SETTINGS", func(): show_settings("menu"))
	_button(col, "EXIT", func(): get_tree().quit())

	_spacer(col, 18)
	_label(col, "Even the smallest light can change the fate of the world.", 14, Color(0.6, 0.62, 0.7))


func _menu_backdrop(root: Control) -> void:
	# a lantern glow behind the menu
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0.06, 0.08, 0.14)
	root.add_child(glow)

	var holder := Node2D.new()
	root.add_child(holder)
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.8, 0.45, 0.55))
	g.set_color(1, Color(1, 0.8, 0.45, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(640, 360)
	sprite.scale = Vector2(2.4, 2.0)
	sprite.modulate = Color(1, 1, 1, 0.45)
	holder.add_child(sprite)


# ================================================================ settings
func show_settings(came_from: String) -> void:
	var root := _new_screen()
	var col := _column(root)
	_label(col, "SETTINGS", 44, CREAM)
	_spacer(col, 14)

	_slider_row(col, "MUSIC", "music")
	_slider_row(col, "SFX", "sfx")
	_slider_row(col, "BRIGHTNESS", "brightness")

	var fs := CheckButton.new()
	fs.text = "FULLSCREEN"
	fs.button_pressed = bool(Game.settings["fullscreen"])
	fs.add_theme_font_size_override("font_size", 18)
	fs.add_theme_color_override("font_color", CREAM)
	fs.toggled.connect(func(on):
		Game.settings["fullscreen"] = on
		Game._apply_settings())
	col.add_child(fs)

	_spacer(col, 18)
	_button(col, "BACK", func():
		Game.save_game()
		if came_from == "menu":
			show_main_menu()
		else:
			pause_game())


func _slider_row(parent: Control, title: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", CREAM)
	row.add_child(l)

	var s := HSlider.new()
	s.custom_minimum_size = Vector2(240, 24)
	s.min_value = 0.1
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.value_changed.connect(func(v):
		Game.settings[key] = v
		Game._apply_settings()
		if key == "brightness" and level and is_instance_valid(level):
			_apply_brightness())
	row.add_child(s)


func _apply_brightness() -> void:
	for child in level.get_children():
		if child is CanvasModulate:
			var tint: Color = Levels.LEVELS[Game.current_level].get("ambient", Color(0.24, 0.27, 0.4))
			var b := float(Game.settings["brightness"])
			child.color = Color(tint.r * b, tint.g * b, tint.b * b)


# ================================================================ play flow
func _new_game() -> void:
	Game.new_game()
	load_level(0)


func _continue_game() -> void:
	if Game.load_game():
		load_level(Game.current_level)
	else:
		_new_game()


func _unload_level() -> void:
	if level and is_instance_valid(level):
		level.queue_free()
	level = null
	if hud and is_instance_valid(hud):
		hud.queue_free()
	hud = null


func load_level(index: int) -> void:
	_clear_screen()
	_unload_level()
	get_tree().paused = false
	_ending = false
	_death_timer = 0.0

	index = clampi(index, 0, Levels.LEVELS.size() - 1)
	Game.current_level = index
	var data: Dictionary = Levels.LEVELS[index]

	var unlock := int(data.get("unlock", -1))
	if unlock >= 0:
		Game.unlock_lantern(unlock)

	level = LevelScript.new()
	world.add_child(level)
	level.build(data, Game.checkpoint_index)

	hud = HudScript.new()
	add_child(hud)
	hud.show_chapter(str(data["name"]), str(data["subtitle"]))
	hud.show_toast(str(data.get("hint", "")))

	state = "play"
	Game.save_game()


func restart_level() -> void:
	Game.heal_full()
	load_level(Game.current_level)


# ================================================================ pause menu
func pause_game() -> void:
	if state != "play" and state != "pause":
		return
	state = "pause"
	get_tree().paused = true

	var root := _new_screen(0.78)
	var col := _column(root)
	_label(col, "PAUSED", 46, CREAM)
	_label(col, str(Levels.LEVELS[Game.current_level]["name"]), 18, GOLD)
	_spacer(col, 16)
	_button(col, "RESUME", resume_game)
	_button(col, "INVENTORY", show_inventory)
	_button(col, "OPTIONS", func(): show_settings("pause"))
	_button(col, "MAIN MENU", func():
		Game.save_game()
		show_main_menu())


func resume_game() -> void:
	_clear_screen()
	get_tree().paused = false
	state = "play"


func show_inventory() -> void:
	var root := _new_screen(0.92)
	var col := _column(root)
	_label(col, "INVENTORY", 42, CREAM)
	_spacer(col, 10)
	_label(col, "Memory Fragments: %d in this chapter  |  %d in total"
		% [Game.fragments_in_level(), Game.total_fragments()], 18, Color(0.55, 0.95, 0.9))
	_spacer(col, 10)
	_label(col, "LANTERNS", 24, GOLD)
	for type in Game.unlocked_lanterns:
		var info: Dictionary = Game.LANTERN_DATA[type]
		var line := "%s   -   radius %d   -   %s" % [
			str(info["name"]), int(info["radius"]),
			"reveals hidden paths" if bool(info["reveal"]) else "burns the shadows",
		]
		_label(col, line, 16, Color(info["color"]))
	_spacer(col, 14)
	_label(col, "CONTROLS", 24, GOLD)
	_label(col, "Move: A / D   -   Run: Shift   -   Jump: Space   -   Climb: W / S", 15, CREAM)
	_label(col, "Lantern: F   -   Swap lantern: Tab   -   Focus beam: R   -   Interact: E", 15, CREAM)
	_spacer(col, 16)
	_button(col, "BACK", pause_game)


# ================================================================ end states
func _on_player_died() -> void:
	if state != "play" or _ending:
		return
	_ending = true
	_death_timer = 1.3


func _show_death_screen() -> void:
	state = "dead"
	get_tree().paused = true
	var root := _new_screen(0.86)
	var col := _column(root)
	_label(col, "THE DARK TAKES YOU", 44, Color(0.85, 0.35, 0.35))
	_label(col, "But the last light is not out yet.", 18, CREAM)
	_spacer(col, 20)
	_button(col, "RETRY FROM CHECKPOINT", func():
		get_tree().paused = false
		restart_level())
	_button(col, "MAIN MENU", show_main_menu)


func _on_level_completed() -> void:
	if state != "play" or _ending:
		return
	_ending = true
	var next := Game.current_level + 1
	Game.checkpoint_index = -1
	if next >= Levels.LEVELS.size():
		_show_ending()
	else:
		Game.current_level = next
		Game.save_game()
		_show_chapter_clear(next)


func _show_chapter_clear(next_index: int) -> void:
	state = "dead"      # locks input until the player chooses
	get_tree().paused = true
	var root := _new_screen(0.86)
	var col := _column(root)
	_label(col, "CHAPTER COMPLETE", 44, GOLD)
	_label(col, "Fragments recovered: %d" % Game.total_fragments(), 18, Color(0.55, 0.95, 0.9))
	_spacer(col, 20)
	_button(col, "CONTINUE", func():
		get_tree().paused = false
		load_level(next_index))
	_button(col, "MAIN MENU", show_main_menu)


func _show_ending() -> void:
	state = "dead"
	get_tree().paused = true
	var root := _new_screen(0.95)
	var col := _column(root)
	_label(col, "THE LAST LIGHT", 54, CREAM)
	_spacer(col, 10)
	_label(col, "The fragments of the Heart of Dawn burn together, and somewhere", 17, CREAM)
	_label(col, "above Elaria the first morning in a hundred years begins.", 17, CREAM)
	_spacer(col, 10)
	_label(col, "Memory Fragments recovered: %d" % Game.total_fragments(), 19, Color(0.55, 0.95, 0.9))
	_spacer(col, 24)
	_label(col, "Thank you for playing.", 16, GOLD)
	_spacer(col, 16)
	_button(col, "MAIN MENU", show_main_menu)
