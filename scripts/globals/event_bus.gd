## Events — the one global signal bus, autoloaded as `Events`.
##
## Everything so far has used direct @export node links, which is right for
## things that live in the same scene. The muster is the first system where the
## sender genuinely cannot know the receiver: a spearman's eyes do not know a
## bell exists, the bell does not know a spawn director exists, and the HUD
## wants all of it. That is what a bus is for.
##
## Keep it to facts about the world. Nothing here should carry a command
## ("spawn a wave"); it carries what happened ("the alarm was raised") and lets
## each listener decide what that means for it.
extends Node

## Someone saw the player. Emitted by every Perception node.
signal player_spotted(who: Node3D)
## The bell went. Only ever fires once per run.
signal alarm_raised(where: Vector3)
## A muster wave landed.
signal wave_spawned(index: int, count: int)
## The rider got off the island. The levy now knows exactly where you are.
signal rider_escaped
signal enemy_killed(enemy: Node3D)
