## Run — the state of one raid, autoloaded as `Run`.
##
## Owns the clock, the tally, and nothing else. It does not know what a
## longship is; stage 7's extraction volume calls finish() on it.
extends Node

signal time_changed(remaining: float)
signal ended(outcome: String, summary: Dictionary)

const RUN_SECONDS := 480.0
## Seconds torn off the clock when the rider gets away.
const RIDER_PENALTY := 90.0

var time_remaining := RUN_SECONDS
var kills := 0
var alarm_raised := false
var rider_escaped := false
var finished := false
var outcome := ""


func _ready() -> void:
	Events.enemy_killed.connect(func(_e: Node3D) -> void: kills += 1)
	Events.alarm_raised.connect(func(_w: Vector3) -> void: alarm_raised = true)
	Events.rider_escaped.connect(_on_rider_escaped)
	Events.player_died.connect(func() -> void: finish("killed"))


func _process(delta: float) -> void:
	if finished:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	time_changed.emit(time_remaining)
	if is_zero_approx(time_remaining):
		finish("caught")


func elapsed() -> float:
	return RUN_SECONDS - time_remaining


func finish(reason: String, extra: Dictionary = {}) -> void:
	if finished:
		return
	finished = true
	outcome = reason
	var summary := {
		"outcome": reason,
		"kills": kills,
		"elapsed": elapsed(),
		"time_left": time_remaining,
		"alarm_raised": alarm_raised,
		"rider_escaped": rider_escaped,
	}
	summary.merge(extra, true)
	ended.emit(reason, summary)


## Restart without reloading the scene. Used by the run-summary screen.
func reset() -> void:
	time_remaining = RUN_SECONDS
	kills = 0
	alarm_raised = false
	rider_escaped = false
	finished = false
	outcome = ""


func _on_rider_escaped() -> void:
	rider_escaped = true
	time_remaining = maxf(0.0, time_remaining - RIDER_PENALTY)
	time_changed.emit(time_remaining)
