## RunSummary — the end-of-raid screen.
##
## Listens to Run.ended and shows what the raid was worth. Its process_mode is
## ALWAYS because ending the run pauses the tree, and a paused screen cannot
## read the key that restarts it.
extends CanvasLayer

const OUTCOME_TITLES := {
	"escaped": "AWAY CLEAN",
	"killed": "CUT DOWN ON THE SAND",
	"caught": "THE LEVY CAUGHT YOU",
}

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body

var _accept_down := false


func _ready() -> void:
	_panel.visible = false
	Run.ended.connect(_on_run_ended)


## Polled rather than handled as an event, matching how Player reads its input.
## It also means a programmatic Input.action_press() reaches this, which an
## _unhandled_input handler never would — the harness drives the game that way.
## Polled rather than event-handled, matching how Player reads its input, and
## with the rising edge tracked by hand.
##
## Input.is_action_just_pressed() is unreliable here: it compares against the
## engine's process-frame counter, and a programmatic Input.action_press() from
## the test harness does not line up with it, so the key reads as held forever
## but never as "just pressed". Watching for the transition ourselves works for
## both a real keyboard and the harness.
func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var down := Input.is_action_pressed("ui_accept")
	if down and not _accept_down:
		_accept_down = true
		_restart()
		return
	_accept_down = down


func _on_run_ended(outcome: String, summary: Dictionary) -> void:
	_title.text = OUTCOME_TITLES.get(outcome, outcome.to_upper())

	var haul: int = summary.get("haul", 0)
	var items: int = summary.get("items", 0)
	var weight: float = summary.get("weight", 0.0)
	var elapsed: float = summary.get("elapsed", 0.0)

	_body.text = "\n".join([
		"haul      %d silver" % haul,
		"carried   %d item%s · %.0f kg" % [items, "" if items == 1 else "s", weight],
		"time      %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60],
		"kills     %d" % summary.get("kills", 0),
		"alarm     %s" % ("raised" if summary.get("alarm_raised", false) else "never rang"),
		"rider     %s" % ("got away, cost you 90s" if summary.get("rider_escaped", false) else "stopped"),
		"",
		"Enter to raid again",
	])

	_panel.visible = true
	# If Enter happened to be down when the run ended, latch it so the summary
	# is not dismissed by the same keypress that caused it.
	_accept_down = Input.is_action_pressed("ui_accept")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Freeze the world behind the summary. Run._process stops too, so the clock
	# does not keep draining while you read your own obituary.
	get_tree().paused = true


func _restart() -> void:
	get_tree().paused = false
	Run.reset()
	# Autoloads survive a scene reload, which is exactly why Run.reset() has to
	# be called explicitly rather than relying on _ready to re-run.
	get_tree().reload_current_scene()
