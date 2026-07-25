## PlayerMotor — owns how movement FEELS.
##
## Reads an intent (`wish_direction`, `wants_sprint`) written by the parent each
## frame, turns it into velocity on the parent CharacterBody3D, and calls
## move_and_slide(). Every tuning knob lives here so tuning never means editing
## input or camera code.
##
## Ordering note (Godot-specific): _physics_process runs in tree order, parent
## before child. Player is this node's parent, so its intent is always written
## before this node reads it.

class_name PlayerMotor
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

var _body: CharacterBody3D
var _was_sprinting := false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	assert(_body != null, "PlayerMotor must be a direct child of a CharacterBody3D.")


func _physics_process(delta: float) -> void:
	var on_floor := _body.is_on_floor()

	_apply_gravity(delta, on_floor)
	_apply_horizontal(delta, on_floor)

	# Capture fall speed before the move resolves it to zero.
	var fall_speed := maxf(0.0, -_body.velocity.y)
	_body.move_and_slide()

	if not on_floor and _body.is_on_floor():
		landed.emit(fall_speed)

	_update_sprint_state(on_floor)


## Current horizontal speed in m/s. Handy for HUDs and animation later.
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
	var target := wish_direction * (sprint_speed if wants_sprint else walk_speed)
	var current := Vector3(_body.velocity.x, 0.0, _body.velocity.z)

	var rate: float
	if wish_direction.is_zero_approx():
		rate = ground_friction if on_floor else air_friction
	else:
		rate = ground_accel if on_floor else air_accel

	# move_toward handles decelerate-then-accelerate on direction changes in one
	# step, which reads as pleasant weight rather than an instant pivot.
	current = current.move_toward(target, rate * delta)

	_body.velocity.x = current.x
	_body.velocity.z = current.z


func _update_sprint_state(on_floor: bool) -> void:
	var sprinting := wants_sprint and on_floor and not wish_direction.is_zero_approx()
	if sprinting == _was_sprinting:
		return
	_was_sprinting = sprinting
	sprint_changed.emit(sprinting)
