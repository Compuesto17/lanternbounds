extends CharacterBody2D
##
## Lumi - the lantern keeper.
##
## Abilities (from the design doc): Walk / Run / Jump / Climb / Use Lantern /
## Interact / Collect / Avoid or weaken enemies. Lantern Energy is the only
## resource.
##

const SPEED := 165.0
const RUN_SPEED := 248.0
const ACCEL := 2000.0
const FRICTION := 2600.0
const AIR_ACCEL := 1200.0
const GRAVITY := 1500.0
const JUMP_VELOCITY := -580.0
const MAX_FALL := 950.0
const CLIMB_SPEED := 130.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const INVULN_TIME := 1.1
const KNOCKBACK := Vector2(190.0, -280.0)

const BEAM_BOUNCES := 6
const BEAM_SEGMENT := 1200.0
const BEAM_DRAIN := 26.0

var facing := 1
var coyote := 0.0
var buffer := 0.0
var invuln := 0.0
var ladders := 0
var climbing := false
var lantern_on := true
var alive := true
var interact_targets: Array = []

var _body: Node2D
var _lamp: Sprite2D
var _light: PointLight2D
var _glow: PointLight2D
var _beam: Line2D
var _flicker := 0.0

@onready var cam: Camera2D = Camera2D.new()


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0

	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 9.0
	cap.height = 30.0
	shape.shape = cap
	shape.position = Vector2(0, -15)
	add_child(shape)

	_body = _build_body()
	add_child(_body)

	# Lantern light -------------------------------------------------------
	_light = PointLight2D.new()
	_light.texture = _radial_texture(256)
	_light.shadow_enabled = false
	_light.energy = 1.25
	_light.position = Vector2(0, -16)
	add_child(_light)

	_glow = PointLight2D.new()
	_glow.texture = _radial_texture(64)
	_glow.energy = 1.5
	_glow.texture_scale = 0.8
	_glow.position = Vector2(11 * facing, -14)
	add_child(_glow)

	# Focused beam --------------------------------------------------------
	_beam = Line2D.new()
	_beam.width = 3.0
	_beam.default_color = Color(1.0, 0.92, 0.65, 0.9)
	_beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam.z_index = 5
	_beam.visible = false
	add_child(_beam)

	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.zoom = Vector2(1.35, 1.35)
	add_child(cam)
	cam.make_current()

	Game.lantern_changed.connect(func(_t): _refresh_lantern())
	_refresh_lantern()


# --------------------------------------------------------------- visuals
func _build_body() -> Node2D:
	var root := Node2D.new()

	var cloak := Polygon2D.new()
	cloak.polygon = PackedVector2Array([
		Vector2(-10, -28), Vector2(10, -28), Vector2(12, -6),
		Vector2(8, 0), Vector2(-8, 0), Vector2(-12, -6),
	])
	cloak.color = Color(0.16, 0.20, 0.27)
	root.add_child(cloak)

	var scarf := Polygon2D.new()
	scarf.polygon = PackedVector2Array([
		Vector2(-9, -30), Vector2(9, -30), Vector2(7, -24), Vector2(-7, -24),
	])
	scarf.color = Color(0.36, 0.30, 0.22)
	root.add_child(scarf)

	var head := Polygon2D.new()
	head.polygon = _circle_points(7.0, 10, Vector2(0, -36))
	head.color = Color(0.92, 0.80, 0.66)
	root.add_child(head)

	var hair := Polygon2D.new()
	hair.polygon = PackedVector2Array([
		Vector2(-8, -38), Vector2(-3, -45), Vector2(4, -44),
		Vector2(9, -38), Vector2(6, -34), Vector2(-6, -34),
	])
	hair.color = Color(0.09, 0.08, 0.10)
	root.add_child(hair)

	# lantern held in the right hand
	_lamp = Sprite2D.new()
	_lamp.texture = _lamp_texture()
	_lamp.position = Vector2(11, -14)
	root.add_child(_lamp)

	return root


