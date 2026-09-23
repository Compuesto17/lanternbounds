extends CanvasLayer
##
## In-game HUD: hearts, lantern energy, memory fragments, chapter card, toasts.
##

const GOLD := Color(0.93, 0.72, 0.30)
const CREAM := Color(0.95, 0.91, 0.80)

var hearts: Array[Label] = []
var energy_bar: ProgressBar
var frag_label: Label
var lantern_label: Label
var toast_label: Label
var title_label: Label
var subtitle_label: Label

var _toast_t := 0.0
var _title_t := 0.0


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- hearts + energy (top left) ----
	var left := VBoxContainer.new()
	left.position = Vector2(26, 20)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	left.add_child(hb)
	for i in Game.max_health:
		var h := Label.new()
		h.text = "\u2665"
		h.add_theme_font_size_override("font_size", 26)
		h.add_theme_color_override("font_color", Color(0.92, 0.26, 0.30))
		hb.add_child(h)
		hearts.append(h)

	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(210, 16)
	energy_bar.max_value = Game.max_energy
	energy_bar.value = Game.energy
	energy_bar.show_percentage = false
	energy_bar.add_theme_stylebox_override("background", _box(Color(0.10, 0.11, 0.16), GOLD.darkened(0.5)))
	energy_bar.add_theme_stylebox_override("fill", _box(GOLD, GOLD))
	left.add_child(energy_bar)

	lantern_label = Label.new()
	lantern_label.add_theme_font_size_override("font_size", 14)
	lantern_label.add_theme_color_override("font_color", CREAM)
	left.add_child(lantern_label)

	# ---- fragments (top right) ----
	frag_label = Label.new()
	frag_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	frag_label.position = Vector2(-190, 22)
	frag_label.custom_minimum_size = Vector2(160, 0)
	frag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frag_label.add_theme_font_size_override("font_size", 18)
	frag_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.9))
	root.add_child(frag_label)

	# ---- chapter card ----
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-320, 90)
	card.custom_minimum_size = Vector2(640, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(card)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(640, 0)
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", CREAM)
	card.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.custom_minimum_size = Vector2(640, 0)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", GOLD)
	card.add_child(subtitle_label)

	# ---- toast ----
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(-300, -90)
	toast_label.custom_minimum_size = Vector2(600, 0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.add_theme_color_override("font_color", CREAM)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	Game.health_changed.connect(_on_health)
	Game.energy_changed.connect(_on_energy)
	Game.fragments_changed.connect(_on_fragments)
	Game.lantern_changed.connect(func(_t): _refresh_lantern())
	Game.toast.connect(show_toast)

	_on_health(Game.health, Game.max_health)
	_on_energy(Game.energy, Game.max_energy)
	_on_fragments(Game.fragments_in_level(), Game.level_fragment_total)
	_refresh_lantern()


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clamp(_toast_t, 0.0, 1.0)
	if _title_t > 0.0:
		_title_t -= delta
		var a: float = clamp(_title_t, 0.0, 1.0)
		title_label.modulate.a = a
		subtitle_label.modulate.a = a


func show_chapter(name: String, subtitle: String) -> void:
	title_label.text = name
	subtitle_label.text = subtitle
	_title_t = 4.0


func show_toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 2.6


func _on_health(current: int, _maximum: int) -> void:
	for i in hearts.size():
		hearts[i].modulate = Color(1, 1, 1, 1) if i < current else Color(0.25, 0.25, 0.3, 1)


func _on_energy(current: float, maximum: float) -> void:
	energy_bar.max_value = maximum
	energy_bar.value = current


func _on_fragments(collected: int, total: int) -> void:
	frag_label.text = "\u25C6  %d / %d" % [collected, total]


func _refresh_lantern() -> void:
	var info: Dictionary = Game.lantern_info()
	lantern_label.text = str(info["name"]) + "   [F] light   [TAB] swap   [R] focus"
	lantern_label.add_theme_color_override("font_color", Color(info["color"]))
	energy_bar.add_theme_stylebox_override("fill", _box(Color(info["color"]), Color(info["color"])))
