extends Node

const DURATION := 600
const WEAK = preload("res://Enemy/enemy_kobold_weak.tscn")
const STRONG = preload("res://Enemy/enemy_kobold_strong.tscn")
const CYCLOPS = preload("res://Enemy/enemy_cyclops.tscn")
const JUGGERNAUT = preload("res://Enemy/enemy_juggernaut.tscn")
const PORTAL = preload("res://World/portal.tscn")

var stage := 1
var portal: Area2D
var awaiting_confirm := false

@onready var spawner = get_parent().get_node("EnemySpawner")
@onready var actors = get_parent().get_node("Actors")
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	spawner.connect("stage_elapsed", Callable(self, "_on_stage_elapsed"))
	player.connect("stage_confirmed", Callable(self, "_on_stage_confirmed"))
	_start_stage()

func _process(_delta):
	if portal == null or awaiting_confirm:
		return
	if _living_enemies() == 0:
		_open_confirm()

func _start_stage():
	player.set_stage_label(stage)
	player.set_stage_upgrades(_upgrades_for(stage))
	spawner.begin_stage(_spawns_for(stage), DURATION)

func _on_stage_elapsed():
	_spawn_portal()

func _spawn_portal():
	if is_instance_valid(portal):
		return
	portal = PORTAL.instantiate() as Area2D
	portal.global_position = _portal_position()
	actors.add_child(portal)
	portal.connect("body_entered", Callable(self, "_on_portal_body_entered"))
	var pulse = portal.create_tween().set_loops()
	pulse.tween_property(portal, "scale", Vector2(1.12, 1.12), 0.55)
	pulse.tween_property(portal, "scale", Vector2(0.9, 0.9), 0.55)
	if _living_enemies() == 0:
		_open_confirm()

func _on_portal_body_entered(body):
	if body.is_in_group("player"):
		_open_confirm()

func _open_confirm():
	if awaiting_confirm or player.deathPanel.visible:
		return
	awaiting_confirm = true
	if stage >= 2:
		player.show_stage_clear("You Win", "Menu")
	else:
		player.show_stage_clear("Stage Clear\nEnter stage 2?", "Enter")

func _on_stage_confirmed():
	if stage >= 2:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://TitleScreen/menu.tscn")
		return
	stage += 1
	_clear_field()
	portal = null
	awaiting_confirm = false
	_start_stage()
	get_tree().paused = false

func _clear_field():
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	if is_instance_valid(portal):
		portal.queue_free()

func _living_enemies():
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count

func _portal_position():
	var view = player.get_viewport_rect().size
	var margin = 56.0
	var half = view * 0.5
	var offset = Vector2(
		randf_range(-half.x + margin, half.x - margin),
		randf_range(-half.y + margin, half.y - margin)
	)
	if offset.length() < 80.0:
		if offset.length_squared() < 0.001:
			offset = Vector2.RIGHT
		offset = offset.normalized() * 80.0
	return player.global_position + offset

func _upgrades_for(index) -> Array[String]:
	if index > 1:
		return []
	var list: Array[String] = [
		"icespear1", "icespear2", "icespear3", "icespear4",
		"ring1", "ring2",
		"speed1", "speed2", "speed3", "speed4",
	]
	return list

func _spawns_for(index):
	var list: Array[Spawn_info] = []
	if index <= 1:
		list.append(_info(0, 119, WEAK, 5, 1))
		list.append(_info(120, 599, WEAK, 5, 0))
		list.append(_info(300, 449, STRONG, 5, 3))
		list.append(_info(450, 599, STRONG, 5, 1))
	else:
		list.append(_info(0, 299, CYCLOPS, 5, 2))
		list.append(_info(300, 599, CYCLOPS, 5, 1))
		list.append(_info(300, 599, JUGGERNAUT, 5, 9))
	return list

func _info(time_start, time_end, enemy, enemy_num, enemy_spawn_delay):
	var info = Spawn_info.new()
	info.time_start = time_start
	info.time_end = time_end
	info.enemy = enemy
	info.enemy_num = enemy_num
	info.enemy_spawn_delay = enemy_spawn_delay
	return info
