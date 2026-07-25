## LootItem — a physical thing worth stealing.
##
## Not an inventory entry. The node itself is reparented onto the carrier when
## picked up and put back in the world when dropped, so what you are carrying
## is literally visible on your back and can be abandoned where you stand.
##
## Sits on collision layer 5 ("interactable") and masks nothing — loot never
## looks for anything, the carrier's reach volume looks for loot.

class_name LootItem
extends Area3D

signal picked_up(by: Node3D)
signal dropped

@export var item_name := "Loot"
## Kilograms. This is the whole design lever: heavier is worth more and costs
## you speed and the ability to swing.
@export_range(0.5, 200.0, 0.5) var weight := 10.0
## Silver. Shown in the run summary.
@export_range(0, 5000, 5) var value := 50

var carried_by: Node3D = null

var _home_parent: Node = null


func is_carried() -> bool:
	return carried_by != null


## Called by Carrier. Reparents onto `anchor` and stops being pickable.
func attach_to(carrier_body: Node3D, anchor: Node3D, slot: int) -> void:
	if is_carried():
		return
	_home_parent = get_parent()
	carried_by = carrier_body

	# Stop the reach volume seeing loot that is already on our back.
	monitorable = false

	reparent(anchor, false)
	position = Vector3(0.0, 0.28 * slot, 0.0)
	rotation = Vector3.ZERO

	picked_up.emit(carrier_body)


## Called by Carrier. Puts the node back in the world at `where`.
func detach_to(world_parent: Node, where: Vector3) -> void:
	if not is_carried():
		return
	carried_by = null

	var parent := world_parent if world_parent != null else _home_parent
	reparent(parent, false)
	global_position = where
	rotation = Vector3.ZERO

	monitorable = true
	dropped.emit()
