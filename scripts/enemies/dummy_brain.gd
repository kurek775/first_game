## DummyBrain — deliberately NOT an AI.
##
## It stands still, turns to face the player, and swings on a fixed interval
## when you are close enough. That exists for exactly one reason: blocking and
## hit reactions need something that hits back before they can be tested.
##
## Stage 4 replaces this whole file with a real state machine
## (idle -> alert -> chase -> attack -> dead) and NavigationAgent3D pathing.
## Everything it drives — MeleeAttack, Hitbox, Health, HitReaction — stays.

extends Node

@export var body: Node3D
## The node to rotate so the swing lands where the dummy is looking.
@export var facing: Node3D
@export var attack: MeleeAttack
@export var health: Health
@export var reaction: HitReaction

@export_group("Behaviour")
## Set false in the inspector for a pure punching bag that never fights back.
@export var enabled := true
## Swings only when the player is within this many metres.
@export_range(0.5, 20.0, 0.1) var engage_range := 2.3
## Seconds between swings.
@export_range(0.2, 10.0, 0.1) var interval := 2.5
## Group name of whatever it should attack.
@export var target_group := "player"

var _cooldown := 0.0


func _ready() -> void:
	_cooldown = interval


func _physics_process(delta: float) -> void:
	if health != null and health.is_dead():
		return

	var target := get_tree().get_first_node_in_group(target_group) as Node3D
	if target == null:
		return

	var to_target := target.global_position - body.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.0001 and facing != null:
		# Snap to face — no smoothing, so the frontal-block test has a stable
		# answer rather than one that depends on turn speed.
		facing.rotation.y = atan2(-to_target.x, -to_target.z)

	if not enabled:
		return
	if reaction != null and reaction.is_staggered():
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return

	if to_target.length() <= engage_range and attack != null and attack.can_swing():
		attack.try_swing()
		_cooldown = interval
