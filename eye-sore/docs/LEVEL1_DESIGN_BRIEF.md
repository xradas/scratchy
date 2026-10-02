# Eye Sore: First Descent — level design brief

**Status:** Proposed design for review; not implemented.  
**Scope:** One compact first level for the native SDL/OpenGL prototype.  
**Art and content rule:** Original Eye Sore rooms, names, silhouettes, sounds, and geometry. The classic FPS influence is pacing and spatial grammar, not a traced Doom map or copied assets.

## What exists today

The native prototype currently has a 72 × 60 unit rectangular play space, interior wall segments with gaps, pillars, and a player start at `(0, 24)` facing toward decreasing Z. Its current first descent is three staged fights: three enemies, then four, then seven; clearing each group reveals a weapon cache. Existing enemy types have four entries in `ENEMY_DEFS`, but no authored names or separate per-type movement/attack tuning in the code. Enemy HP in the current wave list ranges from 4 to 14. Shotgun and arc cannon are unlocked and auto-equipped at their caches.

In the current branch, the shotgun and arc cannon are locked until their caches are collected, and each pickup auto-equips its weapon. The layout has no door state, key, persistent ammo inventory, secret trigger, or exit. Divider gaps are always passable. The map below is a proposed replacement direction, not a description of current game behavior. It is drawn as named spaces and links so it can be translated onto the existing footprint; it does not dictate exact room dimensions.

## Top-down concept map

**Orientation:** North is toward decreasing Z; the player begins at the south. `==>` is the intended first-time view direction. A sightline exists only where explicitly shown; solid walls block it. The map is schematic, not to scale.

```text
                                  NORTH (−Z)
      ┌──────────────────────┐       ┌────────────────────────┐
      │ H  REACTOR / EXIT    │<--G3--│ G  PUMP HALL / SHOTGUN  │
      │ E5: final encounter  │       │ E3: ambush from alcove │
      │ [EXIT LIFT, inactive]│       │ [shotgun]     ┌───────┤
      └──────────┬───────────┘       └──────┬────────┤ SECRET│
                 │ G2: keyed gate            │        │ E4?   │
                 │                            │        └───┬───┘
      ┌──────────┴───────────┐       ┌────────┴────────┐  │
      │ F  EAST SERVICE LOOP │<----->│ E  CENTRAL HUB   │  │
      │ [KEY] on return spur │       │ first view ==>   │  │
      │ E2: 2 melee + caster │       │     ammo/health  │  │
      └──────────┬───────────┘       └────────┬────────┘  │
                 └────G1: opens after E1──────┘           │
                                                         └─┘
      ┌──────────────────────┐       ┌────────────────────────┐
      │ B  ENTRY AIRLOCK     │==G0==>│ C  INTAKE CHAMBER      │
      │ player start (0,24)  │       │ E1: caster + 2 melee   │
      │ quiet / safe          │       │ [small ammo/health]    │
      └──────────────────────┘       └────────────────────────┘
                                  SOUTH (+Z)
```

### Gate and sightline states

| Link | Initial state | Opens when | First-time view and purpose |
|---|---|---|---|
| G0: airlock → intake | Open | Always | From the safe start, see the chamber floor and one distant caster silhouette through a grated screen. The screen is an original set piece; it hides the two melee enemies in side recesses. |
| G1: intake → hub/service loop | Closed, visible | E1 is defeated | The player sees a lit hub landmark beyond the gate while fighting. Opening it makes the reward and next route obvious. |
| Hub ↔ east service loop | Open | Always after G1 | From the hub, see the first part of the loop, not the key. The bend conceals the second encounter and makes the player turn corners deliberately. |
| G2: hub → pump hall | Closed, keyed | Player carries the valve key from F | From the hub, the shotgun cache glow is visible through a barred opening. This previews the reward without revealing the pump-hall ambush positions. |
| Pump hall → secret alcove | Concealed, closed | Optional switch in pump hall | A different wall panel/lighting cue hints at the switch. The alcove contains a useful but optional reward; it must not gate level completion. |
| G3: pump hall → reactor | Closed | E3 is defeated and key is used | The reactor's large light source and exit lift are visible from the pump hall, but cover breaks a direct firing lane. The lift remains inactive until E5 is defeated. |

For an engine pass that cannot yet draw/open doors, use the same division lines as solid static walls and stage each encounter at a doorway trigger. Implement visible open/closed gates in a follow-up; do not pretend a static gap is locked. A temporary barrier can be represented by collision plus a simple colored panel only after collision and rendering share the same gate state.

## Encounter and reward plan

Numbers below are **proposed starting values** for playtesting, not existing values or final balance. The four existing engine slots can be mapped to original Eye Sore archetypes. Type mapping must be confirmed against their actual art before implementation. Existing global enemy speed is about `0.58` units/s and should remain until focused testing suggests a change.

