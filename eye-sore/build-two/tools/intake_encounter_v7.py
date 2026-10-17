"""Bounded Intake encounter authoring; called only by the campaign coordinator.

No scene generation, resource grants, encounter count changes or global AI tuning.
"""
from __future__ import annotations
import json
from collections import Counter
import re
from pathlib import Path

LEVEL = "pale_ward_01"


def applies(stage):
    return stage.get("campaign_level_id", stage.get("id")) == LEVEL


def apply_stage(stage):
    """Attach encounter intent before scene creation; existing progression IDs stay stable."""
    if not applies(stage):
        return
    for portal in stage["portals"]:
        if portal.get("gate") == "shortcut_one":
            portal["requires"] = ["breaker", "brass_key"]
            portal["first_open_normal"] = [1, 0, 0]
            portal["locked_message"] = "Brass key and power required · release from sterile supply side"
    arena = next(r for r in stage["rooms"] if r["id"] == "arena_one")
    arena["encounter"] = "triage cache lure / far-alcove ranged warning / melee advance"
    stage["intake_v7_encounter"] = {
        "arena": "arena_one", "bait": "Bait_arena_one", "count": stage["enemy_counts"]["arena_one"],
        "ranged_slot": "west_north", "wake": "all closet shutters fully open",
        "control": "breaker", "requires": ["clear_arena_one"],
        "retreat": "entry seals only beyond 3m threshold and empty actor sweep; reopens on clear",
        "shortcut": "shortcut_one", "shortcut_requirements": ["breaker", "brass_key"],
        "shortcut_first_open_normal": [1, 0, 0],
    }


def apply_scene(sc, stage, routes):
    """Keep spawn pivots in their physical alcoves; exchange species, not populations.

    Far west slot z−9 receives the existing ranged actor; the old ranged alcove
    receives that slot's melee actor. Entry arrives at local +Z; the gun lure at
    centre therefore leaves >15m before a ranged attacker and no rear spawn.
    """
    if not applies(stage):
        return {"applied": False}
    candidates = []
    for i, text in enumerate(sc.nodes):
        if text.startswith('[node name="Spawn_') and 'metadata/arena_id = "arena_one"' in text:
            match = re.search(r'metadata/kind = ("[^"\n]+")', text)
            position = re.search(r'position = Vector3\(([^)]+)\)', text)
            assert match and position, "triage marker must carry kind and position"
            candidates.append((i, match.group(1), [float(v) for v in position.group(1).split(',')]))
    assert len(candidates) == stage["enemy_counts"]["arena_one"]
    # Author emits each room in insertion order: west slots 0..3, then east.
    # Existing roster uses its second theme kind once every three actors.
    counts = Counter(kind for _, kind, _ in candidates)
    assert sorted(counts.values()) == [1, 4], "triage roster contract changed; review species assignment"
    ranged = next(candidate for candidate in candidates if counts[candidate[1]] == 1)
    far = candidates[0]
    if ranged[0] != far[0]:
        for target, replacement in ((far, ranged[1]), (ranged, far[1])):
            sc.nodes[target[0]] = re.sub(r'(metadata/kind = )"[^"\n]+"', lambda m: m.group(1) + replacement, sc.nodes[target[0]])
    # Metadata fallback allows integration after a stock author that has not yet
    # emitted optional portal metadata. It never changes another door or level.
    for i, text in enumerate(sc.nodes):
        if text.startswith('[node name="Door_shortcut_one" '):
            if "metadata/first_open_normal" not in text:
                sc.nodes[i] = text.rstrip() + '\nmetadata/first_open_normal = Vector3(1, 0, 0)\n\n'
    return {"applied": True, "actor_count": len(candidates), "positions_unchanged": True,
            "ranged_position": far[2], "melee_reassigned_position": ranged[2],
            "roster_counts_unchanged": True}


def contract():
    return json.loads((Path(__file__).resolve().parents[1] / "docs/intake-v7/encounter.json").read_text())
