extends Node2D
##
## Builds a playable level out of an ASCII map (see scripts/levels.gd).
## Everything is generated at runtime, so the project has no binary assets and
## a level can be edited by typing.
##

const TILE := 32

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var data: Dictionary = {}
var rows: Array = []
var cols := 0
var row_count := 0

var player: CharacterBody2D
var spawn := Vector2(64, 64)
var checkpoint_spots: Array[Vector2] = []
var runes: Array = []
var doors: Array = []
var _doors_open := false


func build(level_data: Dictionary, checkpoint_index: int) -> void:
	data = level_data
	rows = data["map"]
	row_count = rows.size()
	for r in rows:
		cols = max(cols, str(r).length())

	var ambient := CanvasModulate.new()
	var tint: Color = data.get("ambient", Color(0.24, 0.27, 0.4))
	var b := float(Game.settings.get("brightness", 1.0))
	ambient.color = Color(tint.r * b, tint.g * b, tint.b * b)
	add_child(ambient)

	_build_backdrop()
	_parse()

	if checkpoint_index >= 0 and checkpoint_index < checkpoint_spots.size():
		spawn = checkpoint_spots[checkpoint_index]

	player = PlayerScript.new()
	player.global_position = spawn
	add_child(player)

	player.cam.limit_left = 0
	player.cam.limit_top = -600
	player.cam.limit_right = cols * TILE
	player.cam.limit_bottom = row_count * TILE + 96

	Game.level_fragment_total = _count("*")
	Game.fragments_changed.emit(Game.fragments_in_level(), Game.level_fragment_total)


func _count(ch: String) -> int:
	var n := 0
	for r in rows:
		n += str(r).count(ch)
	return n


func _process(_delta: float) -> void:
	# doors listen to the runes
	var all_lit := runes.size() > 0
	for r in runes:
		if is_instance_valid(r) and not r.active:
			all_lit = false
	if all_lit != _doors_open:
		_doors_open = all_lit
		for d in doors:
			if is_instance_valid(d):
				d.set_open(all_lit)
		if all_lit:
			Game.toast.emit("The seals give way")

	# fell out of the world
	if player and is_instance_valid(player) and player.alive:
		if player.global_position.y > row_count * TILE + 260:
			player.die()


# ------------------------------------------------------------------ parsing
func _parse() -> void:
	for y in row_count:
		var line := str(rows[y])
		var x := 0
		while x < line.length():
			var ch := line[x]
			if ch == "#":
				var start := x
				while x + 1 < line.length() and line[x + 1] == "#":
					x += 1
				_solid(start, x, y)
			else:
				_entity(ch, x, y)
			x += 1


func _cell(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)


func _entity(ch: String, x: int, y: int) -> void:
	var pos := _cell(x, y)
	match ch:
		"~":
			add_child(Hidden.new(pos))
		"H":
			add_child(Ladder.new(pos))
		"^":
			add_child(Spikes.new(pos))
		"*":
			var id := "%d_%d" % [x, y]
			if not Game.has_fragment(id):
				add_child(Fragment.new(pos, id))
		"o":
			add_child(Oil.new(pos))
		"C":
			var idx := checkpoint_spots.size()
			checkpoint_spots.append(pos + Vector2(0, TILE * 0.5 - 1))
			add_child(Checkpoint.new(pos, idx))
		"E":
			var e := EnemyScript.new()
			e.global_position = pos + Vector2(0, TILE * 0.5 - 1)
			add_child(e)
		"/":
			add_child(Mirror.new(pos, -45.0))
		"\\":
			add_child(Mirror.new(pos, 45.0))
		"R":
			var rune := Rune.new(pos)
			runes.append(rune)
			add_child(rune)
		"D":
			var d := Door.new(pos)
			doors.append(d)
			add_child(d)
		"P":
			spawn = pos + Vector2(0, TILE * 0.5 - 1)
		"X":
			add_child(Exit.new(pos))


