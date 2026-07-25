## CharacterMotor — owns how movement FEELS. Used by the player, the training
## dummy, and (from stage 4) enemies: none of them need different movement code.
##
## Reads an intent (`wish_direction`, `wants_sprint`, `speed_scale`) written by
## the parent each frame, turns it into velocity on the parent CharacterBody3D,
## and calls move_and_slide(). Every tuning knob lives here so tuning never
## means editing input or camera code.
##
## Velocity is tracked in two parts. `_planar` is what the input asked for;
## `_impulse` is external shoves (knockback) that decay on their own. They have
## to be separate: if knockback just wrote into body.velocity, the very next
## frame's move_toward would erase it before it moved anybody.
##
## Ordering note (Godot-specific): _physics_process runs in tree order, parent
## before child. Player is this node's parent, so its intent is always written
## before this node reads it.

class_name CharacterMotor
extends Node

## Fired when the player starts or stops actually sprinting (not merely holding
## the key — you must be grounded and moving).
signal sprint_changed(sprinting: bool)

## Fired the frame we touch the ground after being airborne.
## `impact_speed` is the downward speed at the moment of contact, in m/s.
signal landed(impact_speed: float)

@export_group("Speed")
## Top speed with no sprint, in metres/second. A brisk jog is ~4.5.
@export_range(1.0, 12.0, 0.1) var walk_speed := 4.5
## Top speed while holding sprint.
@export_range(1.0, 20.0, 0.1) var sprint_speed := 7.5

@export_group("Feel")
## How fast we reach target speed on the ground (m/s²). Higher = snappier,
## more arcade. Lower = more weight.
@export_range(1.0, 200.0, 1.0) var ground_accel := 60.0
## How fast we stop on the ground when input is released (m/s²).
@export_range(1.0, 200.0, 1.0) var ground_friction := 45.0
## Air control. Keep well below ground_accel or jumps feel weightless.
@export_range(0.0, 200.0, 1.0) var air_accel := 12.0
## Passive horizontal drag while airborne.
@export_range(0.0, 200.0, 1.0) var air_friction := 1.0
## How quickly knockback bleeds off (m/s²). Lower = you slide further.
@export_range(1.0, 100.0, 1.0) var impulse_damping := 16.0

@export_group("Gravity")
## Deliberately much stronger than real gravity (9.8) — real gravity feels
## floaty in games. Tune this together with the speeds above.
@export_range(1.0, 80.0, 0.5) var gravity := 26.0
## Terminal velocity, so long falls stay predictable.
@export_range(5.0, 200.0, 1.0) var max_fall_speed := 40.0

## Desired horizontal move direction in WORLD space, length 0..1.
## Written by Player every physics frame.
var wish_direction := Vector3.ZERO
## Whether the sprint input is held. Written by Player every physics frame.
var wants_sprint := false
## Multiplier on top speed. Attacking, blocking and being staggered all slow
## the player down by writing this rather than by touching walk_speed.
var speed_scale := 1.0

var _body: CharacterBody3D
var _planar := Vector3.ZERO
var _impulse := Vector3.ZERO
var _was_sprinting := false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	assert(_body != null, "CharacterMotor must be a direct child of a CharacterBody3D.")


func _physics_process(delta: float) -> void:
	var on_floor := _body.is_on_floor()

	_apply_gravity(delta, on_floor)
	_apply_horizontal(delta, on_floor)

	# Capture fall speed before the move resolves it to zero.
	var fall_speed := maxf(0.0, -_body.velocity.y)
	_body.move_and_slide()

	# move_and_slide resolves collisions by rewriting velocity. Fold that back
	# into _planar, or running into a wall stores up speed that fires you
	# sideways the moment you step away from it.
	_planar.x = _body.velocity.x - _impulse.x
	_planar.z = _body.velocity.z - _impulse.z

	if not on_floor and _body.is_on_floor():
		landed.emit(fall_speed)

	_update_sprint_state(on_floor)


## The body this motor drives. Knockback needs it to work out push direction.
func get_body() -> CharacterBody3D:
	return _body


## Shove this body. Decays at `impulse_damping` and is applied on top of
## whatever the input is asking for, so you can still fight the knockback.
func add_impulse(impulse: Vector3) -> void:
	_impulse += impulse


## Current horizontal speed in m/s, knockback included. Handy for HUDs.
func get_ground_speed() -> float:
	return Vector2(_body.velocity.x, _body.velocity.z).length()


func is_sprinting() -> bool:
	return _was_sprinting


func _apply_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
		# A small downward bias keeps us glued to slopes and stairs instead of
		# skipping off them. move_and_slide() with a floor snap needs *some*
		# downward velocity to detect the floor at all.
		_body.velocity.y = -2.0
		return
	_body.velocity.y = maxf(_body.velocity.y - gravity * delta, -max_fall_speed)


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	var top_speed := (sprint_speed if wants_sprint else walk_speed) * speed_scale
	var target := wish_direction * top_speed

	var rate: float
	if wish_direction.is_zero_approx():
		rate = ground_friction if on_floor else air_friction
	else:
		rate = ground_accel if on_floor else air_accel

	# move_toward handles decelerate-then-accelerate on direction changes in one
	# step, which reads as pleasant weight rather than an instant pivot.
	_planar = _planar.move_toward(target, rate * delta)
	_impulse = _impulse.move_toward(Vector3.ZERO, impulse_damping * delta)

	_body.velocity.x = _planar.x + _impulse.x
	_body.velocity.z = _planar.z + _impulse.z


func _update_sprint_state(on_floor: bool) -> void:
	var sprinting := wants_sprint and on_floor and not wish_direction.is_zero_approx()
	if sprinting == _was_sprinting:
		return
	_was_sprinting = sprinting
	sprint_changed.emit(sprinting)
