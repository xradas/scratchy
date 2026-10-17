"""Ash Approach visual dressing for the authored v15 route.

All pieces in this module are visible, non-colliding details. The level author
owns walkable surfaces, cover, gates, controls, and every gameplay collider.
Positions follow room centres and dimensions so the dressing stays attached to
the intended functional space when a room is adjusted.
"""

from __future__ import annotations


EMBER = (1.0, 0.34, 0.075, 1.0)


def _tinted_atlas(sc, source, name, tint, metal=None):
    """Reuse exact authored atlas texels with a distinct architectural tint."""
    prefix = '[sub_resource type="ShaderMaterial" id="' + source + '"]'
    original = next(item for item in sc.sub if item.startswith(prefix))
    modified = original.replace('id="' + source + '"', 'id="' + name + '"', 1)
    modified = modified.replace('shader_parameter/tint = Color(1,1,1,1)',
                                'shader_parameter/tint = Color(' + ','.join(map(str, tint)) + ')')
    if metal is not None:
        modified = modified.replace('shader_parameter/metal = .18',
                                    'shader_parameter/metal = ' + str(metal))
    sc.sub.append(modified)


def _box(sc, name, at, size, material, rotation=None):
    sc.box(name, at, size, material, False, rot=rotation)


def _flame(sc, name, x, y, z, reach=11.0):
    """A compact iron wall sconce with a layered, visible ember flame."""
    _box(sc, name + "Socket", (x, y - .19, z), (.50, .32, .50), "ash15_iron")
    _box(sc, name + "Cup", (x, y, z), (.42, .13, .42), "steel")
    _box(sc, name + "FireOuter", (x, y + .27, z), (.27, .57, .22), "ash15_fire", (0, 0, 27))
    _box(sc, name + "FireCore", (x, y + .31, z + .035), (.10, .36, .13), "ash15_fire_core", (0, 0, -19))
    sc.light(name + "Light", (x, y + .34, z), EMBER, 4.6, reach + 2.0)


def _arch(sc, name, x, floor, z, span, height, depth):
    """Stepped pointed Gothic arch relief, clear above the player and doors."""
    top = floor + height
    side_x = span * .49
    for side in (-1, 1):
        _box(sc, name + "Pier" + str(side), (x + side * side_x, floor + height * .5, z),
             (.72, height - .3, depth), "ash15_cut_stone")
        _box(sc, name + "Spring" + str(side), (x + side * span * .25, top - .68, z),
             (span * .50, .70, depth), "ash15_cut_stone", (0, 0, -side * 29))
        _box(sc, name + "IronPin" + str(side), (x + side * side_x, floor + height * .36, z + depth * .52),
             (.56, .12, .09), "ash15_burnished_iron")
    _box(sc, name + "Crown", (x, top - .12, z), (.72, .55, depth + .06), "ash15_cut_stone")


def _banner(sc, name, x, top, z, width=1.45, drop=3.1):
    _box(sc, name + "IronRod", (x, top + .12, z), (width + .33, .09, .12), "ash15_burnished_iron")
    _box(sc, name + "Cloth", (x, top - drop * .5, z + .08),
         (width, drop, .07), "ash15_red_banner")
    _box(sc, name + "Split", (x + width * .30, top - drop + .25, z + .12),
         (width * .28, .52, .07), "ash15_oxblood", (0, 0, -13))


