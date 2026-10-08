#pragma once

// Authored, renderer-independent data for the compact combat calibration room.
// World axes follow engine3d.cpp: +Y is up, the floor is Y=0, and +Z is south.
namespace eyesore {

struct SceneVec3 {
  float x, y, z;
};

struct SceneBox {
  // Axis-aligned bounds; min/max are inclusive geometry bounds in world units.
  float min_x, min_y, min_z;
  float max_x, max_y, max_z;
};

struct LightRegion {
  const char *name;
  // Rectangular region on the floor plane. Values are normalized brightness
  // multipliers; they are deterministic authored values, not animated lights.
  float min_x, min_z, max_x, max_z;
  float brightness;
};

struct CalibrationScene {
  float half_width, half_depth, ceiling_height;
  SceneVec3 player_start;
  float player_yaw_radians;
  SceneVec3 weapon_pickup;
  SceneVec3 caster_spawn;
  const SceneBox *solid_boxes;
  int solid_box_count;
  const LightRegion *light_regions;
  int light_region_count;
};

// Geometry and placement constants are defined in calibration_scene.cpp.
extern const CalibrationScene kCalibrationScene;

}  // namespace eyesore
