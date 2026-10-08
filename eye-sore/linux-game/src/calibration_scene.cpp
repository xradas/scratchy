#include "calibration_scene.h"

namespace eyesore {
namespace {

constexpr float kHalfWidth = 12.0f;
constexpr float kHalfDepth = 10.0f;
constexpr float kCeiling = 5.0f;

// A compact rectangular shell plus an entry divider with a 3-unit center gap.
// The gap is measured in X from -1.5 to +1.5. Box ends align exactly with it.
constexpr SceneBox kSolidBoxes[] = {
    {-12.0f, 0.0f, -10.0f, -11.6f, 5.0f, 10.0f}, // west shell
    { 11.6f, 0.0f, -10.0f,  12.0f, 5.0f, 10.0f}, // east shell
    {-12.0f, 0.0f, -10.0f,  12.0f, 5.0f, -9.6f}, // north shell
    {-12.0f, 0.0f,   9.6f,  12.0f, 5.0f, 10.0f}, // south shell
    {-12.0f, 0.0f,   4.0f,  -1.5f, 5.0f,  4.4f}, // divider west wing
    {  1.5f, 0.0f,   4.0f,  12.0f, 5.0f,  4.4f}, // divider east wing
    // Broad low cover leaves a route around either side and does not seal the room.
    { -1.8f, 0.0f,  -1.9f,   1.8f, 1.45f, -0.9f},
};

// Region rectangles are separated so renderers can choose flat material values
// or use them as inputs to a later sector/light implementation.
constexpr LightRegion kLightRegions[] = {
    {"entry",       -11.5f,  4.4f, 11.5f,  9.5f, 0.72f},
    {"main-combat", -11.5f, -9.5f, 11.5f,  4.0f, 0.96f},
    {"north-recess", -3.4f, -9.5f,  3.4f, -5.3f, 0.66f},
};

}  // namespace

const CalibrationScene kCalibrationScene = {
    kHalfWidth,
    kHalfDepth,
    kCeiling,
    {0.0f, 1.42f, 7.7f},   // player starts south, facing north (-Z)
    0.0f,
    {4.6f, 0.0f, -7.1f},   // shotgun pickup candidate, visible beyond cover
    {0.0f, 0.0f, -7.6f},   // single ranged caster target
    kSolidBoxes,
    static_cast<int>(sizeof(kSolidBoxes) / sizeof(kSolidBoxes[0])),
    kLightRegions,
    static_cast<int>(sizeof(kLightRegions) / sizeof(kLightRegions[0])),
};

}  // namespace eyesore
