## StateMachine — runs whichever child State is current.
##
## Deliberately tiny. It owns no behaviour, no conditions and no knowledge of
## what any state does; all it can do is tick the current one and swap on
## request. Every transition rule lives in the state that wants to leave, which
## is the only way to read "when does this enemy give up chasing?" without
## reading the whole file.
##
## States are addressed by node name, so the tree in the editor IS the list of
## states, and renaming one in the dock is a real refactor you will notice.

class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

## The thing these states drive. Injected into every child State.
@export var actor: Enemy
## Which child to start in. Defaults to the first child if unset.
@export var initial_state: State

var current: State

var _states: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		var state := child as State
		if state == null:
			push_warning("StateMachine: child '%s' is not a State, ignoring." % child.name)
			continue
		state.machine = self
		state.actor = actor
		_states[child.name] = state

	if _states.is_empty():
		push_error("StateMachine: no State children.")

	# Do NOT enter the initial state here. Godot propagates _ready CHILDREN
	# FIRST, so at this point the actor's own _ready has not run and every one
	# of its @onready component references is still null. The owner calls
	# start() from its _ready, by which time they exist.
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if current != null:
		current.tick(delta)


## Called by the owner from ITS _ready, once its components exist.
func start() -> void:
	if current != null or _states.is_empty():
		return
	current = initial_state if initial_state != null else _states.values()[0]
	current.enter()
	set_physics_process(true)
	state_changed.emit(&"", current.name)


func state_name() -> StringName:
	return current.name if current != null else &""


func transition_to(next_name: StringName) -> void:
	if current != null and current.name == next_name:
		return

	var next: State = _states.get(next_name)
	if next == null:
		push_error("StateMachine: no state named '%s'. Have: %s" % [next_name, _states.keys()])
		return

	var from: StringName = current.name if current != null else &""
	if current != null:
		current.exit()
	current = next
	current.enter()
	state_changed.emit(from, next_name)
