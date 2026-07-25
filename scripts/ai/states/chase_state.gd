## Chase — path to the target until close enough to swing.
##
## Keeps chasing for `give_up_time` after losing sight, so breaking line of
## sight for half a second does not reset the fight.
extends State

## Distance at which to stop closing and start swinging. Must be no greater
## than the hitbox's actual reach or the enemy swings at air forever.
@export_range(0.5, 10.0, 0.1) var attack_range := 1.9
## Seconds of no line of sight before giving up and going back to Idle.
@export_range(0.0, 30.0, 0.5) var give_up_time := 6.0

var _unseen := 0.0


func enter() -> void:
	_unseen = 0.0


func tick(delta: float) -> void:
	# A staggered enemy is not steering anywhere; let knockback carry it.
	if actor.reaction.is_staggered():
		actor.stop()
		return

	var target := actor.perception.target
	if target == null:
		machine.transition_to(&"Idle")
		return

	if actor.perception.can_see():
		_unseen = 0.0
	else:
		_unseen += delta
		if _unseen >= give_up_time:
			machine.transition_to(&"Idle")
			return

	var target_point := target.global_position
	actor.move_toward_point(target_point)
	actor.face(target_point, delta)

	if actor.global_position.distance_to(target_point) <= attack_range:
		machine.transition_to(&"Attack")
