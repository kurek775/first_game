I'm building a small 3D game in Godot 4.4 and I want you to help me build it
incrementally. Read this whole brief before writing any code.

## Context about me
Senior developer — strong TypeScript/Angular/React and Python/FastAPI. I know
software architecture well. I have never used Godot or built a game before.
So: don't explain what a class or a signal-as-observer is, but DO explain Godot-
specific concepts (node tree, scenes vs instances, _process vs _physics_process,
CharacterBody3D, collision layers/masks, export vars) the first time they appear.

## The game
"Lindisfarne" — a single-map Viking raid. One 8-minute run:
land on the beach, raid an undefended monastery, grab loot, get back to the
longship before the local levy musters and kills you.

Core tension: the longer you stay, the more defenders arrive. Loot is physical
and heavy — carrying more slows you down. Greed vs. survival on a timer.

Explicitly OUT of scope: character creation, skill trees, dialogue, quests,
inventory UI, save/load, multiple maps, naval gameplay, crew management.
If I later ask for any of these, push back before implementing.

## Constraints
- Godot 4.4, GDScript (not C#).
- Greybox only: BoxMesh, CapsuleMesh, CylinderMesh, flat colors via
  StandardMaterial3D. No imported models, textures, or audio.
- Write .tscn and .tres files directly as text — I'll open them in the editor
  to verify. Tell me exactly what to check in the editor after each stage.
- Keep scripts small and single-purpose. Prefer composition (child nodes with
  their own scripts) over god-scripts on the player.
- Use signals for cross-system communication rather than direct node references
  up the tree. Show me the idiomatic Godot pattern for this.
- Every script gets a short header comment explaining its responsibility.

## Build stages
Do ONE stage, then stop and wait for me to test it and confirm before moving on.
Do not skip ahead.

1. Project skeleton + third-person player controller on a flat plane.
   CharacterBody3D, WASD movement relative to camera, sprint, gravity,
   SpringArm3D camera with mouse look. Getting this to feel good is the
   priority — expose speed/accel/friction/camera values as @export vars.
2. Greybox monastery: church nave, a side building, a low wall, a crypt
   reachable by stairs. Beach on one edge with the longship as the extraction
   point. Static geometry, correct collision.
3. Combat: melee swing with hitbox, blocking, health, hit reactions and
   knockback. Test against a static dummy first.
4. One enemy: NavigationAgent3D pathing, states (idle → alert → chase →
   attack → dead). Use a simple state machine — show me how you'd structure it.
5. Loot: pickups with a weight value. Carrying reduces move speed and blocks
   two-handed attacks. Physical, visible on the player if cheap to do.
6. The muster: alarm bell trigger, escalating spawn waves over time, a rider
   who leaves the map and shortens the timer if he escapes.
7. Extraction + run summary: reach the longship alive, show haul, time, kills.
8. Juice pass: camera shake, hit-stop, particles, tighter feedback.

## How to work
- Before each stage, tell me what you're going to build and why, in a few lines.
- After each stage, tell me precisely what to do in the Godot editor to test it,
  and what "correct" looks like.
- If a Godot API you want to use might have changed between versions, say so
  rather than guessing — I'd rather check the docs than debug a hallucinated
  method.

Start with stage 1.