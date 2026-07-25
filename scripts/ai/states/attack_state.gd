## Attack — stand and swing while the target stays in reach.
##
## Leaving is deliberately hysteretic: `break_off_range` is larger than Chase's
## attack_range, so a target hovering at exactly the boundary does not flicker
## between chasing and attacking every frame.
extends State

## Beyond this, go back to chasing. Keep it above Chase.attack_range.
@export_range(0.5, 12.0, 0.1) var break_off_range := 2.3
## Seconds between swings.
@export_range(0.0, 5.0, 0.05) var cooldown := 0.9

var _remaining := 0.0


func enter() -> void:
	actor.stop()
	# Swing immediately on arrival; the approach was the wind-up.
	_remaining = 0.0


func exit() -> void:
	if actor.attack.is_swinging():
		actor.attack.cancel()


func tick(delta: float) -> void:
	if actor.reaction.is_staggered():
		actor.attack.cancel()
		return

	var target := actor.perception.target
	if target == null:
		machine.transition_to(&"Idle")
		return

	actor.stop()
	actor.face(target.global_position, delta)

	# Never interrupt our own swing.
	if actor.attack.is_swinging():
		return

	if actor.global_position.distance_to(target.global_position) > break_off_range:
		machine.transition_to(&"Chase")
		return

	_remaining -= delta
	if _remaining <= 0.0 and actor.attack.try_swing():
		_remaining = cooldown