def _room(sc, room):
    rid = room["id"]
    x, y, z = room["center"]
    sx, height, sz = room["size"]
    # Perimeter relief and overhead details never impersonate solid cover.
    if rid in {"siege_approach", "inner_bridge", "cloister", "gatehouse"}:
        for side in (-1, 1):
            px = x + side * min(sx * .32, 8.0)
            _banner(sc, "Ash15_" + rid + "_Banner" + str(side), px,
                    y + min(height - .55, 6.1), z - sz * .28, 1.65, 2.95)
            _flame(sc, "Ash15_" + rid + "_Sconce" + str(side),
                   x + side * (sx / 2 - .75), y + min(height - 1.0, 3.45),
                   z - sz * .27)

    if rid == "siege_approach":
        # The first long sightline frames a lit gate in a sequence of arches.
        for index, offset in enumerate((-.24, .12)):
            _arch(sc, "Ash15_ApproachArch" + str(index), x, y,
                  z + sz * offset, sx - 2.2, min(height - .35, 5.65), .72)
        for side in (-1, 1):
            _box(sc, "Ash15_ApproachScorch" + str(side),
                 (x + side * (sx / 2 - .37), y + 1.65, z - sz * .15),
                 (.035, 2.6, min(4.0, sz * .18)), "damaged")
        # The actual raised bridge is glimpsed through the eastern high
        # aperture. Torch brackets mark its jambs; a cold fill reveals depth.
        for index, zz in enumerate((z + 7.7, z + 14.5)):
            _flame(sc, "Ash15_BridgeVistaTorch" + str(index),
                   x + sx / 2 - .75, y + 3.3, zz, 13)
        sc.light("Ash15_BridgeVistaDepth", (x + sx / 2 + 8, y + 8.5, z + 11),
                 (.45, .61, .75, 1), 3.4, 19)
    elif rid == "trench":
        for side in (-1, 1):
            px = x + side * (sx / 2 - .42)
            _box(sc, "Ash15_TrenchSoot" + str(side), (px, y + 1.65, z),
                 (.035, 2.8, min(sz * .55, 12.0)), "damaged")
            _flame(sc, "Ash15_TrenchTorch" + str(side), px - side * .35, y + 2.8,
                   z + side * sz * .22, 9.0)
    elif rid == "breach_camp":
        for side in (-1, 1):
            px = x + side * min(sx * .31, 7.5)
            _box(sc, "Ash15_CampSiegeRib" + str(side),
                 (px, y + min(height - .5, 3.75), z - sz * .2),
                 (.5, .45, min(sz * .5, 9)), "ash15_iron", (0, side * 12, 0))
            _banner(sc, "Ash15_CampPennon" + str(side), px,
                    y + min(height - .5, 4.6), z + sz * .21, 1.3, 2.4)
    elif rid == "lower_crypt":
        for index, offset in enumerate((-.22, .18)):
            _arch(sc, "Ash15_CryptVault" + str(index), x, y,
                  z + sz * offset, sx - 2.2, min(height - .4, 4.6), .58)
        sc.light("Ash15_CryptColdFill", (x, y + min(height - .7, 4), z),
                 (.26, .34, .42, 1), .55, max(sx, sz) * .65)
    elif rid == "stair_tower":
        for side in (-1, 1):
            _banner(sc, "Ash15_TowerStandard" + str(side),
                    x + side * min(sx * .3, 4), y + min(height - .35, 6.2), z, 1.5, 3.5)
            _flame(sc, "Ash15_TowerBeacon" + str(side),
                   x + side * (sx / 2 - .55), y + min(height - .7, 4.5), z)
    elif rid in {"battlement", "crosswall"}:
        for side in (-1, 1):
            _banner(sc, "Ash15_" + rid + "_Standard" + str(side),
                    x + side * min(sx * .30, 6), y + min(height - .45, 5.5),
                    z - sz * .23, 1.35, 2.85)
        _box(sc, "Ash15_" + rid + "_IronCrown", (x, y + height - .6, z),
             (min(sx * .7, 13), .23, .46), "ash15_iron")
    elif rid == "gatehouse":
        # The lifted portcullis teeth identify a working gate without blocking it.
        for index in range(7):
            px = x + (index - 3) * min(.72, sx / 11)
            _box(sc, "Ash15_GateTooth" + str(index),
                 (px, y + min(height - .7, 4.35), z - sz * .27),
                 (.12, .85, .19), "ash15_iron")
        _arch(sc, "Ash15_GateHouseCrown", x, y, z - sz * .26,
              sx - 2.2, min(height - .35, 5.2), .72)
    elif rid == "winch":
        for side in (-1, 1):
            _box(sc, "Ash15_WinchChain" + str(side),
                 (x + side * (sx / 2 - .8), y + min(height - .8, 3.8), z),
                 (.16, min(2.5, height - 1.2), .16), "ash15_iron")
        _flame(sc, "Ash15_WinchFire", x + sx / 2 - .65,
               y + min(height - 1.0, 3.2), z - sz * .28)
    elif rid == "inner_bridge":
        for side in (-1, 1):
            _box(sc, "Ash15_BridgeSuspender" + str(side),
                 (x + side * (sx / 2 - .48), y + min(height - .7, 4.5), z),
                 (.13, min(3.1, height - 1.0), .13), "ash15_iron")
    elif rid == "cloister":
        for index, offset in enumerate((-.29, .02, .31)):
            _arch(sc, "Ash15_CloisterVault" + str(index), x, y,
                  z + sz * offset, sx - 2.2, min(height - .35, 6.7), .8)
    elif rid == "armory_hall":
        for side in (-1, 1):
            px = x + side * (sx / 2 - .45)
            for index in range(3):
                zz = z + (index - 1) * min(2.8, sz * .19)
                _box(sc, "Ash15_ArmoryRack" + str(side) + str(index),
                     (px, y + 2.0, zz), (.11, 2.3, 1.6), "ash15_iron")
                _box(sc, "Ash15_ArmoryBlade" + str(side) + str(index),
                     (px - side * .08, y + 2.05, zz), (.07, 1.35, .13), "steel", (0, 0, side * 15))
    elif rid == "furnace_gate":
        _arch(sc, "Ash15_ForgeMouth", x, y, z - sz * .27,
              sx - 2.2, min(height - .35, 5.5), .8)
        for side in (-1, 1):
            _flame(sc, "Ash15_ForgeFlame" + str(side),
                   x + side * min(sx * .32, 5.5), y + 2.5, z - sz * .25, 14)
        # Dress the real exit switch, which is authored after this pass. Its
        # collider/interaction metadata remain on the gameplay node.
        front = z + 5.3
        _box(sc, "Ash15_ExitIronFace", (x, y + 1, front),
             (1.57, 1.83, .055), "steel")
        _box(sc, "Ash15_ExitInset", (x, y + 1.12, front + .032),
             (.67, .50, .02), "ash15_iron")
        _box(sc, "Ash15_ExitEmber", (x, y + 1.12, front + .047),
             (.43, .18, .025), "ash15_fire")


