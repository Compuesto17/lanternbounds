extends CharacterBody2D
##
## Shadow - a creature of the dark.
##
## It patrols its ledge and lunges at Lumi in darkness. Inside lantern light it
## is weakened (slow, translucent, harmless) and slowly burns away. The Fire
## Lantern destroys it fastest; the Spirit Lantern barely stings.
##

const GRAVITY := 1400.0
const PATROL_SPEED := 52.0
const CHASE_SPEED := 96.0
const SIGHT := 190.0
const MAX_HP := 3.0

var dir := 1
var hp := MAX_HP
var weakened := 0.0
var dying := false

var _body: Polygon2D
var _eyes: Node2D
var _t := 0.0
var _player: Node2D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 26)
	shape.shape = rect
	shape.position = Vector2(0, -13)
	add_child(shape)

	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-13, -26), Vector2(-7, -33), Vector2(7, -33), Vector2(13, -26),
		Vector2(14, -4), Vector2(9, 0), Vector2(-9, 0), Vector2(-14, -4),
	])
	_body.color = Color(0.07, 0.07, 0.11)
	add_child(_body)

	_eyes = Node2D.new()
	add_child(_eyes)
	for x in [-5.0, 5.0]:
		var e := Polygon2D.new()
		e.polygon = PackedVector2Array([
			Vector2(x - 3, -24), Vector2(x + 3, -25),
			Vector2(x + 3, -21), Vector2(x - 3, -20),
		])
		e.color = Color(1.0, 0.85, 0.55)
		_eyes.add_child(e)

	# contact hurtbox
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acol := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(26, 30)
	acol.shape = arect
	acol.position = Vector2(0, -15)
	area.add_child(acol)
	area.body_entered.connect(_on_touch)
	add_child(area)


func _on_touch(body: Node) -> void:
	if dying or weakened > 0.6:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)


func _physics_process(delta: float) -> void:
	_t += delta
	if dying:
		modulate.a = max(0.0, modulate.a - delta * 2.5)
		scale = scale.lerp(Vector2(0.2, 0.2), delta * 6.0)
		if modulate.a <= 0.02:
			queue_free()
		return

	velocity.y = min(velocity.y + GRAVITY * delta, 900.0)

	var lit := Game.is_lit(global_position + Vector2(0, -16))
	if lit:
		weakened = min(1.0, weakened + delta * 3.0)
		hp -= Game.lantern_burn * delta
		if hp <= 0.0:
			_die()
			return
	else:
		weakened = max(0.0, weakened - delta * 1.2)

	if _player == null or not is_instance_valid(_player):
		var ps := get_tree().get_nodes_in_group("player")
		_player = ps[0] if ps.size() > 0 else null

	var speed := PATROL_SPEED
	if lit:
		# recoil from the light
		speed = PATROL_SPEED * 1.4
		if _player:
			dir = -1 if _player.global_position.x > global_position.x else 1
	elif _player and global_position.distance_to(_player.global_position) < SIGHT:
		speed = CHASE_SPEED
		dir = 1 if _player.global_position.x > global_position.x else -1

	if is_on_wall() or (is_on_floor() and not _floor_ahead()):
		dir = -dir

	velocity.x = dir * speed * (1.0 - weakened * 0.55)
	move_and_slide()

	_body.color = Color(0.07, 0.07, 0.11).lerp(Color(0.45, 0.35, 0.55), weakened)
	modulate.a = 1.0 - weakened * 0.45
	_eyes.modulate = Color(1, 1, 1, 1.0 - weakened)
	_body.scale.y = 1.0 + sin(_t * 5.0) * 0.04
	_body.scale.x = 1.0 - sin(_t * 5.0) * 0.03


func _floor_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 16.0, -6.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 40))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _die() -> void:
	dying = true
	set_deferred("collision_layer", 0)
	Game.restore_energy(6.0)
	Game.toast.emit("A shadow unravels")
