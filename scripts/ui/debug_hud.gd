## DebugHud — throwaway readout for tuning. Delete it once combat feels right,
## or keep it behind a toggle.
##
## Demonstrates the two ways this project talks between systems:
##   * Discrete events (started sprinting, landed, took a hit) arrive as SIGNALS.
##   * Continuous values (current speed, current health) are POLLED each frame —
##     sending a signal 60x/second to say "speed is 4.51" would be silly.
##
## The player reference is an @export node link, set in the editor. That is fine
## and idiomatic; what we avoid is code like get_parent().get_parent().player,
## which silently breaks the moment the scene tree is rearranged.

extends CanvasLayer

@export var player: Player

@onready var _label: Label = $Panel/Label

var _director: MusterDirector

var _last_event := "-"


func _ready() -> void:
	if player == null:
		_label.text = "DebugHud: no player assigned"
		set_process(false)
		return

	_director = get_tree().current_scene.find_child("MusterDirector", true, false) as MusterDirector

	Events.alarm_raised.connect(func(_w: Vector3) -> void: _last_event = "ALARM RAISED")
	Events.wave_spawned.connect(func(i: int, n: int) -> void: _last_event = "wave %d: %d levy" % [i, n])
	Events.rider_escaped.connect(func() -> void: _last_event = "rider escaped! -90s")
	Events.enemy_killed.connect(func(e: Node3D) -> void: _last_event = "killed %s" % e.name)

	player.sprint_changed.connect(_on_sprint_changed)
	player.landed.connect(_on_landed)
	player.died.connect(func() -> void: _last_event = "DIED")

	player.health.damaged.connect(_on_damaged)
	player.blocker.blocked.connect(func(_hit: HitInfo) -> void: _last_event = "blocked!")
	player.attack.swing_landed.connect(_on_swing_landed)
	player.carrier.picked_up.connect(
		func(item: LootItem) -> void: _last_event = "took %s (%.0fkg)" % [item.item_name, item.weight]
	)
	player.carrier.dropped.connect(
		func(item: LootItem) -> void: _last_event = "dropped %s" % item.item_name
	)
	player.reaction.stagger_started.connect(
		func(duration: float) -> void: _last_event = "staggered %.2fs" % duration
	)


func _process(_delta: float) -> void:
	_label.text = "\n".join([
		"hp        %3d / %-3d" % [roundi(player.health.current), roundi(player.health.max_health)],
		"speed     %5.2f m/s" % player.motor.get_ground_speed(),
		"attack    %s" % _phase_name(),
		"guard     %s" % ("UP" if player.blocker.is_blocking() else "down"),
		"load      %.0f kg · %d silver%s" % [
			player.carrier.total_weight(),
			player.carrier.total_value(),
			"" if player.carrier.has_free_hands() else "  HANDS FULL",
		],
		"state     %s" % _state_name(),
		"clock     %s%s" % [_clock(), "  ALARM" if Run.alarm_raised else ""],
		"muster    wave %d · %d kills%s" % [
			_director.wave if _director != null else 0,
			Run.kills,
			"  RIDER AWAY" if Run.rider_escaped else "",
		],
		"last      %s" % _last_event,
		"",
		"WASD · Shift sprint · LMB attack · RMB block",
		"E take · G drop · Esc mouse",
	])


func _clock() -> String:
	var t := Run.time_remaining
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func _phase_name() -> String:
	match player.attack.phase:
		MeleeAttack.Phase.WINDUP: return "windup"
		MeleeAttack.Phase.ACTIVE: return "ACTIVE"
		MeleeAttack.Phase.RECOVERY: return "recovery"
		_: return "ready"


func _state_name() -> String:
	if player.health.is_dead():
		return "dead"
	if player.reaction.is_staggered():
		return "staggered"
	if not player.is_on_floor():
		return "airborne"
	return "ok"


func _on_damaged(amount: float, remaining: float) -> void:
	_last_event = "took %.0f (%.0f left)" % [amount, remaining]


func _on_swing_landed(hurtbox: Hurtbox) -> void:
	var who: String = str(hurtbox.body.name) if hurtbox.body != null else "?"
	_last_event = "hit %s" % who


func _on_sprint_changed(sprinting: bool) -> void:
	_last_event = "sprint on" if sprinting else "sprint off"


func _on_landed(impact_speed: float) -> void:
	_last_event = "landed @ %.1f m/s" % impact_speed
