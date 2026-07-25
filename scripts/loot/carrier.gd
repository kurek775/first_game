## Carrier — what a character is hauling, and what it costs them.
##
## Owns the whole greed-versus-survival lever: total weight scales movement
## speed down and, past a threshold, means both hands are full and you cannot
## swing at all. Dropping the reliquary to fight is meant to be a real decision.
##
## Knows nothing about input. The Player reads the keys and calls
## try_pick_up() / drop_last().

class_name Carrier
extends Node

signal load_changed(weight: float, value: int)
signal picked_up(item: LootItem)
signal dropped(item: LootItem)
## Emitted when crossing the two-hand threshold in either direction, so the HUD
## can say "hands full" without polling for a change.
signal hands_changed(free: bool)

## The character doing the carrying.
@export var body: Node3D
## Area3D that detects loot within arm's length. Masks layer 5, "interactable".
@export var reach: Area3D
## Where carried loot is parented. Put it on the character's back.
@export var stack_anchor: Node3D
## Where dropped loot is reparented to. Leave null to use the scene root.
@export var world_parent: Node

@export_group("Load")
## Weight at which you would barely move. Speed scales toward min_speed_scale
## as the load approaches this.
@export_range(10.0, 500.0, 5.0) var crush_weight := 130.0
@export_range(0.05, 1.0, 0.05) var min_speed_scale := 0.35
## Above this you are holding loot in both arms and cannot attack.
@export_range(0.0, 200.0, 0.5) var two_hand_weight_limit := 12.0

var carried: Array[LootItem] = []

var _hands_free := true


func total_weight() -> float:
	var sum := 0.0
	for item in carried:
		sum += item.weight
	return sum


func total_value() -> int:
	var sum := 0
	for item in carried:
		sum += item.value
	return sum


## Multiplier for CharacterMotor.speed_scale. Linear in weight, floored so a
## fully laden raider still shuffles rather than freezing.
func speed_scale() -> float:
	return clampf(1.0 - total_weight() / crush_weight, min_speed_scale, 1.0)


## False once your arms are full. The player's swing is two-handed.
func has_free_hands() -> bool:
	return total_weight() <= two_hand_weight_limit


## Nearest un-carried loot inside the reach volume.
func nearest_in_reach() -> LootItem:
	if reach == null:
		return null

	var best: LootItem = null
	var best_distance := INF
	for area in reach.get_overlapping_areas():
		var item := area as LootItem
		if item == null or item.is_carried():
			continue
		var distance := body.global_position.distance_to(item.global_position)
		if distance < best_distance:
			best_distance = distance
			best = item
	return best


func try_pick_up() -> bool:
	var item := nearest_in_reach()
	if item == null:
		return false

	item.attach_to(body, stack_anchor, carried.size())
	carried.append(item)
	picked_up.emit(item)
	_announce()
	return true


func drop_last() -> bool:
	if carried.is_empty():
		return false

	var item: LootItem = carried.pop_back()
	item.detach_to(_drop_parent(), _drop_position())
	dropped.emit(item)
	_announce()
	return true


func drop_all() -> void:
	while not carried.is_empty():
		drop_last()


func _drop_parent() -> Node:
	return world_parent if world_parent != null else body.get_tree().current_scene


## Just in front of the feet, so dropped loot does not land inside the body and
## immediately re-enter the reach volume from the inside.
func _drop_position() -> Vector3:
	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	return body.global_position + forward.normalized() * 1.1 + Vector3.UP * 0.3


func _announce() -> void:
	load_changed.emit(total_weight(), total_value())

	var free := has_free_hands()
	if free != _hands_free:
		_hands_free = free
		hands_changed.emit(free)
