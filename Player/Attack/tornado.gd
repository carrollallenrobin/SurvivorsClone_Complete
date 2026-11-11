extends Area2D

var level = 1
var hp = 9999
var speed = 100.0
var damage = 5
var attack_size = 1.0
var knockback_amount = 100

var last_movement = Vector2.ZERO
var orbit_radius = 50.0
var outward_ratio = 0.20
var bearing = 0.0
var radius = 50.0

signal remove_from_array(object)

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	match level:
		1:
			hp = 9999
			speed = 100.0
			damage = 5
			knockback_amount = 100
			attack_size = 1.0 * (1 + player.spell_size)
		2:
			hp = 9999
			speed = 100.0
			damage = 5
			knockback_amount = 100
			attack_size = 1.0 * (1 + player.spell_size)
		3:
			hp = 9999
			speed = 100.0
			damage = 5
			knockback_amount = 100
			attack_size = 1.0 * (1 + player.spell_size)
		4:
			hp = 9999
			speed = 100.0
			damage = 5
			knockback_amount = 125
			attack_size = 1.0 * (1 + player.spell_size)

	speed *= 1.0 + player.spell_attack_speed
	var spawn_direction = last_movement
	if spawn_direction.length_squared() <= 0.001:
		spawn_direction = Vector2.UP
	spawn_direction = spawn_direction.normalized()
	bearing = spawn_direction.angle()
	var already = 0
	for node in get_tree().get_nodes_in_group("attack"):
		if node != self and node.get_script() == get_script():
			already += 1
	bearing -= already * TAU / 3.0
	radius = orbit_radius
	global_position = player.global_position + Vector2.RIGHT.rotated(bearing) * radius

	var initial_tween = create_tween().set_parallel(true)
	initial_tween.tween_property(self, "scale", Vector2(1, 1) * attack_size, 3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var final_speed = speed
	speed = speed / 5.0
	initial_tween.tween_property(self, "speed", final_speed, 6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	initial_tween.play()

func _physics_process(delta):
	if not is_instance_valid(player):
		global_position += Vector2.RIGHT.rotated(bearing - PI / 2.0) * speed * delta
		return

	var scale = sqrt(1.0 + outward_ratio * outward_ratio)
	var outward_speed = speed * outward_ratio / scale
	var tangential_speed = speed / scale
	var step = tangential_speed / max(radius, 1.0) * delta
	bearing -= step
	radius += outward_speed * delta
	global_position = player.global_position + Vector2.RIGHT.rotated(bearing) * radius

func _on_timer_timeout():
	emit_signal("remove_from_array", self)
	queue_free()
