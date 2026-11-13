extends Area2D

var level = 1
var hp = 1
var speed = 100
var damage = 5
var knockback_amount = 100
var attack_size = 1.0

var target = null
var angle = Vector2.UP
var curve_start = Vector2.ZERO
var curve_handle = Vector2.ZERO
var curve_control = Vector2.ZERO
var curve_end = Vector2.ZERO
var curve_progress = 0.0
var flight_duration = 1.0
var velocity = Vector2.ZERO
var preparing_launch = true
var orbit_angle = 0.0
var orbit_radius = 10.0
var spiral_outward_ratio = 0.32
var intro_outward_ratio = 0.8
var intro_active = true
var intro_spiraling = false
var intro_bearing = 0.0
var intro_radius = 0.0
var intro_swept = 0.0
var orbit_center = Vector2.ZERO
var lock_center = Vector2.ZERO
var spawn_direction = Vector2.UP

@onready var player = get_tree().get_first_node_in_group("player")
signal remove_from_array(object)

func _ready():
	speed *= 1.0 + player.spell_attack_speed
	if spawn_direction.length_squared() <= 0.001:
		spawn_direction = Vector2.UP
	spawn_direction = spawn_direction.normalized()
	orbit_center = player.global_position
	intro_bearing = spawn_direction.angle()
	intro_radius = orbit_radius
	intro_spiraling = true
	orbit_angle = intro_bearing
	global_position = orbit_center + spawn_direction * orbit_radius
	var tangent = Vector2.RIGHT.rotated(intro_bearing - PI / 2.0)
	velocity = (tangent + spawn_direction * intro_outward_ratio).normalized() * speed
	face(velocity)
	attack_size = 1.0 * (1 + player.spell_size)

	
	var tween = create_tween()
	tween.tween_property(self,"scale",Vector2(0.65,0.65)*attack_size,1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()

func _physics_process(delta):
	if intro_active:
		orbit_before_lock(delta)
		return
	
	if preparing_launch:
		glide(delta)
		target = acquire_target()
		if is_instance_valid(target):
			preparing_launch = false
			start_curve()
		return
	
	if not is_instance_valid(target):
		switch_target_or_glide(delta)
		return
	
	curve_end = target.global_position
	if is_radially_between(target.global_position, lock_center) or curve_has_no_bulge():
		target = null
		glide(delta)
		return
	
	curve_progress = advance_curve(curve_progress, speed * delta)
	var next_position = sample_curve(curve_progress)
	
	if crosses_left_to_right(global_position, next_position, lock_center):
		target = null
		glide(delta)
		return
	
	move_to(next_position, delta)
	
	if curve_progress >= 1.0:
		switch_target_or_glide(delta)

func orbit_before_lock(delta):
	var center = orbit_center
	if not intro_spiraling:
		if global_position.distance_squared_to(center) < 64.0:
			global_position += velocity * delta
			face(velocity)
			return
		var offset = global_position - center
		intro_spiraling = true
		intro_bearing = offset.angle()
		intro_radius = offset.length()
		intro_swept = 0.0
	
	var ratio = intro_outward_ratio
	var scale = sqrt(1.0 + ratio * ratio)
	var outward_speed = speed * ratio / scale
	var tangential_speed = speed / scale
	var angular_speed = tangential_speed / max(intro_radius, 1.0)
	var step = angular_speed * delta
	if intro_swept + step >= PI:
		var fraction = (PI - intro_swept) / max(step, 0.0001)
		step = PI - intro_swept
		delta *= fraction
		intro_active = false
	intro_swept += step
	intro_bearing -= step
	intro_radius += outward_speed * delta
	var outward = Vector2.RIGHT.rotated(intro_bearing)
	var tangent = Vector2.RIGHT.rotated(intro_bearing - PI / 2.0)
	velocity = (tangent + outward * ratio).normalized() * speed
	global_position = center + outward * intro_radius
	orbit_angle = intro_bearing
	face(velocity)

func acquire_target():
	if not is_instance_valid(player):
		return null
	
	var center = player.global_position
	var sword_offset = global_position - center
	if sword_offset.length_squared() <= 0.001:
		return null
	
	var sword_angle = sword_offset.angle()
	var best_enemy = null
	var best_distance_squared = INF
	for enemy in player.enemy_close:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_offset = enemy.global_position - center
		if enemy_offset.length_squared() <= 0.001:
			continue
		var counterclockwise_angle = fposmod(sword_angle - enemy_offset.angle(), TAU)
		if counterclockwise_angle < PI / 2.0 or counterclockwise_angle >= PI:
			continue
		if is_radially_between(enemy.global_position, center):
			continue
		if crosses_left_to_right(global_position, enemy.global_position, center):
			continue
		
		var distance_squared = center.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_enemy = enemy
	
	if is_instance_valid(best_enemy):
		lock_center = center
	return best_enemy

func is_radially_between(enemy_position, center):
	var to_enemy = enemy_position - center
	var enemy_length_squared = to_enemy.length_squared()
	if enemy_length_squared <= 1.0:
		return false
	
	var to_sword = global_position - center
	var projection = to_sword.dot(to_enemy) / enemy_length_squared
	if projection <= 0.0 or projection >= 0.98:
		return false
	
	var lateral = to_sword - to_enemy * projection
	return lateral.length_squared() <= 16.0

func curve_has_no_bulge():
	var chord = curve_end - curve_start
	var chord_length_squared = chord.length_squared()
	if chord_length_squared <= 1.0:
		return true
	
	var control_offset = curve_control - curve_start
	var lateral = control_offset - chord * (control_offset.dot(chord) / chord_length_squared)
	return lateral.length_squared() <= 16.0

func switch_target_or_glide(delta):
	var new_target = acquire_target()
	if is_instance_valid(new_target):
		target = new_target
		start_curve()
		return
	
	target = null
	glide(delta)

func glide(delta):
	var center = orbit_center
	var offset = global_position - center
	var desired = velocity
	if offset.length_squared() > 1.0:
		var outward = offset.normalized()
		var tangent = Vector2.RIGHT.rotated(outward.angle() - PI / 2.0)
		desired = (tangent + outward * spiral_outward_ratio).normalized() * speed
	elif desired.length_squared() <= 1.0:
		desired = Vector2.RIGHT.rotated(randf() * TAU) * speed
	else:
		desired = desired.normalized() * speed
	steer_toward(desired, delta)
	global_position += velocity * delta
	face(velocity)

func steer_toward(desired, delta):
	if velocity.length_squared() < 1.0:
		velocity = desired
		return
	
	var max_turn = 2.5 * delta
	var current_angle = velocity.angle()
	var turn = wrapf(desired.angle() - current_angle, -PI, PI)
	turn = clampf(turn, -max_turn, max_turn)
	velocity = Vector2.RIGHT.rotated(current_angle + turn) * speed

func move_to(next_position, delta):
	if delta > 0.0:
		velocity = (next_position - global_position) / delta
	if not global_position.is_equal_approx(next_position):
		face(next_position - global_position)
	global_position = next_position

func face(direction):
	if direction.length_squared() <= 0.001:
		return
	angle = direction.normalized()
	rotation = angle.angle() + deg_to_rad(135)

func advance_curve(progress, distance):
	var remaining = distance
	var guard = 0
	while remaining > 0.0 and progress < 1.0 and guard < 8:
		guard += 1
		var next_progress = min(progress + 0.02, 1.0)
		var segment = sample_curve(progress).distance_to(sample_curve(next_progress))
		if segment <= 0.001:
			progress = next_progress
			continue
		if segment <= remaining:
			remaining -= segment
			progress = next_progress
		else:
			progress += (next_progress - progress) * remaining / segment
			remaining = 0.0
	return progress

func sample_curve(progress):
	var inverse_progress = 1.0 - progress
	return (
		inverse_progress * inverse_progress * inverse_progress * curve_start
		+ 3.0 * inverse_progress * inverse_progress * progress * curve_handle
		+ 3.0 * inverse_progress * progress * progress * curve_control
		+ progress * progress * progress * curve_end
	)

func crosses_left_to_right(from_position, to_position, center):
	return from_position.x < center.x and to_position.x > center.x

func start_curve():
	curve_start = global_position
	if is_instance_valid(target):
		curve_end = target.global_position
	else:
		curve_end = global_position + Vector2.UP * 100.0
	
	var center = lock_center
	var start_offset = curve_start - center
	var end_offset = curve_end - center
	var start_angle = start_offset.angle()
	var end_angle = end_offset.angle()
	var counterclockwise_angle = min(fposmod(start_angle - end_angle, TAU), PI)
	var middle_angle = start_angle - counterclockwise_angle * 0.5
	var control_radius = max(
		(start_offset.length() + end_offset.length()) * 0.6,
		orbit_radius * 1.5
	)
	var target_distance = max(curve_start.distance_to(curve_end), 1.0)
	var incoming = velocity
	if incoming.length_squared() < 1.0:
		incoming = Vector2.RIGHT.rotated(orbit_angle - PI / 2.0) * speed
	curve_handle = curve_start + incoming.normalized() * clampf(target_distance * 0.35, 24.0, 90.0)
	
	curve_control = center + Vector2.RIGHT.rotated(middle_angle) * control_radius
	if curve_start.x >= center.x and curve_end.x >= center.x:
		curve_control.x = max(curve_control.x, center.x)
	elif curve_start.x <= center.x and curve_end.x <= center.x:
		curve_control.x = min(curve_control.x, center.x)
	flight_duration = max(target_distance / speed, 0.2)
	curve_progress = 0.0
	face(incoming)

func _on_timer_timeout():
	emit_signal("remove_from_array", self)
	queue_free()

func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		emit_signal("remove_from_array",self)
		queue_free()