func _solid(x0: int, x1: int, y: int) -> void:
	var w := (x1 - x0 + 1) * TILE
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(x0 * TILE + w * 0.5, y * TILE + TILE * 0.5)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, TILE)
	shape.shape = rect
	body.add_child(shape)

	var face := Polygon2D.new()
	face.polygon = _rect_points(w, TILE)
	face.color = Color(0.13, 0.15, 0.21)
	body.add_child(face)

	# lip on the top edge, so ledges read clearly in the gloom
	var lip := Polygon2D.new()
	lip.polygon = _rect_points(w, 5.0)
	lip.position = Vector2(0, -TILE * 0.5 + 2.5)
	lip.color = Color(0.22, 0.25, 0.33)
	body.add_child(lip)

	add_child(body)


static func _rect_points(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
	])


# ------------------------------------------------------------------ backdrop
func _build_backdrop() -> void:
	var back := Node2D.new()
	back.z_index = -20
	add_child(back)

	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([
		Vector2(-200, -900), Vector2(cols * TILE + 200, -900),
		Vector2(cols * TILE + 200, row_count * TILE + 200), Vector2(-200, row_count * TILE + 200),
	])
	sky.color = Color(0.05, 0.07, 0.13)
	back.add_child(sky)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("name", "level")))
	var ground := row_count * TILE
	for i in 26:
		var sx := rng.randf_range(-100.0, cols * TILE + 100.0)
		var h := rng.randf_range(120.0, 420.0)
		var w := rng.randf_range(26.0, 70.0)
		var spire := Polygon2D.new()
		spire.polygon = PackedVector2Array([
			Vector2(-w * 0.5, 0), Vector2(-w * 0.4, -h),
			Vector2(0, -h - w * 0.8), Vector2(w * 0.4, -h), Vector2(w * 0.5, 0),
		])
		spire.position = Vector2(sx, ground - 40.0)
		spire.color = Color(0.07, 0.09, 0.16).lerp(Color(0.10, 0.12, 0.20), rng.randf())
		back.add_child(spire)

		if rng.randf() < 0.55:
			var win := Polygon2D.new()
			win.polygon = _rect_points(4, 7)
			win.position = Vector2(sx + rng.randf_range(-8, 8), ground - 40.0 - h * rng.randf_range(0.3, 0.9))
			win.color = Color(1.0, 0.72, 0.35, 0.55)
			back.add_child(win)

	var moon := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a), sin(a)) * 34.0)
	moon.polygon = pts
	moon.position = Vector2(cols * TILE * 0.72, -180)
	moon.color = Color(0.85, 0.88, 1.0, 0.5)
	back.add_child(moon)


# =============================================================== entities ===

class Hidden extends StaticBody2D:
	## A platform that only exists inside revealing lantern light.
	var poly: Polygon2D
	var glowing := false

	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 0
		collision_mask = 0

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 32)
		shape.shape = rect
		add_child(shape)

		poly = Polygon2D.new()
		poly.polygon = _rect_points(32, 32)
		poly.color = Color(0.35, 0.45, 0.62, 0.0)
		add_child(poly)

	func _process(delta: float) -> void:
		var lit := Game.reveals_at(global_position)
		if lit != glowing:
			glowing = lit
			collision_layer = 1 if lit else 0
		var target := 0.85 if glowing else 0.06
		poly.color.a = lerpf(poly.color.a, target, delta * 8.0)

	static func _rect_points(w: float, h: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
			Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
		])


class Ladder extends Area2D:
	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 8
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20, 32)
		shape.shape = rect
		add_child(shape)

		for side in [-8.0, 8.0]:
			var rail := Polygon2D.new()
			rail.polygon = PackedVector2Array([
				Vector2(side - 2, -16), Vector2(side + 2, -16),
				Vector2(side + 2, 16), Vector2(side - 2, 16),
			])
			rail.color = Color(0.32, 0.26, 0.18)
			add_child(rail)
		var rung := Polygon2D.new()
		rung.polygon = PackedVector2Array([
			Vector2(-9, -3), Vector2(9, -3), Vector2(9, 2), Vector2(-9, 2),
		])
		rung.color = Color(0.38, 0.31, 0.21)
		add_child(rung)

		body_entered.connect(_on_enter)
		body_exited.connect(_on_exit)

	func _on_enter(b: Node) -> void:
		if b.has_method("add_ladder"):
			b.add_ladder(1)

	func _on_exit(b: Node) -> void:
		if b.has_method("add_ladder"):
			b.add_ladder(-1)


