extends Node3D


@onready var cam := $Camera3D
@onready var Attr := cam.get("attributes") as CameraAttributes

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimBoya.play("Olas")
	$AnimCam.play("Cam")
	pass # Replace with function body.

func desenfoque():
	var Anim := create_tween()
	Anim.tween_property(Attr, "dof_blur_amount", 0.5,1)

func enfoque():
	var Anim := create_tween()
	Anim.tween_property(Attr, "dof_blur_amount", 0,1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
