## Enemy — the facade its states drive.
##
## Same shape as Player: it holds the components and exposes a few verbs, and
## contains no behaviour of its own. Everything about WHEN to walk or swing
## lives in the State nodes under $StateMachine.
##
## The verbs exist so states never touch NavigationAgent3D or CharacterMotor
## directly — swapping pathing implementations should not mean editing five
## state files.

class_name Enemy
extends CharacterBody3D

@export_range(1.0, 40.0, 0.5) var turn_speed := 8.0

@onready var motor: CharacterMotor = $Motor
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack: MeleeAttack = $MeleeAttack
@onready var reaction: HitReaction = $HitReaction
@onready var perception: Perception = $Perception
@onready var machine: StateMachine = $StateMachine
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual


func _ready() -> void:
	# Death is not a transition any state asks for; it happens TO the enemy.
	health.died.connect(func() -> void: machine.transition_to(&"Dead"))

	# Start the machine only now: _ready runs children-first, so StateMachine's
	# own _ready fired before the @onready vars above were assigned.
	machine.start()


## Walk toward a world point along the navigation mesh.
func move_toward_point(point: Vector3) -> void:
	agent.target_position = point

	if agent.is_navigation_finished():
		stop()
		return

	var step := agent.get_next_path_position() - global_position
	step.y = 0.0
	motor.wish_direction = step.normalized() if step.length_squared() > 0.0001 else Vector3.ZERO


func stop() -> void:
	motor.wish_direction = Vector3.ZERO


## Turn the mesh toward a world point. Cosmetic, except that Hitbox hangs off
## Visual, so this is also what aims the swing.
func face(point: Vector3, delta: float) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length_squared() < 0.0001:
		return
	# global_rotation, not rotation: target_yaw is a WORLD angle, so writing it
	# into a local one is only correct while the body itself is unrotated.
	# Placing a rotated enemy in a level would otherwise aim every swing wrong.
	var target_yaw := atan2(-to_point.x, -to_point.z)
	visual.global_rotation.y = lerp_angle(
		visual.global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta)
	)
