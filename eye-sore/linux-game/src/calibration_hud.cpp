#include "calibration_hud.h"

#include <SDL2/SDL_opengl.h>

#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>

namespace eyesore {
namespace {

struct Glyph {
    char character;
    unsigned char rows[7];
};

// Five least-significant bits form a row, left to right from bit 4 to bit 0.
static const Glyph kGlyphs[] = {
    {'A',{14,17,17,31,17,17,17}}, {'B',{30,17,17,30,17,17,30}},
    {'C',{14,17,16,16,16,17,14}}, {'D',{30,17,17,17,17,17,30}},
    {'E',{31,16,16,30,16,16,31}}, {'F',{31,16,16,30,16,16,16}},
    {'G',{14,17,16,23,17,17,15}}, {'H',{17,17,17,31,17,17,17}},
    {'I',{14,4,4,4,4,4,14}}, {'J',{7,2,2,2,18,18,12}},
    {'K',{17,18,20,24,20,18,17}}, {'L',{16,16,16,16,16,16,31}},
    {'M',{17,27,21,21,17,17,17}}, {'N',{17,25,21,19,17,17,17}},
    {'O',{14,17,17,17,17,17,14}}, {'P',{30,17,17,30,16,16,16}},
    {'Q',{14,17,17,17,21,18,13}}, {'R',{30,17,17,30,20,18,17}},
    {'S',{15,16,16,14,1,1,30}}, {'T',{31,4,4,4,4,4,4}},
    {'U',{17,17,17,17,17,17,14}}, {'V',{17,17,17,17,17,10,4}},
    {'W',{17,17,17,21,21,21,10}}, {'X',{17,17,10,4,10,17,17}},
    {'Y',{17,17,10,4,4,4,4}}, {'Z',{31,1,2,4,8,16,31}},
    {'0',{14,17,19,21,25,17,14}}, {'1',{4,12,4,4,4,4,14}},
    {'2',{14,17,1,2,4,8,31}}, {'3',{30,1,1,14,1,1,30}},
    {'4',{2,6,10,18,31,2,2}}, {'5',{31,16,16,30,1,1,30}},
    {'6',{14,16,16,30,17,17,14}}, {'7',{31,1,2,4,8,8,8}},
    {'8',{14,17,17,14,17,17,14}}, {'9',{14,17,17,15,1,1,14}},
    {':',{0,4,4,0,4,4,0}}, {'.',{0,0,0,0,0,12,12}},
    {',',{0,0,0,0,4,4,8}}, {'!',{4,4,4,4,4,0,4}},
    {'?',{14,17,1,2,4,0,4}}, {'/',{1,2,2,4,8,8,16}},
    {'-',{0,0,0,31,0,0,0}}, {'+',{0,4,4,31,4,4,0}},
    {'%',{17,2,4,8,17,0,0}}, {'=',{0,0,31,0,31,0,0}},
    {'(',{2,4,8,8,8,4,2}}, {')',{8,4,2,2,2,4,8}},
    {'[',{14,8,8,8,8,8,14}}, {']',{14,2,2,2,2,2,14}},
    {'\'',{4,4,8,0,0,0,0}}, {'_',{0,0,0,0,0,0,31}},
    {'<',{2,4,8,16,8,4,2}}, {'>',{8,4,2,1,2,4,8}}
};

constexpr float kDesignWidth = 1280.0f;
constexpr float kDesignHeight = 720.0f;
constexpr float kCreamR = 0.93f, kCreamG = 0.84f, kCreamB = 0.62f;
constexpr float kPanelR = 0.055f, kPanelG = 0.050f, kPanelB = 0.045f;

const Glyph *findGlyph(char c) {
    c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    for (const Glyph &glyph : kGlyphs) {
        if (glyph.character == c) return &glyph;
    }
    return nullptr;
}

void rect(float x, float y, float w, float h, float r, float g, float b, float a = 1.0f) {
    glColor4f(r,g,b,a);
    glBegin(GL_QUADS);
    glVertex2f(x,y); glVertex2f(x+w,y); glVertex2f(x+w,y+h); glVertex2f(x,y+h);
    glEnd();
}

void text(const char *value, float x, float y, float pixel, float r = kCreamR,
          float g = kCreamG, float b = kCreamB) {
    if (!value) return;
    glColor4f(r,g,b,1.0f);
    glBegin(GL_QUADS);
    for (const char *p = value; *p; ++p, x += 6.0f * pixel) {
        const Glyph *glyph = findGlyph(*p);
        if (!glyph) continue;
        for (int row=0; row<7; ++row) {
            for (int col=0; col<5; ++col) {
                if ((glyph->rows[row] & (1u << (4-col))) == 0) continue;
                const float left = x + col*pixel, top = y + row*pixel;
                glVertex2f(left,top); glVertex2f(left+pixel,top);
                glVertex2f(left+pixel,top+pixel); glVertex2f(left,top+pixel);
            }
        }
    }
    glEnd();
}

void panel(float x, float y, float w, float h) {
    rect(x+3,y+3,w,h,0,0,0,0.48f);
    rect(x,y,w,h,kPanelR,kPanelG,kPanelB,0.91f);
    rect(x,y,w,2.0f,0.55f,0.31f,0.12f,0.95f);
}

const char *weaponName(HudWeapon weapon) {
    switch (weapon) {
        case HudWeapon::Shotgun: return "RIVET SHOTGUN";
        case HudWeapon::Arc: return "ARC CANNON";
        default: return "EMBER PISTOL";
    }
}

void centeredText(const char *label, float y, float pixel) {
    const float width = static_cast<float>(std::strlen(label)) * 6.0f * pixel - pixel;
    text(label,(kDesignWidth-width)*0.5f,y,pixel);
}

void overlay(const HudState &state, float pixel) {
    rect(0,0,kDesignWidth,kDesignHeight,0.015f,0.012f,0.010f,0.72f);
    float y = 270.0f;
    if (state.dead) {
        centeredText("YOU DIED",y,5.0f);
        centeredText("PRESS R TO RESTART",y+58,2.0f);
    } else if (state.complete) {
        centeredText("SECTOR CLEAR",y,4.0f);
        centeredText("PRESS R TO RESTART",y+52,2.0f);
    } else if (state.help) {
        centeredText("FIELD MANUAL",y,3.0f);
        centeredText("WASD MOVE  MOUSE LOOK",y+49,1.7f);
        centeredText("CLICK FIRE  1 PISTOL  2 SHOTGUN  3 ARC",y+81,1.45f);
        centeredText("F1 CLOSE HELP  R RESTART",y+113,1.7f);
    } else if (state.paused) {
        centeredText("PAUSED",y,4.0f);
        centeredText("PRESS SPACE TO RESUME",y+55,1.8f);
    }
    (void)pixel;
}

} // namespace

void drawCalibrationHud(const HudState &state, int drawableWidth, int drawableHeight) {
    if (drawableWidth <= 0 || drawableHeight <= 0) return;
    const float sx = drawableWidth/kDesignWidth, sy = drawableHeight/kDesignHeight;
    const float pixel = std::max(1.0f,std::min(sx,sy)*2.0f);

    glPushAttrib(GL_ENABLE_BIT | GL_COLOR_BUFFER_BIT | GL_CURRENT_BIT | GL_TRANSFORM_BIT |
                 GL_VIEWPORT_BIT | GL_SCISSOR_BIT | GL_TEXTURE_BIT | GL_DEPTH_BUFFER_BIT);
    glViewport(0,0,drawableWidth,drawableHeight);
    glDisable(GL_DEPTH_TEST);
    // The HUD is screen space. The world point light must not dim its text or
    // panels as if they were surfaces inside the room.
    glDisable(GL_LIGHTING);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_SCISSOR_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    glMatrixMode(GL_PROJECTION);
    glPushMatrix(); glLoadIdentity(); glOrtho(0,kDesignWidth,kDesignHeight,0,-1,1);
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix(); glLoadIdentity();

    panel(24,22,365,49);
    std::string encounter = state.encounter ? state.encounter : "CALIBRATION";
    text(encounter.c_str(),42,42,pixel);

    panel(24,657,238,43);
    text("F1 HELP   R RESTART",40,674,pixel*0.82f);

    panel(24,590,320,52);
    const int health = std::max(0,std::min(999,state.health));
    const std::string healthLabel = "HEALTH  " + std::to_string(health) + "%";
    text(healthLabel.c_str(),42,611,pixel*1.12f);

    const float weaponWidth = 390.0f;
    panel(kDesignWidth-24-weaponWidth,590,weaponWidth,52);
    const char *name = weaponName(state.selectedWeapon);
    std::string weaponLabel = std::string(name) + "   AMMO: INFINITE";
    if (state.selectedWeapon == HudWeapon::Shotgun && !state.shotgunUnlocked)
        weaponLabel = "SHOTGUN LOCKED";
    text(weaponLabel.c_str(),kDesignWidth-weaponWidth-5,611,pixel*1.05f);

    if (state.help || state.paused || state.dead || state.complete) overlay(state,pixel);

    glPopMatrix();
    glMatrixMode(GL_PROJECTION); glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopAttrib();
}

} // namespace eyesore
