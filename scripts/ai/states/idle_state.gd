## Idle — stand still until the target is seen.
##
## Deliberately has no patrol behaviour. A monk's guard who wanders is a
## different enemy; add it as a sibling state rather than a flag in here.
extends State


func enter() -> void:
	actor.stop()


func tick(_delta: float) -> void:
	if actor.perception.can_see():
		machine.transition_to(&"Alert")
