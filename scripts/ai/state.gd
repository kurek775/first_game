## State — base class for one behaviour in a StateMachine.
##
## States are NODES, not enum values. That costs a file per state, and buys:
##   * per-state tuning knobs as @export, visible in the inspector where you
##     are actually looking when you tune them
##   * states reusable across enemy types — stage 6's rider wants Chase and
##     Dead unchanged and only needs a new Flee
##   * no single _physics_process that grows a branch per behaviour
##
## The alternative (an enum plus one big match) is genuinely better when there
## are three states and one enemy forever. This game is not that.
##
## A state never constructs another state or reaches into a sibling. It calls
## machine.transition_to(&"Name") and that is the only coupling.

class_name State
extends Node

## Both injected by StateMachine before the first enter(). States do not walk
## the tree looking for their owner.
var machine: StateMachine
var actor: Enemy


## Called once when this state becomes current.
func enter() -> void:
	pass


## Called once when leaving. Undo anything enter() turned on.
func exit() -> void:
	pass


## Called every physics frame while current.
func tick(_delta: float) -> void:
	pass
