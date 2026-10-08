#pragma once

#include <cstddef>
#include <vector>

namespace combat_world {

struct Vec3 { float x, y, z; };
// Inclusive physical extents. The renderer should use these same dimensions.
struct Box { Vec3 min, max; };
enum class Surface { none, room, wall, pillar };
struct Solid { Box box; Surface surface; };
struct Hit {
  bool blocked = false;
  float fraction = 1.0f; // 0 at start, 1 at end of the requested segment
  Vec3 position{};
  Vec3 normal{};
  Surface surface = Surface::none;
  std::size_t solid_index = 0; // index in World::solids; unused for room
};

struct World {
  Box room{}; // playable interior, including floor and ceiling
  std::vector<Solid> solids;
};

// Current descent geometry. New rooms can construct World directly.
World descent_world();
World starling_rink_world();

// Actor is a vertical cylinder in X/Z. Walls are exact boxes, with circular
// clearance at corners; the room is inset by radius. height includes feet.
bool blocks_actor(const World &world, Vec3 feet, float radius, float height);

// Find the first contact along a finite segment, including vertical-only and
// axis-aligned segments. radius=0 is an exact ray; positive radius sweeps a
// sphere, so fast projectiles cannot skip cover. This works with a zero-length
// segment too, which reports contact only when its start is already blocked.
// A segment beginning inside a solid returns fraction 0. Room contact is
// returned at the first inner boundary (inset by radius).
Hit trace_segment(const World &world, Vec3 start, Vec3 end, float radius = 0.0f);

// Line of sight to an endpoint: contact at the endpoint itself is allowed.
bool clear_line(const World &world, Vec3 start, Vec3 end);

} // namespace combat_world
