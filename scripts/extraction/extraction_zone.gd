## ExtractionZone — the longship's deck. Stepping onto it alive ends the run.
##
## Reads the haul off whatever walked in rather than tracking loot itself: the
## Carrier already knows what is on the player's back, and duplicating that here
## would mean two places to get it wrong.
class_name ExtractionZone
extends Area3D

signal extracted(summary: Dictionary)

## Refuse to leave empty-handed. Off by default — running for the boat with
## nothing is a legitimate, cowardly choice.
@export var require_loot := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if Run.finished or not body.is_in_group("player"):
		return

	var health := body.get_node_or_null("Health") as Health
	if health != null and health.is_dead():
		return

	var carrier := body.get_node_or_null("Carrier") as Carrier
	var haul := carrier.total_value() if carrier != null else 0
	if require_loot and haul <= 0:
		return

	var summary := {
		"haul": haul,
		"weight": carrier.total_weight() if carrier != null else 0.0,
		"items": carrier.carried.size() if carrier != null else 0,
	}
	extracted.emit(summary)
	Run.finish("escaped", summary)
