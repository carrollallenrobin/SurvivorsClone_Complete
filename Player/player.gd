extends CharacterBody2D


var movement_speed = 40.0
var hp = 80
var maxhp = 80
var last_movement = Vector2.UP
var time = 0

var experience = 0
var experience_level = 1
var collected_experience = 0

#Attacks
var iceSpear = preload("res://Player/Attack/ice_spear.tscn")
var tornado = preload("res://Player/Attack/tornado.tscn")
var javelin = preload("res://Player/Attack/javelin.tscn")

#AttackNodes
@onready var iceSpearTimer = get_node("%IceSpearTimer")
@onready var iceSpearAttackTimer = get_node("%IceSpearAttackTimer")
@onready var tornadoTimer = get_node("%TornadoTimer")
@onready var tornadoAttackTimer = get_node("%TornadoAttackTimer")
@onready var javelinBase = get_node("%JavelinBase")

#UPGRADES
var collected_upgrades = []
var upgrade_options = []
var armor = 0
var speed = 0
var spell_cooldown = 0
var spell_size = 0
var spell_attack_speed = 0

#IceSpear
var icespear_ammo = 0
var icespear_baseammo = 0
var icespear_attackspeed = 0.125
var icespear_level = 0
var sword_spawn_step = 0
var sword_spawned_count = 0
var sword_batch_paused = false

#Tornado
var tornado_ammo = 0
var tornado_baseammo = 0
var tornado_attackspeed = 3
var tornado_level = 0

#Javelin
var javelin_ammo = 0
var javelin_level = 0
var javelin_bonus_damage = 0
var javelin_bonus_knockback = 0


#Enemy Related
var enemy_close = []


@onready var sprite = $Sprite2D
var run_frame = 0
var run_anim_time = 0.0

#GUI
@onready var expBar = get_node("%ExperienceBar")
@onready var lblLevel = get_node("%lbl_level")
@onready var levelPanel = get_node("%LevelUp")
@onready var upgradeOptions = get_node("%UpgradeOptions")
@onready var itemOptions = preload("res://Utility/item_option.tscn")
@onready var sndLevelUp = get_node("%snd_levelup")
@onready var healthBar = get_node("%HealthBar")
@onready var lblTimer = get_node("%lblTimer")
@onready var collectedWeapons = get_node("%CollectedWeapons")
@onready var collectedUpgrades = get_node("%CollectedUpgrades")
@onready var itemContainer = preload("res://Player/GUI/item_container.tscn")

@onready var deathPanel = get_node("%DeathPanel")
@onready var lblResult = get_node("%lbl_Result")
@onready var sndVictory = get_node("%snd_victory")
@onready var sndLose = get_node("%snd_lose")
@onready var clearPanel = get_node("%ClearPanel")
@onready var lblClear = get_node("%lbl_Clear")
@onready var btnEnter = get_node("%btn_enter")
@onready var lblStage = get_node("%lblStage")

#Signal
signal playerdeath
signal stage_confirmed

func _ready():
	upgrade_character("icespear1")
	attack()
	set_expbar(experience, calculate_experiencecap())
	_on_hurt_box_hurt(0,0,0)

func _physics_process(delta):
	movement(delta)

func movement(delta):
	var x_mov = Input.get_action_strength("right") - Input.get_action_strength("left")
	var y_mov = Input.get_action_strength("down") - Input.get_action_strength("up")
	var mov = Vector2(x_mov,y_mov)
	if mov.x > 0:
		sprite.flip_h = true
	elif mov.x < 0:
		sprite.flip_h = false

	if mov != Vector2.ZERO:
		last_movement = mov
		if sprite.hframes > 1:
			run_anim_time += delta
			if run_anim_time >= 0.1:
				run_anim_time = 0.0
				run_frame = (run_frame + 1) % (sprite.hframes - 1)
			sprite.frame = run_frame + 1
	elif sprite.hframes > 1:
		sprite.frame = 0
	
	velocity = mov.normalized()*movement_speed
	move_and_slide()