def decorate(sc, level):
    """Add only Ash Approach visual nodes after its authored physical shell."""
    if level["id"] != "ash_citadel_01":
        raise ValueError("Ash Approach dressing used on a different level")
    sc.mat("ash15_iron", (.12, .105, .09, 1))
    sc.mat("ash15_oxblood", (.23, .025, .018, 1))
    sc.mat("ash15_fire", (.86, .19, .018, 1), 1.9)
    sc.mat("ash15_fire_core", (1, .62, .09, 1), 2.6)
    _tinted_atlas(sc, "pillar", "ash15_cut_stone", (1.52, 1.42, 1.34, 1))
    _tinted_atlas(sc, "steel", "ash15_burnished_iron", (1.15, 1.23, 1.31, 1), .42)
    _tinted_atlas(sc, "banner", "ash15_red_banner", (1.22, .76, .72, 1))
    for room in level["rooms"]:
        _room(sc, room)
        if room["id"] in {"siege_approach", "lower_crypt", "stair_tower", "gatehouse", "cloister", "furnace_gate"}:
            x, y, z = room["center"]
            sx, h, sz = room["size"]
            sc.light("Ash15_ColdFill_" + room["id"],
                     (x - sx * .23, y + min(h - .8, 5.2), z - sz * .18),
                     (.53, .62, .70, 1), 2.0, max(sx, sz) * .74)
