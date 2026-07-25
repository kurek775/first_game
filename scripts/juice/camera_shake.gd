## CameraShake — trauma-driven camera jitter.
##
## Trauma accumulates and decays; the offset is trauma SQUARED, so small hits
## are barely felt and big ones are unmistakable. Linear shake reads as
## constant noise no matter how hard you were hit.
##
## Offsets the Camera3D inside the SpringArm3D rather than the arm itself, so
## the arm's collision test still runs along the true, unshaken direction and
## the camera cannot jitter itself through a wall.
class_name CameraShake
extends Node

## The Camera3D to offset. Must be a child of the spring arm.
@export var camera: Node3D
@export_range(0.5, 20.0, 0.5) var decay := 6.5
@export_range(0.0, 2.0, 0.01) var max_offset := 0.32
@export_range(0.0, 15.0, 0.5) var max_roll_deg := 2.5

var _trauma := 0.0
var _base_position := Vector3.ZERO


func _ready() -> void:
	if camera != null:
		_base_position = camera.position
	Juice.shake_requested.connect(add_trauma)


func add_trauma(strength: float) -> void:
	_trauma = clampf(_trauma + strength, 0.0, 1.0)


func _process(delta: float) -> void:
	if camera == null:
		return

	if _trauma <= 0.0:
		camera.position = _base_position
		camera.rotation.z = 0.0
		return

	_trauma = maxf(0.0, _trauma - decay * delta)
	var amount := _trauma * _trauma

	camera.position = _base_position + Vector3(
		randf_range(-1.0, 1.0) * max_offset * amount,
		randf_range(-1.0, 1.0) * max_offset * amount,
		0.0
	)
	camera.rotation.z = deg_to_rad(max_roll_deg) * amount * randf_range(-1.0, 1.0)