func attack():
	if icespear_level > 0 and not sword_batch_paused:
		iceSpearTimer.wait_time = icespear_attackspeed * (1 - spell_cooldown)
		if iceSpearTimer.is_stopped():
			iceSpearTimer.start()
	if tornado_level > 0:
		tornadoTimer.wait_time = tornado_attackspeed * (1 - spell_cooldown)
		if tornadoTimer.is_stopped():
			tornadoTimer.start()
	if javelin_level > 0:
		spawn_javelin()

func _on_hurt_box_hurt(damage, _angle, _knockback):
	hp -= clamp(damage-armor, 1.0, 999.0)
	healthBar.max_value = maxhp
	healthBar.value = hp
	if hp <= 0:
		death()

func _on_ice_spear_timer_timeout():
	icespear_ammo += icespear_baseammo
	if iceSpearAttackTimer.is_stopped():
		_spawn_flying_sword()


func _on_ice_spear_attack_timer_timeout():
	_spawn_flying_sword()

func _spawn_flying_sword():
	if icespear_ammo <= 0:
		iceSpearAttackTimer.stop()
		return
	var icespear_attack = iceSpear.instantiate()
	icespear_attack.position = position
	icespear_attack.level = icespear_level
	icespear_attack.spawn_direction = next_sword_direction()
	add_child(icespear_attack)
	icespear_ammo -= 1
	sword_spawned_count += 1
	if sword_spawned_count % 50 == 0:
		_pause_sword_spawning()
		return
	if icespear_ammo > 0:
		if iceSpearAttackTimer.is_stopped():
			iceSpearAttackTimer.start()
	else:
		iceSpearAttackTimer.stop()

func _pause_sword_spawning():
	sword_batch_paused = true
	iceSpearTimer.stop()
	iceSpearAttackTimer.stop()
	get_tree().create_timer(5.0).timeout.connect(_resume_sword_spawning)

func _resume_sword_spawning():
	sword_batch_paused = false
	if not is_inside_tree() or icespear_level <= 0:
		return
	if icespear_ammo > 0:
		iceSpearAttackTimer.start()
	attack()

func next_sword_direction():
	var degrees = sword_spawn_step * 10
	sword_spawn_step = (sword_spawn_step + 1) % 36
	return Vector2.UP.rotated(deg_to_rad(degrees))

func _on_tornado_timer_timeout():
	tornado_ammo += tornado_baseammo
	tornadoAttackTimer.start()

func _on_tornado_attack_timer_timeout():
	if tornado_ammo > 0:
		var tornado_attack = tornado.instantiate()
		tornado_attack.position = position
		tornado_attack.last_movement = last_movement
		tornado_attack.level = tornado_level
		add_child(tornado_attack)
		tornado_ammo -= 1
		if tornado_ammo > 0:
			tornadoAttackTimer.start()
		else:
			tornadoAttackTimer.stop()

func spawn_javelin():
	var get_javelin_total = javelinBase.get_child_count()
	var calc_spawns = javelin_ammo - get_javelin_total
	while calc_spawns > 0:
		var javelin_spawn = javelin.instantiate()
		javelin_spawn.global_position = global_position
		javelinBase.add_child(javelin_spawn)
		calc_spawns -= 1
	#Upgrade Javelin
	var get_javelins = javelinBase.get_children()
	for i in get_javelins:
		if i.has_method("update_javelin"):
			i.update_javelin()

func get_nearest_enemy():
	var nearest_enemy = null
	var nearest_distance_squared = INF
	
	for enemy in enemy_close:
		if not is_instance_valid(enemy):
			continue
		
		var distance_squared = global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy
	
	return nearest_enemy

func get_nearest_target():
	var nearest_enemy = get_nearest_enemy()
	if nearest_enemy != null:
		return nearest_enemy.global_position
	
	return global_position + Vector2.UP * 100.0


func _on_enemy_detection_area_body_entered(body):
	if not enemy_close.has(body):
		enemy_close.append(body)

