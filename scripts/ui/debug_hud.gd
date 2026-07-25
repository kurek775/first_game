## DebugHud — throwaway readout for tuning stage 1. Delete it once movement
## feels right, or keep it behind a toggle.
##
## Demonstrates the two ways this project talks between systems:
##   * Discrete events (started sprinting, landed) arrive as SIGNALS.
##   * Continuous values (current speed) are POLLED each frame — sending a
##     signal 60x/second to say "speed is 4.51" would be silly.
##
## The player reference is an @export node link, set in the editor. That is fine
## and idiomatic; what we avoid is code like get_parent().get_parent().player,
## which silently breaks the moment the scene tree is rearranged.

extends CanvasLayer

@export var player: Player

@onready var _label: Label = $Panel/Label

var _last_event := "-"


func _ready() -> void:
	if player == null:
		_label.text = "DebugHud: no player assigned"
		set_process(false)
		return

	player.sprint_changed.connect(_on_sprint_changed)
	player.landed.connect(_on_landed)


func _process(_delta: float) -> void:
	var speed := player.motor.get_ground_speed()
	_label.text = "\n".join([
		"speed     %5.2f m/s" % speed,
		"sprinting %s" % ("yes" if player.motor.is_sprinting() else "no"),
		"grounded  %s" % ("yes" if player.is_on_floor() else "no"),
		"last      %s" % _last_event,
		"",
		"WASD move · Shift sprint · Esc release mouse",
	])


func _on_sprint_changed(sprinting: bool) -> void:
	_last_event = "sprint on" if sprinting else "sprint off"


func _on_landed(impact_speed: float) -> void:
	_last_event = "landed @ %.1f m/s" % impact_speed
