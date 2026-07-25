## Player — the thin root of the player scene.
##
## Its only jobs: read input, express it as a world-space direction relative to
## where the camera is pointing, hand that to the Motor, and turn the visual mesh
## to face travel. All movement maths lives in PlayerMotor; all mouse look lives
## in CameraRig.
##
## It also re-emits its components' signals as its own, so the rest of the game
## only ever needs to know about `Player` — nothing outside reaches into
## $Motor or $CameraRig.

class_name Player
extends CharacterBody3D

signal sprint_changed(sprinting: bool)
signal landed(impact_speed: float)

## How quickly the mesh swings around to face the direction of travel.
## Higher = snappier turns. This is cosmetic; it does not affect movement.
@export_range(1.0, 40.0, 0.5) var turn_speed := 12.0

@onready var motor: PlayerMotor = $Motor
@onready var camera_rig: CameraRig = $CameraRig
@onready var visual: Node3D = $Visual


func _ready() -> void:
	motor.sprint_changed.connect(func(s: bool) -> void: sprint_changed.emit(s))
	motor.landed.connect(func(speed: float) -> void: landed.emit(speed))
	# The rig reports the condition; deciding that "hide the body" is the answer
	# is the player's business, not the camera's.
	camera_rig.occluded_changed.connect(func(occluded: bool) -> void: visual.visible = not occluded)


func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	motor.wish_direction = _camera_relative(input_vec)
	motor.wants_sprint = Input.is_action_pressed("sprint")

	_face_travel(delta)


## Convert 2D input into a world direction on the XZ plane, relative to the
## camera's yaw. The rig only ever rotates around Y, so its basis is already
## flat — but we zero out Y anyway so a future free-look camera can't tilt us.
func _camera_relative(input_vec: Vector2) -> Vector3:
	var b := camera_rig.global_transform.basis
	var dir := b.x * input_vec.x + b.z * input_vec.y
	dir.y = 0.0
	# limit_length, not normalized: preserves analog stick magnitude later.
	return dir.limit_length(1.0)


func _face_travel(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.04:
		return

	# A Node3D's forward is -Z, so the yaw that points -Z along `flat` is this.
	var target_yaw := atan2(-flat.x, -flat.z)
	# Exponential smoothing — framerate-independent, unlike a raw lerp weight.
	var weight := 1.0 - exp(-turn_speed * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
