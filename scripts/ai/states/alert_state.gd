## Alert — the beat between spotting you and committing to the chase.
##
## Purely so the player can read the moment they were noticed. Without it the
## enemy snaps from statue to sprint on a single frame and feels like a trap
## rather than a person.
extends State

## Seconds spent turning to face you before the chase begins.
@export_range(0.0, 3.0, 0.05) var reaction_time := 0.5

var _remaining := 0.0


func enter() -> void:
	actor.stop()
	_remaining = reaction_time


func tick(delta: float) -> void:
	actor.face(actor.perception.target_position(), delta)

	_remaining -= delta
	if _remaining <= 0.0:
		machine.transition_to(&"Chase")
