# Layout reference review — 17 October 2026

Coordinator research and design decisions for the construction specialist. Scope requested by the user: the links in the DoomWiki FAQ **Contents** section and the supplied layout article. Site navigation, unrelated tutorials, linked example maps and further reference chains are outside this review.

## Sources and access

- [Doom Level Design FAQ index](https://doomwiki.org/wiki/Doom_Level_Design_FAQ): read. Its contents point to the ten destinations below; “Levels and Maps” and “Other Errors” are plain text headings.
- [Tom Neff, DESIGN12.FAQ](https://www.gamers.org/dhs/helpdocs/pwadmake.html), version 1.2a (1994; contact update 1997): read the relevant categories and common-error appendix as the accessible primary fallback for blocked topic pages.
- [Woolie's Blognostications, The secret to a good Doom level—it’s the layout, stupid!](https://tankermottind.tumblr.com/post/123754770395/the-secret-to-a-good-doom-level-its-the-layout), 10 July 2015: read the article, excluding comments/reblogs.

| Contents label | Actual destination | Access result | Eyesore design decision |
|---|---|---|---|
| Editors | [Editors](https://doomwiki.org/wiki/Editors) | Unavailable/cache miss | Keep the pinned Godot authoring pipeline; separate editable plans from generated scenes and exports. |
| Walls | [Linedef](https://doomwiki.org/wiki/Linedef) | HTTP 403; FAQ fallback | Every opening needs an explicit movement/visibility/shot contract and physical boundary. |
| Sectors / Rooms / Floors / Ceilings / Stairs | [Sector](https://doomwiki.org/wiki/Sector) | HTTP 403; FAQ fallback | Audit actual controller ascent, descent and headroom at transitions, including moving states. |
| Doors | [Door](https://doomwiki.org/wiki/Door) | HTTP 403; FAQ fallback | Recess and frame doors; test closed/open collision, exposed faces and reachable controls. |
| Tags | [Tag](https://doomwiki.org/wiki/Tag) | Read | Keep stable authored IDs and explicit control-to-target ownership; never infer targets from list order. |
| Triggers / Effects | [Linedef type](https://doomwiki.org/wiki/Linedef_type) | HTTP 403; FAQ fallback | Validate prerequisites, single-use/repeat behavior and visible results per mechanism. |
| Monsters | [Monster](https://doomwiki.org/wiki/Monster) | HTTP 403; FAQ fallback | Check actual enemy footprints, separation, entrances and usable attack angles. |
| Things | [Thing types](https://doomwiki.org/wiki/Thing_types) | HTTP 403; FAQ fallback | Place supplies by purpose and accessible reach; reserve interaction and movement space. |
| Graphics | [Graphics](https://doomwiki.org/wiki/Graphics) | Read; disambiguation page | Keep surface textures, creature sprites and HUD assets as separate production responsibilities. |
| Sounds | [Sound](https://doomwiki.org/wiki/Sound) | HTTP 403; FAQ fallback | Keep audio emitter behavior separate from enemy activation rules; no new sound changes in this pass. |

Access errors are not completed page reads. The fallback covers the associated FAQ topics, not the unseen contents of those wiki articles.

## Reference findings

The FAQ emphasizes clearances, separated actors, correctly targeted effects, complete textures on newly exposed moving surfaces, and avoiding unintended inescapable areas. Tags associate actions with targets; they are not geometry indices. Its engine-specific flags, dimensions, file formats and rendering limits are historical Doom implementation details, not Godot requirements. ([FAQ](https://www.gamers.org/dhs/helpdocs/pwadmake.html), [Tag](https://doomwiki.org/wiki/Tag))

The layout article argues for connected spatial volumes: windows and ledges allow combat between areas; different heights change threats; views establish where the player will go; mechanisms can transform routes. Decorative detail cannot compensate for a sequence of enclosed rooms. Contrasting scales and careful enemy angles matter more than dressing each box. ([Article](https://tankermottind.tumblr.com/post/123754770395/the-secret-to-a-good-doom-level-its-the-layout))

## Review of Eyesore, not a source claim

The current v13 pass has distinct objective journeys, return shortcuts, independent Containment branches, physical height changes and a visible Breach descent. It still constructs predominantly rectangular rooms on a 40m grid, joined by enclosed axis-aligned links. Observation glass usually blocks fire. Thus it improves progression and support geometry, but does not yet satisfy the intended spatial combat standard. More props or random room shuffling will not resolve that.

The construction specialist must review a feasible cross-area combat connection in each Ward map before any additional decoration. Preserve the passing candidate first. Keep credential/feed/anchor prerequisites intact: an opening can reveal or expose a later area without providing a traversable shortcut. No invisible movement-only wall may stand in for an actual sill, barrier or height difference.

## Construction acceptance contract

These are project decisions, not numerical rules from either reference:

1. Author objective dependencies and room purposes before geometry. Use deterministic scene construction; random seeds must not decide whether progression is solvable.
2. For each proposed connection, record both room IDs, absolute aperture bounds, actor path policy, sight and weapon paths, and the objective state in which it matters. A glass pane is an observation connection, not a firing connection.
3. Show the same landmark from an early route and its later destination. Demonstrate a useful combat angle at a different elevation. Retain real cover and at least one movement response to that threat.
4. Review the layout from enemy positions as well as from the player route. Do not add an enemy solely to increase the count. Test unintended early activation and checkpoint safety after opening sightlines.
5. Verify every possible objective order, reachable supplies without secrets, shortcut direction, escape from drops, and all moving-surface states. Test movement, hitscan and projectiles against the actual exported geometry.
6. Judge the result in real gameplay views and navigation. Diagrams, metadata assertions and bot completion cannot establish visual match, tactical quality or the 20–25-minute human pacing target.

The coordinator owns research and acceptance decisions. Workers receive bounded implementation contracts and do not browse or invent replacement objectives. This review does not claim that the structural proposals are implemented or release-verified.