class Spikes extends Area2D:
	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 8
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(30, 16)
		shape.shape = rect
		shape.position = Vector2(0, 8)
		add_child(shape)

		for i in 3:
			var s := Polygon2D.new()
			var x := -10.0 + i * 10.0
			s.polygon = PackedVector2Array([
				Vector2(x - 5, 16), Vector2(x, -2), Vector2(x + 5, 16),
			])
			s.color = Color(0.55, 0.57, 0.66)
			add_child(s)

		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if b.has_method("take_damage"):
			b.take_damage(1, global_position)


class Fragment extends Area2D:
	## Memory Fragment - collect them to uncover the story of Lumina.
	var id := ""
	var t := 0.0

	func _init(pos: Vector2, fragment_id: String) -> void:
		position = pos
		id = fragment_id
		collision_layer = 8
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14.0
		shape.shape = circle
		add_child(shape)

		var crystal := Polygon2D.new()
		crystal.polygon = PackedVector2Array([
			Vector2(0, -13), Vector2(8, 0), Vector2(0, 13), Vector2(-8, 0),
		])
		crystal.color = Color(0.55, 0.95, 0.9)
		add_child(crystal)

		var light := PointLight2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		light.texture = tex
		light.color = Color(0.5, 1.0, 0.9)
		light.energy = 0.8
		light.texture_scale = 0.7
		add_child(light)

		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if b.is_in_group("player"):
			Game.collect_fragment(id)
			queue_free()

	func _process(delta: float) -> void:
		t += delta
		position.y += sin(t * 2.2) * delta * 9.0
		rotation = sin(t * 1.4) * 0.35


class Oil extends Area2D:
	## Lantern oil - restores energy.
	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 8
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 13.0
		shape.shape = circle
		add_child(shape)

		var flask := Polygon2D.new()
		flask.polygon = PackedVector2Array([
			Vector2(-6, -10), Vector2(6, -10), Vector2(9, 4),
			Vector2(4, 11), Vector2(-4, 11), Vector2(-9, 4),
		])
		flask.color = Color(1.0, 0.72, 0.30)
		add_child(flask)

		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if b.is_in_group("player"):
			Game.restore_energy(40.0)
			Game.toast.emit("Lantern oil +40")
			queue_free()


class Checkpoint extends Area2D:
	## Save point - refills health and lantern energy.
	var index := 0
	var used := false
	var flame: Polygon2D
	var light: PointLight2D

	func _init(pos: Vector2, idx: int) -> void:
		position = pos
		index = idx
		collision_layer = 8
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(30, 40)
		shape.shape = rect
		add_child(shape)

		var post := Polygon2D.new()
		post.polygon = PackedVector2Array([
			Vector2(-3, -6), Vector2(3, -6), Vector2(3, 16), Vector2(-3, 16),
		])
		post.color = Color(0.30, 0.25, 0.18)
		add_child(post)

		var bowl := Polygon2D.new()
		bowl.polygon = PackedVector2Array([
			Vector2(-10, -12), Vector2(10, -12), Vector2(6, -4), Vector2(-6, -4),
		])
		bowl.color = Color(0.38, 0.31, 0.21)
		add_child(bowl)

		flame = Polygon2D.new()
		flame.polygon = PackedVector2Array([
			Vector2(0, -26), Vector2(6, -14), Vector2(0, -10), Vector2(-6, -14),
		])
		flame.color = Color(1.0, 0.75, 0.35, 0.0)
		add_child(flame)

		light = PointLight2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		light.texture = tex
		light.color = Color(1.0, 0.78, 0.42)
		light.energy = 0.0
		light.texture_scale = 1.2
		light.position = Vector2(0, -18)
		add_child(light)

		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if b.is_in_group("player"):
			_activate()

	func _activate() -> void:
		if used:
			return
		used = true
		flame.color.a = 1.0
		light.energy = 1.1
		Game.checkpoint_index = index
		Game.heal_full()
		Game.save_game()
		Game.toast.emit("Checkpoint - the light is restored")


