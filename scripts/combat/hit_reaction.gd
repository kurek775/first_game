## HitReaction — what a body does when a blow connects: a knockback impulse
## plus a brief stagger during which it cannot act.
##
## Owns the knockback reduction for blocked hits, because it is the thing that
## applies knockback. Blocker owns the damage reduction, because it is the thing
## that decides a block happened. Each component reduces only what it applies.

class_name HitReaction
extends Node

signal stagger_started(duration: float)
signal stagger_finished

## The motor to push. Knockback has to go through it rather than writing
## velocity directly, or the motor overwrites the impulse on the same frame.
@export var motor: CharacterMotor

@export_group("Stagger")
## Seconds of lost control after an unblocked hit.
@export_range(0.0, 2.0, 0.01) var stagger_time := 0.28
## Seconds of lost control after a blocked hit. Should be short enough that
## blocking stays worth doing.
@export_range(0.0, 2.0, 0.01) var blocked_stagger_time := 0.12

@export_group("Knockback")
@export_range(0.0, 3.0, 0.05) var knockback_scale := 1.0
## Multiplier applied on top when the blow was blocked.
@export_range(0.0, 1.0, 0.05) var blocked_knockback_scale := 0.35

var _stagger := 0.0


func is_staggered() -> bool:
	return _stagger > 0.0


func _physics_process(delta: float) -> void:
	if _stagger <= 0.0:
		return
	_stagger -= delta
	if _stagger <= 0.0:
		_stagger = 0.0
		stagger_finished.emit()


## Wired to Hurtbox.hit_taken.
func react(hit: HitInfo) -> void:
	_apply(hit, knockback_scale, stagger_time)


## Wired to Hurtbox.hit_blocked.
func react_blocked(hit: HitInfo) -> void:
	_apply(hit, knockback_scale * blocked_knockback_scale, blocked_stagger_time)


func _apply(hit: HitInfo, scale: float, duration: float) -> void:
	if motor != null and hit.knockback > 0.0:
		motor.add_impulse(_push_direction(hit) * hit.knockback * scale)

	if duration > 0.0:
		_stagger = maxf(_stagger, duration)
		stagger_started.emit(duration)


## Away from where the blow landed, flattened to the ground plane.
func _push_direction(hit: HitInfo) -> Vector3:
	var here := (motor.get_body().global_position if motor != null else Vector3.ZERO)
	var away := here - hit.origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		return Vector3.FORWARD
	return away.normalized()
