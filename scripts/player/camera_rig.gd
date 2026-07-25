## CameraRig — owns mouse look and nothing else.
##
## Yaw goes on this node, pitch goes on the SpringArm3D child. Keeping them on
## separate nodes avoids gimbal problems and means the arm's own collision test
## always runs along the true camera direction.
##
## This node is a child of the player body, but the body never rotates (the
## Visual child does), so camera yaw stays independent of which way the
## character is facing.

class_name CameraRig
extends Node3D

## Emitted when the spring arm collapses far enough that the camera has ended up
## inside the character. The rig does not own the mesh, so it just announces the
## condition and lets the owner decide what to hide.
signal occluded_changed(occluded: bool)

## Radians of rotation per pixel of mouse movement.
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity := 0.0025
## How far down you can look, in degrees (negative = looking down).
@export_range(-89.0, 0.0, 1.0) var pitch_min_deg := -55.0
## How far up you can look, in degrees.
@export_range(0.0, 89.0, 1.0) var pitch_max_deg := 30.0
@export var invert_y := false
## Below this arm length (metres) the camera is close enough to be inside the
## character mesh, and `occluded_changed` fires.
@export_range(0.0, 5.0, 0.1) var occlusion_distance := 1.9

@onready var _arm: SpringArm3D = $SpringArm3D

var _pitch := 0.0
var _occluded := false


func _ready() -> void:
	_pitch = _arm.rotation.x
	_capture_mouse(true)


func _process(_delta: float) -> void:
	# get_hit_length() is the arm's *current* length after its collision sweep,
	# which is shorter than spring_length whenever something is in the way.
	var occluded := _arm.get_hit_length() < occlusion_distance
	if occluded == _occluded:
		return
	_occluded = occluded
	occluded_changed.emit(occluded)


# _unhandled_input, not _input: anything the UI consumes first (a pause menu,
# later) will never reach the camera.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).relative)
		return

	if event.is_action_pressed("ui_cancel"):
		_capture_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
		return

	# Click back into the game after Esc.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse(true)


func _look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity

	var sign_y := -1.0 if invert_y else 1.0
	_pitch = clampf(
		_pitch - relative.y * mouse_sensitivity * sign_y,
		deg_to_rad(pitch_min_deg),
		deg_to_rad(pitch_max_deg)
	)
	_arm.rotation.x = _pitch


func _capture_mouse(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
