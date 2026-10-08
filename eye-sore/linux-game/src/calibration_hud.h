#ifndef EYESORE_CALIBRATION_HUD_H
#define EYESORE_CALIBRATION_HUD_H

namespace eyesore {

enum class HudWeapon {
    Pistol,
    Shotgun,
    Arc
};

// Read-only snapshot consumed by drawCalibrationHud. Strings are copied by
// neither this module nor its renderer; callers own their lifetime.
struct HudState {
    int health = 100;
    HudWeapon selectedWeapon = HudWeapon::Pistol;
    bool shotgunUnlocked = false;
    const char *encounter = "CALIBRATION";
    bool paused = false;
    bool help = false;
    bool dead = false;
    bool complete = false;
};

// Draws a 2D HUD over the current frame using a 1280x720 design coordinate
// space scaled to the supplied drawable dimensions. Call after the 3D scene.
void drawCalibrationHud(const HudState &state, int drawableWidth, int drawableHeight);

} // namespace eyesore

#endif
