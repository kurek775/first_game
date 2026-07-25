## Player — the thin root of the player scene.
##
## Reads input, expresses it as a world-space direction relative to where the
## camera is pointing, hands that to the Motor, and turns the visual mesh. All
## movement maths lives in CharacterMotor, mouse look in CameraRig, and every
## combat rule in the components under scripts/combat — none of which know
## anything about the player specifically.
##
## It also re-emits its components' signals as its own, so the rest of the game
## only ever needs to know about `Player`.

class_name Player
extends CharacterBody3D

signal sprint_changed(sprinting: bool)
signal landed(impact_speed: float)
signal died

## How quickly the mesh swings around to face its target direction.
## Cosmetic; it does not affect movement.
@export_range(1.0, 40.0, 0.5) var turn_speed := 12.0

@onready var motor: CharacterMotor = $Motor
@onready var camera_rig: CameraRig = $CameraRig
@onready var visual: Node3D = $Visual
@onready var health: Health = $Health
@onready var blocker: Blocker = $Blocker
@onready var attack: MeleeAttack = $MeleeAttack
@onready var reaction: HitReaction = $HitReaction


func _ready() -> void:
	motor.sprint_changed.connect(func(s: bool) -> void: sprint_changed.emit(s))
	motor.landed.connect(func(speed: float) -> void: landed.emit(speed))
	health.died.connect(func() -> void: died.emit())
	# The rig reports the condition; deciding that "hide the body" is the answer
	# is the player's business, not the camera's.
	camera_rig.occluded_changed.connect(func(occluded: bool) -> void: visual.visible = not occluded)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		_release_all_intent()
		return

	# A landed blow takes control away for a moment. This is the whole reason
	# trading hits is a bad idea and blocking is worth doing.
	if reaction.is_staggered():
		_release_all_intent()
		if attack.is_swinging():
			attack.cancel()
		return

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	motor.wish_direction = _camera_relative(input_vec)

	# Guard drops the instant you commit to a swing — you cannot do both.
	blocker.set_blocking(Input.is_action_pressed("block") and not attack.is_swinging())

	if Input.is_action_just_pressed("attack"):
		attack.try_swing()

	motor.wants_sprint = (
		Input.is_action_pressed("sprint")
		and not blocker.is_blocking()
		and not attack.is_swinging()
	)
	motor.speed_scale = _speed_scale()

	_face(delta)


func _release_all_intent() -> void:
	motor.wish_direction = Vector3.ZERO
	motor.wants_sprint = false
	motor.speed_scale = 1.0
	blocker.set_blocking(false)


func _speed_scale() -> float:
	if attack.is_swinging():
		return attack.move_scale
	if blocker.is_blocking():
		return blocker.move_scale
	return 1.0


## Convert 2D input into a world direction on the XZ plane, relative to the
## camera's yaw. The rig only ever rotates around Y, so its basis is already
## flat — but we zero out Y anyway so a future free-look camera can't tilt us.
func _camera_relative(input_vec: Vector2) -> Vector3:
	var b := camera_rig.global_transform.basis
	var dir := b.x * input_vec.x + b.z * input_vec.y
	dir.y = 0.0
	# limit_length, not normalized: preserves analog stick magnitude later.
	return dir.limit_length(1.0)


## Normally the mesh faces where you are travelling. While swinging or
## guarding it faces where the CAMERA is pointing instead — otherwise your
## blade lands wherever you happened to be strafing, which is unaimable.
func _face(delta: float) -> void:
	var target_yaw: float

	if attack.is_swinging() or blocker.is_blocking():
		target_yaw = camera_rig.rotation.y
	else:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if flat.length_squared() < 0.04:
			return
		# A Node3D's forward is -Z, so the yaw that points -Z along `flat`.
		target_yaw = atan2(-flat.x, -flat.z)

	# Exponential smoothing — framerate-independent, unlike a raw lerp weight.
	var weight := 1.0 - exp(-turn_speed * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