class Exit extends Area2D:
	## The beacon that ends the chapter.
	var t := 0.0
	var core: Polygon2D

	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 8
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 60)
		shape.shape = rect
		shape.position = Vector2(0, -12)
		add_child(shape)

		var arch := Polygon2D.new()
		arch.polygon = PackedVector2Array([
			Vector2(-18, 16), Vector2(-14, -36), Vector2(0, -48),
			Vector2(14, -36), Vector2(18, 16),
		])
		arch.color = Color(0.20, 0.18, 0.30)
		add_child(arch)

		core = Polygon2D.new()
		core.polygon = PackedVector2Array([
			Vector2(0, -40), Vector2(10, -16), Vector2(0, 8), Vector2(-10, -16),
		])
		core.color = Color(0.72, 0.52, 1.0)
		add_child(core)

		var light := PointLight2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		light.texture = tex
		light.color = Color(0.72, 0.52, 1.0)
		light.energy = 1.0
		light.texture_scale = 1.4
		light.position = Vector2(0, -16)
		add_child(light)

		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if b.is_in_group("player"):
			Game.level_completed.emit()

	func _process(delta: float) -> void:
		t += delta
		core.scale = Vector2.ONE * (1.0 + sin(t * 2.5) * 0.07)


class Mirror extends StaticBody2D:
	## Reflects the focused light beam.
	func _init(pos: Vector2, angle_deg: float) -> void:
		position = pos
		rotation_degrees = angle_deg
		collision_layer = 1
		collision_mask = 0

	func _ready() -> void:
		add_to_group("mirror")
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 7)
		shape.shape = rect
		add_child(shape)

		var frame := Polygon2D.new()
		frame.polygon = PackedVector2Array([
			Vector2(-21, -5), Vector2(21, -5), Vector2(21, 5), Vector2(-21, 5),
		])
		frame.color = Color(0.32, 0.27, 0.18)
		add_child(frame)

		var glass := Polygon2D.new()
		glass.polygon = PackedVector2Array([
			Vector2(-19, -3), Vector2(19, -3), Vector2(19, 1), Vector2(-19, 1),
		])
		glass.color = Color(0.80, 0.90, 1.0)
		add_child(glass)


class Rune extends StaticBody2D:
	## Light rune - stays awake while the beam touches it.
	var active := false
	var timer := 0.0
	var ring: Polygon2D
	var light: PointLight2D

	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 1
		collision_mask = 0

	func _ready() -> void:
		add_to_group("rune")
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(26, 26)
		shape.shape = rect
		add_child(shape)

		var stone := Polygon2D.new()
		stone.polygon = PackedVector2Array([
			Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13),
		])
		stone.color = Color(0.18, 0.18, 0.24)
		add_child(stone)

		ring = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * float(i) / 8.0
			pts.append(Vector2(cos(a), sin(a)) * 8.0)
		ring.polygon = pts
		ring.color = Color(0.4, 0.4, 0.5)
		add_child(ring)

		light = PointLight2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		light.texture = tex
		light.color = Color(1.0, 0.85, 0.5)
		light.energy = 0.0
		light.texture_scale = 1.6
		add_child(light)

	func hit_by_beam() -> void:
		# runes latch: once the beam wakes one, it stays awake
		timer = 1.0
		active = true

	func _process(delta: float) -> void:
		timer = max(0.0, timer - delta)
		ring.color = ring.color.lerp(
			Color(1.0, 0.86, 0.5) if active else Color(0.4, 0.4, 0.5), delta * 10.0)
		light.energy = lerpf(light.energy, 1.3 if active else 0.0, delta * 10.0)


class Door extends StaticBody2D:
	## Sealed door - opens while every rune in the level is awake.
	var slab: Polygon2D
	var open := false

	func _init(pos: Vector2) -> void:
		position = pos
		collision_layer = 1
		collision_mask = 0

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 32)
		shape.shape = rect
		add_child(shape)

		slab = Polygon2D.new()
		slab.polygon = PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
		])
		slab.color = Color(0.30, 0.24, 0.35)
		add_child(slab)

	func set_open(value: bool) -> void:
		open = value
		collision_layer = 0 if value else 1

	func _process(delta: float) -> void:
		slab.color.a = lerpf(slab.color.a, 0.12 if open else 1.0, delta * 6.0)
		slab.scale.x = lerpf(slab.scale.x, 0.25 if open else 1.0, delta * 6.0)