| Encounter | Trigger / placement | Enemies and proposed HP | Intended lesson / pressure | Reward |
|---|---|---|---|---|
| E1 — Intake | Enter chamber; initially visible ember-caster at far end, two melee enemies wake when player passes midline | 1 **Cinderling** (existing ranged slot 1), 4 HP; 2 **Scrap Hounds** (melee slot 0), 4 HP each | Establish sightline, projectile dodge, then movement under light pressure. Keep the first view legible; avoid starting all three attacks at once. | Small health pack (+20, cap 100) and pistol cells (e.g. +24); G1 opens. |
| E2 — Service loop | Cross the loop threshold; enemies take positions on opposite sides of cover | 2 Scrap Hounds, 6 HP each; 1 **Kiln Adept** (ranged slot 2), 7 HP | Introduce crossfire and flanking. The walls and a central machine should create safe movement choices rather than a long open firing lane. | Valve key at the far spur; a small shell pickup on the return path. Opens G2. |
| E3 — Pump hall | Enter after using G2; one visible guard, two enemies held behind side alcoves | 2 Kiln Adepts, 8 HP each; 2 Scrap Hounds, 7 HP each | First sustained fight, but with a clear retreat route to the hub. The first enemy gives the player time to understand the room before the ambush joins. | Original pump-action shotgun; modest shell pack (+16). Weapon is shown before E3, picked up afterward. |
| E4 — Secret alcove (optional) | Activate hinted panel; short one-room detour | 1 **Furnace Brute** (heavy slot 3), 10 HP | Optional risk for a clear payoff, with enough room to circle and break line of sight. If this enemy cannot be made distinct yet, substitute two Scrap Hounds rather than adding a fifth enemy type. | Health (+25) and shells (+8), or a level-specific score bonus; never a required key. |
| E5 — Reactor | Cross G3 threshold; boss-like pressure begins after a short reveal beat | 1 Furnace Brute, 14 HP; 2 Kiln Adepts, 9 HP each; 2 Scrap Hounds, 8 HP each | Use the widest room and multiple cover routes. Ranged units anchor different lanes; melee enemies force movement. Stage the group in two beats so the player can react to the room reveal. | Health (+25) and ammo cache; exit lift activates with a conspicuous light and original sound cue. |

**Weapon inventory:** begin with the ember pistol. Shotgun is the only new weapon needed to complete this first level. Treat the arc cannon as a later-level reward: placing both current weapon caches in this one compact route overloads the opening and removes room for ammo economy. If the engine currently has no ammunition system, the brief can first ship with pickups as health and weapon unlocks only; do not put ammo pickups in the HUD until they are tracked.

## Pacing targets

1. **Orient (10–20 seconds):** safe airlock, readable landmark, first enemy preview; no damage pressure.
2. **Teach (30–60 seconds):** one ranged enemy, then two melee enemies; encounter ends with a visible route opening and a small sustain reward.
3. **Explore (20–40 seconds):** hub and short loop; key is found by following a readable landmark, not a hidden pixel hunt. Secret is optional.
4. **Escalate (45–75 seconds):** pump hall uses cover and one delayed flank; shotgun pickup rewards the player after the fight.
5. **Resolve (45–75 seconds):** reactor expands the combat space, mixes established roles, and ends with a clear exit activation.

The intended rhythm is short combat, a safe breath to look and collect, then a new spatial problem. Difficulty increases through enemy combination, approach angles, and room shape before it increases through raw health. Keep retreat paths open, telegraph ranged attacks, and avoid simultaneous unavoidable fire from several enemies.

## Feasible implementation slices

**Slice 1 — authored flow using current primitives:** preserve current renderer and enemy art; separate the spaces into a small set of wall rectangles, relocate the player start and staged spawns, and implement E1→G1→E2→key→G2→E3→exit as trigger-driven state. Reuse existing four enemy slots and weapon models. Health pickups can be simple original billboard objects. The optional secret and E4 can follow after route readability is established.

**Slice 2 — real gates and rewards:** define a small `LevelDefinition` for walls, gates, encounters, pickups, and exit. Each gate needs one shared open/closed state used by rendering, player collision, enemy movement/LOS, and projectile collision. Add key state and visible HUD indicator; add health/ammo counts only when those systems exist. Keep the level geometry in one source of truth so shots cannot pass through walls that block movement.

**Slice 3 — authored polish:** original signage, animated gate/exit, unique ambient beds and one-shot cues for gate unlock/key pickup/secret discovery, then playtest from a clean restart. Tune HP and counts from observed time-to-kill and damage taken rather than making later enemies only damage sponges.

## Classic FPS layout grammar used here

This concept uses recognizable genre techniques: a safe start, a visible but temporarily inaccessible reward, short connected spaces, a key that sends the player through a compact return loop, an optional secret, readable landmark lighting, staged enemy reveals, and an exit that changes state after the final encounter. Room silhouettes, connections, encounter placement, names, textures, sprites, weapon art, and audio must be authored for Eye Sore. No Doom map, WAD data, source level geometry, or commercial Doom asset is a reference input.
