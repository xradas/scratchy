# Calibration HUD integration

The HUD is an isolated fixed-function OpenGL overlay in `src/calibration_hud.h` and `.cpp`.
Once the 3D scene is drawn, construct an `eyesore::HudState` snapshot and call
`eyesore::drawCalibrationHud(state, drawableWidth, drawableHeight)` immediately
before swapping the window buffers. Pass SDL drawable dimensions (for HiDPI,
`SDL_GL_GetDrawableSize`, not logical window dimensions). The draw call restores
the OpenGL state it changes.

Map the live health, selected weapon, shotgun unlock and encounter label into the
snapshot. Set `help`, `paused`, `dead` and `complete` from the current game mode.
Ammo is explicitly shown as `INFINITE` while the prototype has no finite ammo
system. Keep the restart and help bindings aligned with the engine's input map;
the pause card currently describes Space as resume.

Build integration when ready: add `src/calibration_hud.cpp` to the `OUT3D`
prerequisites and compile/link inputs in `linux-game/Makefile`.