func _on_enemy_detection_area_body_exited(body):
	if enemy_close.has(body):
		enemy_close.erase(body)


func _on_grab_area_area_entered(area):
	if area.is_in_group("loot"):
		area.target = self

func _on_collect_area_area_entered(area):
	if area.is_in_group("loot"):
		var gem_exp = area.collect()
		calculate_experience(gem_exp)

func calculate_experience(gem_exp):
	var exp_required = calculate_experiencecap()
	collected_experience += gem_exp
	if experience + collected_experience >= exp_required: #level up
		collected_experience -= exp_required-experience
		experience_level += 1
		experience = 0
		exp_required = calculate_experiencecap()
		levelup()
	else:
		experience += collected_experience
		collected_experience = 0
	
	set_expbar(experience, exp_required)

func calculate_experiencecap():
	var exp_cap = experience_level
	if experience_level < 20:
		exp_cap = experience_level*5
	elif experience_level < 40:
		exp_cap + 95 * (experience_level-19)*8
	else:
		exp_cap = 255 + (experience_level-39)*12
		
	return exp_cap
		
func set_expbar(set_value = 1, set_max_value = 100):
	expBar.value = set_value
	expBar.max_value = set_max_value

func levelup():
	lblLevel.text = str("Level: ",experience_level)
	var options = 0
	var optionsmax = 3
	while options < optionsmax:
		var item = get_random_item()
		if item == null:
			break
		var option_choice = itemOptions.instantiate()
		option_choice.item = item
		option_choice.shown_level = _offer_level(item)
		upgradeOptions.add_child(option_choice)
		options += 1
	if options == 0:
		return
	sndLevelUp.play()
	levelPanel.visible = true
	var tween = levelPanel.create_tween()
	tween.tween_property(levelPanel,"position",Vector2(220,50),0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.play()
	get_tree().paused = true

func upgrade_character(upgrade):
	match upgrade:
		"icespear1":
			icespear_level = 1
			icespear_baseammo += 1
		"icespear2":
			icespear_level = 2
			icespear_attackspeed *= 0.8
		"icespear3":
			icespear_level = 3
			icespear_attackspeed *= 0.8
		"icespear4":
			icespear_level = 4
			icespear_attackspeed *= 0.8
		"tornado1":
			tornado_level = 1
			tornado_baseammo += 1
		"tornado2":
			tornado_level = 2
			tornado_baseammo += 1
		"tornado3":
			tornado_level = 3
			tornado_attackspeed -= 0.5
		"tornado4":
			tornado_level = 4
			tornado_baseammo += 1
		"javelin1":
			javelin_level = 1
			javelin_ammo = 1
		"javelin2":
			javelin_level = 2
		"javelin3":
			javelin_level = 3
		"javelin4":
			javelin_level = 4
			if collected_upgrades.count("javelin4") > 0:
				javelin_bonus_damage += 5
				javelin_bonus_knockback += 20
		"armor1","armor2","armor3","armor4":
			armor += 1
		"speed1","speed2","speed3","speed4":
			movement_speed += 20.0
		"tome1","tome2","tome3","tome4":
			spell_size += 0.10
		"scroll1","scroll2","scroll3","scroll4":
			spell_cooldown += 0.05
		"ring1","ring2":
			spell_attack_speed += 0.20
		"food":
			hp += 20
			hp = clamp(hp,0,maxhp)
	adjust_gui_collection(upgrade)
	attack()
	var option_children = upgradeOptions.get_children()
	for i in option_children:
		i.queue_free()
	upgrade_options.clear()
	collected_upgrades.append(upgrade)
	levelPanel.visible = false
	levelPanel.position = Vector2(800,50)
	get_tree().paused = false
	calculate_experience(0)
	
func _upgrade_lines():
	return [
		["icespear1", "icespear2", "icespear3", "icespear4"],
		["javelin1", "javelin2", "javelin3", "javelin4"],
		["tornado1", "tornado2", "tornado3", "tornado4"],
		["armor1", "armor2", "armor3", "armor4"],
		["speed1", "speed2", "speed3", "speed4"],
		["tome1", "tome2", "tome3", "tome4"],
		["scroll1", "scroll2", "scroll3", "scroll4"],
		["ring1", "ring2"],
	]

func _line_for(upgrade_name):
	for line in _upgrade_lines():
		if upgrade_name in line:
			return line
	return []

func _line_rank(line):
	var count = 0
	for upgrade_name in line:
		count += collected_upgrades.count(upgrade_name)
	return count

func _offer_level(upgrade_name):
	var line = _line_for(upgrade_name)
	if line.size() == 0:
		return -1
	return _line_rank(line) + 1

func _pool_allows(upgrade_name):
	return stage_upgrade_pool.size() == 0 or upgrade_name in stage_upgrade_pool

func get_random_item():
	var dblist = []
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades:
			continue
		if i in upgrade_options:
			continue
		if UpgradeDb.UPGRADES[i]["type"] == "item":
			continue
		if not _pool_allows(i):
			continue
		if UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0:
			var to_add = true
			for n in UpgradeDb.UPGRADES[i]["prerequisite"]:
				if not n in collected_upgrades:
					to_add = false
			if to_add:
				dblist.append(i)
		else:
			dblist.append(i)
	for line in _upgrade_lines():
		var cap = line[line.size() - 1]
		if not cap in collected_upgrades:
			continue
		if cap in upgrade_options or cap in dblist:
			continue
		if not _pool_allows(cap):
			continue
		dblist.append(cap)
	if dblist.size() > 0:
		var randomitem = dblist.pick_random()
		upgrade_options.append(randomitem)
		return randomitem
	else:
		return null

func change_time(argtime = 0):
	time = argtime
	var get_m = int(time/60.0)
	var get_s = time % 60
	if get_m < 10:
		get_m = str(0,get_m)
	if get_s < 10:
		get_s = str(0,get_s)
	lblTimer.text = str(get_m,":",get_s)

var stage_upgrade_pool: Array[String] = [
	"icespear1", "icespear2", "icespear3", "icespear4",
	"ring1", "ring2",
	"speed1", "speed2", "speed3", "speed4",
]

func set_stage_label(stage_number):
	lblStage.text = str("Stage ", stage_number)

func set_stage_upgrades(allowed: Array):
	stage_upgrade_pool.clear()
	for upgrade_name in allowed:
		stage_upgrade_pool.append(upgrade_name)

func show_stage_clear(message, button_text):
	lblClear.text = message
	btnEnter.text = button_text
	clearPanel.position = Vector2(220, -220)
	clearPanel.visible = true
	get_tree().paused = true
	sndVictory.play()
	var tween = clearPanel.create_tween()
	tween.tween_property(clearPanel, "position", Vector2(220, 90), 0.45).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()

func _on_btn_enter_click_end():
	clearPanel.visible = false
	emit_signal("stage_confirmed")

func adjust_gui_collection(upgrade):
	var get_upgraded_displayname = UpgradeDb.UPGRADES[upgrade]["displayname"]
	var get_type = UpgradeDb.UPGRADES[upgrade]["type"]
	if get_type != "item":
		var get_collected_displaynames = []
		for i in collected_upgrades:
			get_collected_displaynames.append(UpgradeDb.UPGRADES[i]["displayname"])
		if not get_upgraded_displayname in get_collected_displaynames:
			var new_item = itemContainer.instantiate()
			new_item.upgrade = upgrade
			match get_type:
				"weapon":
					collectedWeapons.add_child(new_item)
				"upgrade":
					collectedUpgrades.add_child(new_item)

func death():
	deathPanel.visible = true
	emit_signal("playerdeath")
	get_tree().paused = true
	var tween = deathPanel.create_tween()
	tween.tween_property(deathPanel,"position",Vector2(220,50),3.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()
	lblResult.text = "You Lose"
	sndLose.play()


func _on_btn_menu_click_end():
	get_tree().paused = false
	var _level = get_tree().change_scene_to_file("res://TitleScreen/menu.tscn")
