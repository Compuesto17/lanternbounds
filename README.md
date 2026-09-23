# Lanternbound: The Last Light — Godot 4 project

A playable vertical slice built from your design document: Lumi, the lantern
keeper, crosses three chapters of Elaria using light to reveal paths, solve a
mirror puzzle, burn back shadows and recover Memory Fragments.

Everything (art, levels, UI, lights) is generated from code, so the project has
**no binary assets** — you can open it, press Play, and then replace pieces with
your own Aseprite art as it lands.

## Running it

1. Install **Godot 4.3** or newer (standard build, not .NET).
2. Godot → *Import* → pick this folder's `project.godot` → *Import & Edit*.
3. Press **F5**.

Web export works too: *Project → Export → Web*. The renderer is already set to
GL Compatibility, which is what the web target needs.

## Controls

| Action | Keys |
| --- | --- |
| Move | `A` / `D` or arrows |
| Run | `Shift` |
| Jump | `Space` (hold for a higher jump) |
| Climb | `W` / `S` on ladders |
| Toggle lantern | `F` |
| Swap lantern type | `Tab` or `Q` |
| Focused light beam | hold `R` |
| Interact | `E` |
| Pause | `Esc` |

## What is implemented

- **Lantern light system** — a real 2D light that reveals hidden platforms,
  wakes runes and weakens shadow enemies.
- **Lantern energy** — the only resource. It drains while the lantern is lit,
  drains faster while focusing a beam, and refills at checkpoints and from
  lantern oil.
- **Lantern types** — Warm, Spirit (wide reveal) and Fire (fast burn), unlocked
  as chapters begin. They trade radius, drain and burn power.
- **Reflection puzzle** — hold `R` to fire a beam that bounces off mirrors up to
  six times; lighting every rune opens the sealed doors.
- **Memory Fragments** — collectibles tracked per chapter and in total.
- **Checkpoints** — refill health and energy, and write the save file.
- **Shadow enemies** — patrol, chase in darkness, recoil and burn away in light.
- **Hazards** — spikes and fall-outs, with knockback and invulnerability frames.
- **UI** — main menu (Continue / New Game / Settings / Exit), pause menu
  (Resume / Inventory / Options / Main Menu), HUD with hearts, energy bar and
  fragment counter, chapter cards, death and ending screens.
- **Saving** — `user://lanternbound.save` (JSON): chapter, checkpoint, health,
  energy, lanterns, fragments, settings.

## Files

```
project.godot          engine config; registers the Game autoload
scenes/Main.tscn       the only scene — everything else is built in code
scripts/game.gd        autoload singleton: state, lantern data, save/load, input map
scripts/main.gd        screen flow: menus, settings, pause, inventory, endings
scripts/levels.gd      the three levels as ASCII maps  <-- edit levels here
scripts/level.gd       map parser + all world entities (tiles, pickups, mirrors…)
scripts/player.gd      Lumi: movement, climbing, lantern, beam, damage
scripts/enemy.gd       shadow creature
scripts/hud.gd         hearts, energy, fragments, toasts, chapter card
```

## Editing or adding a level

Levels are text. One character per 32×32 tile, in `scripts/levels.gd`:

```
#  solid rock          ~  hidden platform (lantern-only)
H  ladder              ^  spikes
*  memory fragment     o  lantern oil
C  checkpoint          E  shadow enemy
/  mirror              \  mirror (write it as "\\" in GDScript)
R  light rune          D  sealed door
P  player spawn        X  chapter exit
```

Copy one of the dictionaries in `LEVELS`, give it a `name`, `subtitle`,
`ambient` colour and a `map`, and it appears in the chapter order. Rows do not
need to be the same length. Tuning numbers live at the top of `player.gd`
(`JUMP_VELOCITY` gives about 3.5 tiles of height at the current gravity) and
`game.gd` (`LANTERN_DATA`).

## What is deliberately left out

- **Audio.** No sound assets ship with this. Add an `AudioStreamPlayer` per
  event and hook it to the existing signals in `game.gd` (`toast`,
  `health_changed`, `level_completed`) — that is the cleanest seam.
- **Final art.** Sprites are code-drawn polygons standing in for your Aseprite
  work. Each entity builds its own visuals in `_ready()`, so swapping a
  `Polygon2D` for a `Sprite2D` (or an `AnimatedSprite2D`) is a local change.
- **The story beats** past the three sample chapters, and the boss fight implied
  by "understand its true origin".
