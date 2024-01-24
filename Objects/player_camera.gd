extends Camera3D

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().call_group("directional_billboards", "set_camera", self)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
