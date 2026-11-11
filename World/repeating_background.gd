extends Sprite2D

@onready var player = get_tree().get_first_node_in_group("player")
var tile_size := Vector2.ONE


func _ready():
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	tile_size = texture_size * scale


func _process(_delta):
	if not is_instance_valid(player):
		return

	global_position = Vector2(
		floor(player.global_position.x / tile_size.x) * tile_size.x,
		floor(player.global_position.y / tile_size.y) * tile_size.y
	)
