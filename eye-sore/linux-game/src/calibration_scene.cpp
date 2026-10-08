#include "calibration_scene.h"

namespace eyesore {
namespace {

constexpr float kHalfWidth = 12.0f;
constexpr float kHalfDepth = 10.0f;
constexpr float kCeiling = 5.0f;

// A compact rectangular shell plus an entry divider with a 3-unit eastern gap.
// The gap is measured in X from +3 to +6. Box ends align exactly with it.
constexpr SceneBox kSolidBoxes[] = {
    {-12.0f, 0.0f, -10.0f, -11.6f, 5.0f, 10.0f}, // west shell
    { 11.6f, 0.0f, -10.0f,  12.0f, 5.0f, 10.0f}, // east shell
    {-12.0f, 0.0f, -10.0f,  12.0f, 5.0f, -9.6f}, // north shell
    {-12.0f, 0.0f,   9.6f,  12.0f, 5.0f, 10.0f}, // south shell
    {-12.0f, 0.0f,   5.0f,   3.0f, 5.0f,  6.0f}, // entry divider west wing
    {  6.0f, 0.0f,   5.0f,  12.0f, 5.0f,  6.0f}, // entry divider east wing
    // Full-height central block splits the sightline and leaves routes on both sides.
    { -2.0f, 0.0f,   0.0f,   0.0f, 5.0f,  2.5f},
};

// Region rectangles are separated so renderers can choose flat material values
// or use them as inputs to a later sector/light implementation.
constexpr LightRegion kLightRegions[] = {
    {"west-lane",  -12.0f, -10.0f, -4.0f, 5.0f, 0.42f},
    {"main-combat", -4.0f, -10.0f, 3.0f, 5.0f, 0.68f},
    {"east-lane",    3.0f, -10.0f, 12.0f, 5.0f, 0.88f},
    {"entry",      -12.0f,   5.0f, 12.0f,10.0f, 0.75f},
};

}  // namespace

const CalibrationScene kCalibrationScene = {
    kHalfWidth,
    kHalfDepth,
    kCeiling,
    {-6.0f, 1.42f, 8.0f},  // player starts behind the divider, facing the opening
    -1.570796327f,
    {-2.0f, 0.0f, 8.0f},   // shotgun pickup before entering the combat room
    {0.0f, 0.0f, -2.0f},   // single ranged caster target
    kSolidBoxes,
    static_cast<int>(sizeof(kSolidBoxes) / sizeof(kSolidBoxes[0])),
    kLightRegions,
    static_cast<int>(sizeof(kLightRegions) / sizeof(kLightRegions[0])),
};

}  // namespace eyesore