func _lamp_texture() -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var c := Color(0, 0, 0, 0)
			var edge: bool = x <= 3 or x >= 12 or y <= 2 or y >= 13
			if y >= 3 and y <= 13 and x >= 3 and x <= 12:
				c = Color(0.28, 0.22, 0.15, 1.0) if edge else Color(1.0, 0.82, 0.42, 1.0)
			if y <= 2 and x >= 6 and x <= 9:
				c = Color(0.35, 0.28, 0.18, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _circle_points(r: float, steps: int, offset: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(offset + Vector2(cos(a), sin(a)) * r)
	return pts


func _radial_texture(px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = px
	t.height = px
	return t


func _refresh_lantern() -> void:
	var info: Dictionary = Game.lantern_info()
	_light.color = info["color"]
	_glow.color = info["color"]
	_light.texture_scale = float(info["radius"]) / 128.0
	_lamp.modulate = Color(1, 1, 1).lerp(Color(info["color"]), 0.6)


# --------------------------------------------------------------- gameplay
func _physics_process(delta: float) -> void:
	if not alive:
		return

	invuln = max(0.0, invuln - delta)
	coyote = max(0.0, coyote - delta)
	buffer = max(0.0, buffer - delta)
	_flicker += delta

	_handle_lantern(delta)

	var dir := Input.get_axis("move_left", "move_right")
	var vdir := Input.get_axis("move_up", "move_down")

	# ---- climbing ----
	if ladders > 0 and (absf(vdir) > 0.1 or climbing):
		climbing = true
	if ladders == 0:
		climbing = false

	if climbing:
		velocity.y = vdir * CLIMB_SPEED
		velocity.x = dir * SPEED * 0.6
		if Input.is_action_just_pressed("jump"):
			climbing = false
			velocity.y = JUMP_VELOCITY * 0.85
		move_and_slide()
		_animate(delta, dir)
		return

	# ---- gravity ----
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
	if is_on_floor():
		coyote = COYOTE_TIME

	# ---- jump ----
	if Input.is_action_just_pressed("jump"):
		buffer = JUMP_BUFFER
	if buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		buffer = 0.0
		coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45   # variable jump height

	# ---- run / walk ----
	var top: float = RUN_SPEED if Input.is_action_pressed("run") else SPEED
	var a: float = ACCEL if is_on_floor() else AIR_ACCEL
	if absf(dir) > 0.05:
		velocity.x = move_toward(velocity.x, dir * top, a * delta)
		facing = 1 if dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# ---- interact ----
	if Input.is_action_just_pressed("interact"):
		for t in interact_targets:
			if is_instance_valid(t) and t.has_method("interact"):
				t.interact(self)

	move_and_slide()
	_animate(delta, dir)


func _animate(delta: float, dir: float) -> void:
	_body.scale.x = lerpf(_body.scale.x, float(facing), 18.0 * delta)
	var hand := Vector2(11 * facing, -14)
	_glow.position = hand
	if is_on_floor() and absf(velocity.x) > 10.0:
		_body.position.y = -absf(sin(_flicker * 12.0)) * 2.0
	else:
		_body.position.y = 0.0
	if invuln > 0.0:
		_body.modulate.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 1.0
	else:
		_body.modulate.a = 1.0


# --------------------------------------------------------------- lantern
func _handle_lantern(delta: float) -> void:
	if Input.is_action_just_pressed("lantern"):
		lantern_on = not lantern_on
	if Input.is_action_just_pressed("cycle_lantern"):
		Game.cycle_lantern()
		_refresh_lantern()

	var info: Dictionary = Game.lantern_info()
	var focusing: bool = Input.is_action_pressed("focus_beam") and lantern_on and Game.energy > 0.0

	if lantern_on and Game.energy > 0.0:
		Game.spend_energy(float(info["drain"]) * delta)
	if Game.energy <= 0.0:
		lantern_on = false

	var lit := lantern_on and Game.energy > 0.0
	var flick := 1.0 + sin(_flicker * 9.0) * 0.04 + sin(_flicker * 23.0) * 0.02
	_light.enabled = lit
	_glow.enabled = lit
	_light.energy = 1.25 * flick if lit else 0.0

	Game.lantern_on = lit
	Game.lantern_pos = global_position + Vector2(0, -16)
	Game.lantern_radius = float(info["radius"]) if lit else 0.0
	Game.lantern_reveals = bool(info["reveal"]) and lit
	Game.lantern_burn = float(info["burn"])

	_update_beam(focusing, delta)


## Casts the focused beam and bounces it off mirrors. Runes hit by the beam
## stay awake for a moment, which is what opens the sealed doors.
func _update_beam(focusing: bool, delta: float) -> void:
	_beam.visible = focusing
	if not focusing:
		_beam.clear_points()
		return

	Game.spend_energy(BEAM_DRAIN * delta)

	var origin := global_position + Vector2(11 * facing, -14)
	var dir := Vector2(facing, 0)
	var pts := PackedVector2Array([to_local(origin)])
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid()]

	for i in BEAM_BOUNCES:
		var query := PhysicsRayQueryParameters2D.create(origin, origin + dir * BEAM_SEGMENT)
		query.collision_mask = 1
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			pts.append(to_local(origin + dir * BEAM_SEGMENT))
			break
		var point: Vector2 = hit["position"]
		pts.append(to_local(point))
		var collider = hit["collider"]
		if collider and collider.is_in_group("mirror"):
			dir = dir.bounce(hit["normal"]).normalized()
			origin = point + dir * 3.0
			continue
		if collider and collider.has_method("hit_by_beam"):
			collider.hit_by_beam()
		break

	_beam.points = pts
	var c: Color = Game.lantern_info()["color"]
	_beam.default_color = Color(c.r, c.g, c.b, 0.85)


# --------------------------------------------------------------- state
func add_ladder(delta_count: int) -> void:
	ladders = max(0, ladders + delta_count)


func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if invuln > 0.0 or not alive:
		return
	invuln = INVULN_TIME
	Game.damage(amount)
	var away := 1.0 if global_position.x >= from.x else -1.0
	if from == Vector2.ZERO:
		away = -facing
	velocity = Vector2(KNOCKBACK.x * away, KNOCKBACK.y)
	climbing = false
	if Game.health <= 0:
		_shut_down()


## Called when Lumi falls out of the world, or when health reaches zero.
func die() -> void:
	if not alive:
		return
	_shut_down()
	if Game.health > 0:
		Game.damage(Game.health)   # the dark takes what is left


func _shut_down() -> void:
	alive = false
	velocity = Vector2.ZERO
	Game.lantern_on = false
	_light.enabled = false
	_glow.enabled = false
	_beam.visible = false
