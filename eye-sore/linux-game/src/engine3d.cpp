#include <SDL2/SDL.h>
#include <GL/gl.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <vector>

static constexpr int W = 1280, H = 720;
static constexpr int ENEMY_COUNT = 14;
struct Vec3 { float x, y, z; };
enum EnemyState { EnemyWalk, EnemyPain, EnemyAttack, EnemyDeath, EnemyGib, EnemyCorpse };
enum EnemyDirection { EnemyFront, EnemyFrontRight, EnemyRight, EnemyBackRight, EnemyBack, EnemyBackLeft, EnemyLeft, EnemyFrontLeft, EnemyDirectionCount };
enum EnemyAtlas { DirectionalAtlas, CombatAtlas };
enum ProjectileSprite { PlayerPistolSprite, PlayerShotgunSprite, PlayerArcSprite, CultistFireSprite, WraithPlasmaSprite, ProjectileSpriteCount };
enum ProjectileDirection { ProjectileToward, ProjectileTowardRight, ProjectileRight, ProjectileAwayRight, ProjectileAway, ProjectileAwayLeft, ProjectileLeft, ProjectileTowardLeft, ProjectileDirectionCount };
struct EnemyDefinition {
  float world_width, world_height, baseline;
  float hitbox_width, hitbox_height, hitbox_depth;
};
struct EnemyFrame { EnemyAtlas atlas; int column, row; float duration, pivot_x, pivot_y; bool mirror; };
struct EnemyClip { const EnemyFrame *frames; int count; bool loop; int event_frame; };
struct Enemy { Vec3 pos; float hp, max_hp, facing, state_time, walk_time, attack_cooldown, roam_timer, roam_heading; bool alive, event_fired, gibbed; EnemyState state; int type, target_enemy; };

// Render size and collision size are deliberately independent. Art frames never resize
// the actor: every pose is placed on this fixed world-space canvas and foot baseline.
static constexpr EnemyDefinition ENEMY_DEFS[] = {
  {1.52f,2.15f,0.00f,1.34f,2.08f,.64f},
  {1.30f,2.35f,0.00f,1.10f,2.28f,.58f},
  {1.44f,2.05f,0.28f,1.24f,1.94f,.60f},
  {1.60f,2.55f,0.00f,1.40f,2.46f,.68f}
};
static constexpr float ARENA_HALF_WIDTH=36.0f,ARENA_HALF_DEPTH=30.0f,ARENA_CEILING=5.0f;
static constexpr Vec3 ENEMY_SPAWNS[ENEMY_COUNT]={{4,0,4},{-5,0,-4},{0,0,16},{-24,0,17},{22,0,19},{-8,0,26},{12,0,25},{0,0,-17},{-24,0,-17},{22,0,-19},{-8,0,-26},{12,0,-25},{-27,0,0},{27,0,0}};
static constexpr float ENEMY_HEALTH[ENEMY_COUNT]={4,6,8,10,4,6,8,10,4,6,8,10,6,8};
static constexpr int ENEMY_TYPES[ENEMY_COUNT]={0,1,2,3,0,1,2,3,0,1,2,3,1,2};
static constexpr float PILLARS[][2]={{-18,-19},{18,-19},{-18,19},{18,19},{0,18},{0,-18},{-26,0},{26,0}};
struct WallBlock { float x0,z0,x1,z1; };
// The outer shell is one connected arena; these blocks divide it into the
// start hall, north/south wings and side rooms, with deliberate door gaps.
static constexpr WallBlock ROOM_WALLS[]={{-36,9,-7,10},{7,9,36,10},{-36,-10,-7,-9},{7,-10,36,-9},{-15,10,-14,21},{-15,25,-14,30},{14,10,15,21},{14,25,15,30},{-15,-30,-14,-21},{-15,-25,-14,-9},{14,-30,15,-21},{14,-25,15,-9}};

static constexpr EnemyFrame WALK_FRAMES[]={{DirectionalAtlas,0,0,.14f,.5f,0.0f,false},{DirectionalAtlas,0,1,.14f,.5f,0.0f,false},{DirectionalAtlas,0,2,.14f,.5f,0.0f,false},{DirectionalAtlas,0,3,.14f,.5f,0.0f,false}};
static constexpr EnemyFrame PAIN_FRAMES[]={{CombatAtlas,0,0,.06f,.5f,0.0f,false},{CombatAtlas,1,0,.07f,.5f,0.0f,false},{CombatAtlas,2,0,.07f,.5f,0.0f,false},{CombatAtlas,3,0,.08f,.5f,0.0f,false}};
static constexpr EnemyFrame ATTACK_FRAMES[]={{CombatAtlas,0,1,.14f,.5f,0.0f,false},{CombatAtlas,1,1,.12f,.5f,0.0f,false},{CombatAtlas,2,1,.09f,.5f,0.0f,false},{CombatAtlas,3,1,.18f,.5f,0.0f,false}};
static constexpr EnemyFrame DEATH_FRAMES[]={{CombatAtlas,0,2,.14f,.5f,0.0f,false},{CombatAtlas,1,2,.14f,.5f,0.0f,false},{CombatAtlas,2,2,.16f,.5f,0.0f,false},{CombatAtlas,3,2,.20f,.5f,0.0f,false}};
static constexpr EnemyFrame GIB_FRAMES[]={{CombatAtlas,0,3,.10f,.5f,0.0f,false},{CombatAtlas,1,3,.11f,.5f,0.0f,false},{CombatAtlas,2,3,.14f,.5f,0.0f,false},{CombatAtlas,3,3,.20f,.5f,0.0f,false}};
static constexpr EnemyFrame DEATH_CORPSE_FRAMES[]={{CombatAtlas,3,2,9999.0f,.5f,0.0f,false}};
static constexpr EnemyFrame GIB_CORPSE_FRAMES[]={{CombatAtlas,3,3,9999.0f,.5f,0.0f,false}};
static constexpr EnemyClip WALK_CLIP={WALK_FRAMES,4,true,-1},PAIN_CLIP={PAIN_FRAMES,4,false,-1},ATTACK_CLIP={ATTACK_FRAMES,4,false,2},DEATH_CLIP={DEATH_FRAMES,4,false,-1},GIB_CLIP={GIB_FRAMES,4,false,-1},DEATH_CORPSE_CLIP={DEATH_CORPSE_FRAMES,1,false,-1},GIB_CORPSE_CLIP={GIB_CORPSE_FRAMES,1,false,-1};
struct Projectile { Vec3 pos, vel; float damage, radius, travelled; int sprite; bool active; };
struct VisualProjectile { Vec3 pos, vel; float damage, radius; int sprite; bool active; };
struct EnemyProjectile { Vec3 pos, vel; float life, radius, damage; int style, sprite, owner; bool active; };
struct Impact { Vec3 pos; float life; int weapon; };
struct FirstPersonLaunch { float life, duration; int weapon; bool active; };
struct Sound { Uint8 *data; Uint32 length; };
struct EnemyCollision { float width, height, depth, bottom; };
static constexpr int MAX_ENEMY_PROJECTILES=16;
static constexpr int MAX_VISUAL_PROJECTILES=12;
static constexpr int WEAPON_SOUND_VARIANTS=3;
static constexpr const char *WEAPON_SOUND_NAMES[]={"ember-pistol","rivet-shotgun","arc-cannon"};
static constexpr float PLAYER_HEIGHT=1.42f,PLAYER_SPEED=2.85f,SPRINT_MULTIPLIER=2.0f,ENEMY_SPEED=.58f;
static constexpr float RANGED_NOTICE_DISTANCE=18.0f,MELEE_NOTICE_DISTANCE=12.0f,RANGED_ATTACK_DISTANCE=10.5f,MELEE_ATTACK_DISTANCE=1.18f;
static constexpr float WEAPON_SCREEN_BOTTOM=-1.0f;
static constexpr float WEAPON_COOLDOWNS[]={.50f,1.5f,1.5f};
static constexpr float WEAPON_ANIM_DURATIONS[]={.50f,1.20f,1.20f};
static constexpr int WEAPON_FRAME_COUNTS[]={3,4,4};
static constexpr int WEAPON_SOURCE_FRAMES[3][4]={{0,1,3,3},{0,1,2,3},{0,1,2,3}};
static float player_move_speed(bool sprinting) { return PLAYER_SPEED*(sprinting?SPRINT_MULTIPLIER:1.0f); }
static Vec3 operator+(Vec3 a, Vec3 b) { return {a.x+b.x,a.y+b.y,a.z+b.z}; }
static Vec3 operator*(Vec3 a, float b) { return {a.x*b,a.y*b,a.z*b}; }
static const EnemyFrame &clip_frame(const EnemyClip &clip, float time, int *frame_index);
static const EnemyClip &enemy_clip(const Enemy &enemy);
static float turn_toward(float current, float target, float maximum_step) {
  const float pi=3.14159265f;float delta=target-current;while(delta>pi)delta-=2*pi;while(delta< -pi)delta+=2*pi;
  delta=std::fmax(-maximum_step,std::fmin(maximum_step,delta));return current+delta;
}
static bool enemies_can_infight(const Enemy &attacker,const Enemy &victim){return attacker.type!=victim.type;}

static EnemyCollision enemy_collision(const Enemy &enemy) {
  const EnemyDefinition &def=ENEMY_DEFS[enemy.type];const EnemyClip &clip=enemy_clip(enemy);int frame_index=0;clip_frame(clip,enemy.state==EnemyWalk?enemy.walk_time:enemy.state_time,&frame_index);
  // Each visible pose gets its own body profile. Arms and spell effects may
  // extend outside it, but crouch, recoil, attack lunge, and fallen bodies no
  // longer use the standing walk cylinder.
  static constexpr float walk_width[]={.96f,1.03f,1.00f,.98f},walk_height[]={1.00f,.97f,1.00f,.98f},walk_bottom[]={0,.01f,0,.01f};
  static constexpr float pain_width[]={1.00f,.96f,.90f,.96f},pain_height[]={.98f,.94f,.89f,.95f},pain_bottom[]={0,.01f,.03f,.01f};
  static constexpr float attack_width[]={1.00f,1.10f,1.16f,1.03f},attack_height[]={1.00f,.98f,.95f,.99f},attack_bottom[]={0,.01f,.03f,.01f};
  static constexpr float death_width[]={1.00f,1.10f,1.24f,1.42f},death_height[]={.92f,.70f,.42f,.16f},death_bottom[]={0,0,0,0};
  const float *width=walk_width,*height=walk_height,*bottom=walk_bottom;
  if(enemy.state==EnemyPain){width=pain_width;height=pain_height;bottom=pain_bottom;}else if(enemy.state==EnemyAttack){width=attack_width;height=attack_height;bottom=attack_bottom;}else if(enemy.state==EnemyDeath||enemy.state==EnemyGib||enemy.state==EnemyCorpse){width=death_width;height=death_height;bottom=death_bottom;}
  int index=std::max(0,std::min(3,frame_index));return {def.hitbox_width*width[index],def.hitbox_height*height[index],def.hitbox_depth*width[index],def.baseline+bottom[index]};
}

static bool ray_enemy_hit(Vec3 origin, Vec3 ray, const Enemy &enemy, float &distance) {
  EnemyCollision collision=enemy_collision(enemy);
  float sine=std::sin(enemy.facing),cosine=std::cos(enemy.facing),dx=origin.x-enemy.pos.x,dz=origin.z-enemy.pos.z;
  float ox=dx*cosine-dz*sine,oz=dx*sine+dz*cosine,rx=ray.x*cosine-ray.z*sine,rz=ray.x*sine+ray.z*cosine,half_width=collision.width*.5f,half_depth=collision.depth*.5f;
  float a=rx*rx/(half_width*half_width)+rz*rz/(half_depth*half_depth),b=2.0f*(ox*rx/(half_width*half_width)+oz*rz/(half_depth*half_depth)),c=ox*ox/(half_width*half_width)+oz*oz/(half_depth*half_depth)-1.0f;
  float discriminant=b*b-4*a*c; if(a<.00001f||discriminant<0)return false;
  float root=std::sqrt(discriminant), near_t=(-b-root)/(2*a), far_t=(-b+root)/(2*a); if(far_t<0)return false;
  float t=near_t>=0?near_t:far_t, y=origin.y+ray.y*t;
  float bottom=enemy.pos.y+collision.bottom, top=bottom+collision.height; if(y<bottom||y>top)return false;
  distance=t; return true;
}

static bool projectile_enemy_hit(Vec3 point, float radius, const Enemy &enemy) {
  EnemyCollision collision=enemy_collision(enemy);float dx=point.x-enemy.pos.x,dz=point.z-enemy.pos.z,sine=std::sin(enemy.facing),cosine=std::cos(enemy.facing),local_x=dx*cosine-dz*sine,local_z=dx*sine+dz*cosine,half_width=collision.width*.5f+radius,half_depth=collision.depth*.5f+radius;
  bool inside_body=local_x*local_x/(half_width*half_width)+local_z*local_z/(half_depth*half_depth)<=1.0f;return inside_body&&point.y>=enemy.pos.y+collision.bottom-radius&&point.y<=enemy.pos.y+collision.bottom+collision.height+radius;
}

static GLuint texture_from_bmp(const char *file, bool black_transparent=false, int *out_width=nullptr, int *out_height=nullptr) {
  SDL_Surface *src = SDL_LoadBMP(file);
  if (!src) { char path[1024]; char *base = SDL_GetBasePath(); if (base) { std::snprintf(path,sizeof(path),"%s../%s",base,file); src = SDL_LoadBMP(path); SDL_free(base); } }
  if (!src) { std::fprintf(stderr, "Texture %s: %s\n", file, SDL_GetError()); return 0; }
  if(out_width)*out_width=src->w;
  if(out_height)*out_height=src->h;
  SDL_Surface *rgba = SDL_ConvertSurfaceFormat(src, SDL_PIXELFORMAT_ABGR8888, 0); SDL_FreeSurface(src);
  if (!rgba) return 0;
  if (black_transparent) { Uint8 *pixels=(Uint8*)rgba->pixels; for(int y=0;y<rgba->h;y++) for(int x=0;x<rgba->w;x++){Uint8 *p=pixels+y*rgba->pitch+x*4;if(p[0]<12&&p[1]<12&&p[2]<12)p[3]=0;} }
  GLuint id = 0; glGenTextures(1, &id); glBindTexture(GL_TEXTURE_2D, id);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, black_transparent?GL_NEAREST:GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, black_transparent?GL_CLAMP_TO_EDGE:GL_REPEAT); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, black_transparent?GL_CLAMP_TO_EDGE:GL_REPEAT);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, rgba->w, rgba->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba->pixels);
  SDL_FreeSurface(rgba); return id;
}

static Sound load_sound(const char *file, SDL_AudioSpec *spec) {
  Sound sound={nullptr,0};if(SDL_LoadWAV(file,spec,&sound.data,&sound.length))return sound;
  char path[1024];char *base=SDL_GetBasePath();if(base){std::snprintf(path,sizeof(path),"%s../%s",base,file);SDL_LoadWAV(path,spec,&sound.data,&sound.length);SDL_free(base);}if(!sound.data)std::fprintf(stderr,"Sound %s: %s\n",file,SDL_GetError());return sound;
}

static void draw_weapon(int weapon, bool muzzle, bool hit);
static void draw_impact(const Impact &impact) {
  if (impact.life<=0) return;
  float age=1.0f-impact.life/.28f, radius=.08f+age*(impact.weapon==1?.48f:impact.weapon==2?.62f:impact.weapon==3?.7f:.34f), alpha=1.0f-age;
  glDisable(GL_TEXTURE_2D); glDisable(GL_LIGHTING); glEnable(GL_BLEND); glBlendFunc(GL_SRC_ALPHA,GL_ONE);
  if(impact.weapon==2) glColor4f(.15f,.8f,1,alpha); else if(impact.weapon==1) glColor4f(1,.35f,.08f,alpha); else if(impact.weapon==3) glColor4f(.6f,.48f,.38f,alpha*.9f); else glColor4f(1,.85f,.35f,alpha);
  glPushMatrix(); glTranslatef(impact.pos.x,impact.pos.y,impact.pos.z); glBegin(GL_LINES);
  for(int i=0;i<12;i++){float a=i*3.14159265f/6.0f, c=std::cos(a), s=std::sin(a); glVertex3f(-radius*c,0,-radius*s);glVertex3f(radius*c,0,radius*s);glVertex3f(0,-radius*c,-radius*s);glVertex3f(0,radius*c,radius*s);glVertex3f(-radius*c,-radius*s,0);glVertex3f(radius*c,radius*s,0);} glEnd(); glColor4f(.18f,.16f,.15f,alpha*.55f); glBegin(GL_LINE_LOOP); for(int i=0;i<16;i++){float a=i*3.14159265f/8.0f;glVertex3f(std::cos(a)*radius*.72f,std::sin(a)*radius*.72f,0);} glEnd(); glBegin(GL_LINE_LOOP); for(int i=0;i<16;i++){float a=i*3.14159265f/8.0f;glVertex3f(0,std::cos(a)*radius*.58f,std::sin(a)*radius*.58f);} glEnd(); glPopMatrix();
  glDisable(GL_BLEND); glEnable(GL_LIGHTING); glEnable(GL_TEXTURE_2D);
}
static void sprite_plane(float u0,float u1,float v0,float v1,float cx,float cz,float bottom,float height,float hw,float ax,float az,float alpha) {
  glColor4f(1,1,1,alpha); glBegin(GL_QUADS); glTexCoord2f(u0,v1);glVertex3f(cx-ax*hw,bottom,cz-az*hw); glTexCoord2f(u1,v1);glVertex3f(cx+ax*hw,bottom,cz+az*hw); glTexCoord2f(u1,v0);glVertex3f(cx+ax*hw,bottom+height,cz+az*hw); glTexCoord2f(u0,v0);glVertex3f(cx-ax*hw,bottom+height,cz-az*hw); glEnd();
}
static void draw_projectile_sprite(GLuint tex, Vec3 position, Vec3 velocity, Vec3 viewer, float width, float height) {
  if(!tex)return;
  (void)velocity;
  float distance=std::sqrt((viewer.x-position.x)*(viewer.x-position.x)+(viewer.y-position.y)*(viewer.y-position.y)+(viewer.z-position.z)*(viewer.z-position.z));
  // Preserve a readable apparent size over the long room sight lines. The
  // collision volume remains unchanged; this is only billboard presentation.
  float scale=std::fmin(3.2f,std::fmax(1.0f,distance/5.5f));width*=scale;height*=scale;
  float view_angle=std::atan2(viewer.x-position.x,viewer.z-position.z),right_x=std::cos(view_angle),right_z=-std::sin(view_angle);
  glEnable(GL_TEXTURE_2D);glBindTexture(GL_TEXTURE_2D,tex);glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE);glEnable(GL_ALPHA_TEST);glAlphaFunc(GL_GREATER,.03f);glDisable(GL_LIGHTING);sprite_plane(0,1,0,1,position.x,position.z,position.y-height*.5f,height,width*.5f,right_x,right_z,1);glColor4f(1,1,1,1);glDisable(GL_ALPHA_TEST);glDisable(GL_BLEND);glEnable(GL_LIGHTING);
}
// Arc rounds are not billboards. The line trail appears only once the
// first-person bolt has cleared the weapon, so there is never a second sheet.
static void draw_arc_world_trail(Vec3 position, Vec3 velocity, float travelled) {
  float speed=std::sqrt(velocity.x*velocity.x+velocity.y*velocity.y+velocity.z*velocity.z);if(speed<.001f)return;
  Vec3 forward=velocity*(1.0f/speed),tail=position+forward*(-std::fmin(2.8f,travelled*.38f)),side={forward.z,0,-forward.x};
  glDisable(GL_TEXTURE_2D);glDisable(GL_LIGHTING);glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE);glLineWidth(2.6f);glColor4f(.18f,.88f,1,.90f);glBegin(GL_LINE_STRIP);
  for(int i=0;i<10;i++){float t=i/9.0f,wave=std::sin(travelled*4.0f+i*2.31f)*.055f*(i%3?1.0f:-1.0f);Vec3 p=tail*(1.0f-t)+position*t;p.x+=side.x*wave;p.z+=side.z*wave;glVertex3f(p.x,p.y,p.z);}glEnd();
  glLineWidth(1.0f);glDisable(GL_BLEND);glEnable(GL_LIGHTING);glEnable(GL_TEXTURE_2D);glColor4f(1,1,1,1);
}
static ProjectileDirection projectile_direction(Vec3 position, Vec3 velocity, Vec3 viewer) {
  float dx=viewer.x-position.x,dz=viewer.z-position.z,length=std::hypot(dx,dz);if(length<.001f)return ProjectileToward;
  dx/=length;dz/=length;float toward=velocity.x*dx+velocity.z*dz,right=velocity.x*dz-velocity.z*dx;
  const float sector=3.14159265f*.25f;int direction=(int)std::floor(std::atan2(right,toward)/sector+.5f);direction=(direction%ProjectileDirectionCount+ProjectileDirectionCount)%ProjectileDirectionCount;
  return (ProjectileDirection)direction;
}
static const EnemyFrame &clip_frame(const EnemyClip &clip, float time, int *frame_index=nullptr) {
  float total=0; for(int i=0;i<clip.count;i++)total+=clip.frames[i].duration;
  float cursor=clip.loop&&total>0?std::fmod(time,total):std::fmin(time,total-.0001f);
  for(int i=0;i<clip.count;i++){if(cursor<clip.frames[i].duration){if(frame_index)*frame_index=i;return clip.frames[i];}cursor-=clip.frames[i].duration;}
  if(frame_index)*frame_index=clip.count-1;
  return clip.frames[clip.count-1];
}
static float clip_duration(const EnemyClip &clip) { float total=0;for(int i=0;i<clip.count;i++)total+=clip.frames[i].duration;return total; }
static EnemyDirection enemy_direction(const Enemy &enemy, Vec3 player) {
  const float pi=3.14159265f, step=pi*.25f; float view=std::atan2(player.x-enemy.pos.x,player.z-enemy.pos.z), relative=view-enemy.facing;
  while(relative<0)relative+=2*pi;
  while(relative>=2*pi)relative-=2*pi;
  return (EnemyDirection)(((int)std::floor((relative+step*.5f)/step))&7);
}
static const EnemyClip &enemy_clip(const Enemy &enemy) {
  if(enemy.state==EnemyPain)return PAIN_CLIP;
  if(enemy.state==EnemyAttack)return ATTACK_CLIP;
  if(enemy.state==EnemyDeath)return DEATH_CLIP;
  if(enemy.state==EnemyGib)return GIB_CLIP;
  if(enemy.state==EnemyCorpse)return enemy.gibbed?GIB_CORPSE_CLIP:DEATH_CORPSE_CLIP;
  return WALK_CLIP;
}
static void enemy_model(const GLuint directional_frames[4][EnemyDirectionCount][4], const GLuint combat_frames[4][4][4], const Enemy &enemy, int variant, Vec3 player) {
  const EnemyDefinition &def=ENEMY_DEFS[variant]; const EnemyClip &clip=enemy_clip(enemy); const EnemyFrame &frame=clip_frame(clip,enemy.state==EnemyWalk?enemy.walk_time:enemy.state_time);
  EnemyDirection direction=enemy_direction(enemy,player);GLuint tex=frame.atlas==DirectionalAtlas?directional_frames[variant][direction][frame.row]:combat_frames[variant][frame.row][frame.column];if(!tex)return;
  float u0=0,u1=1,v0=0,v1=1;if(frame.mirror)std::swap(u0,u1);
  float player_angle=std::atan2(player.x-enemy.pos.x,player.z-enemy.pos.z),right_x=std::cos(player_angle),right_z=-std::sin(player_angle);
  float canvas_width=def.world_height*1.5f,cx=enemy.pos.x+right_x*(.5f-frame.pivot_x)*canvas_width,cz=enemy.pos.z+right_z*(.5f-frame.pivot_x)*canvas_width,bottom=enemy.pos.y+def.baseline-frame.pivot_y*def.world_height,hw=canvas_width*.5f;
  glEnable(GL_TEXTURE_2D);glBindTexture(GL_TEXTURE_2D,tex);glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);glEnable(GL_ALPHA_TEST);glAlphaFunc(GL_GREATER,.08f);glDisable(GL_LIGHTING);glColor4f(1,1,1,1);
  sprite_plane(u0,u1,v0,v1,cx,cz,bottom,def.world_height,hw,right_x,right_z,1);
  if(enemy.alive){float bar_y=enemy.pos.y+def.baseline+def.world_height+.08f,bar_hw=def.world_width*.5f;glDisable(GL_TEXTURE_2D);glColor4f(.08f,.01f,.005f,1);glBegin(GL_QUADS);glVertex3f(cx-bar_hw,bar_y,cz);glVertex3f(cx+bar_hw,bar_y,cz);glVertex3f(cx+bar_hw,bar_y+.07f,cz);glVertex3f(cx-bar_hw,bar_y+.07f,cz);glColor4f(1,.22f,.04f,1);float fill=def.world_width*std::fmax(0.0f,enemy.hp/enemy.max_hp);glVertex3f(cx-bar_hw,bar_y+.001f,cz);glVertex3f(cx-bar_hw+fill,bar_y+.001f,cz);glVertex3f(cx-bar_hw+fill,bar_y+.069f,cz);glVertex3f(cx-bar_hw,bar_y+.069f,cz);glEnd();}
  glColor4f(1,1,1,1);glDisable(GL_ALPHA_TEST);glEnable(GL_LIGHTING);glDisable(GL_BLEND);
}
static void draw_weapon_model(const GLuint weapon_frames[3][4], int weapon, float anim, bool hit) {
  int animation_frame=0;if(anim>0){float progress=1.0f-anim/WEAPON_ANIM_DURATIONS[weapon];animation_frame=std::min(WEAPON_FRAME_COUNTS[weapon]-1,std::max(0,(int)(progress*WEAPON_FRAME_COUNTS[weapon])));}int frame=WEAPON_SOURCE_FRAMES[weapon][animation_frame];GLuint tex=weapon_frames[weapon][frame];if(!tex){draw_weapon(weapon,anim>0,hit);return;}
  glMatrixMode(GL_PROJECTION); glPushMatrix(); glLoadIdentity(); glOrtho(-1,1,-1,1,-1,1); glMatrixMode(GL_MODELVIEW); glPushMatrix(); glLoadIdentity(); glDisable(GL_DEPTH_TEST); glDisable(GL_LIGHTING); glEnable(GL_BLEND); glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); glEnable(GL_TEXTURE_2D); glBindTexture(GL_TEXTURE_2D,tex);const float widths[]={.54f,.72f,.9f},heights[]={.58f,.7f,.82f};float half=widths[weapon]*.5f,y_bottom=WEAPON_SCREEN_BOTTOM,y_top=y_bottom+heights[weapon];glColor4f(1,1,1,1);glBegin(GL_QUADS);glTexCoord2f(0,1);glVertex2f(-half,y_bottom);glTexCoord2f(1,1);glVertex2f(half,y_bottom);glTexCoord2f(1,0);glVertex2f(half,y_top);glTexCoord2f(0,0);glVertex2f(-half,y_top);glEnd();
  glDisable(GL_BLEND); glEnable(GL_TEXTURE_2D); if(hit)glColor3f(.3f,1,.35f);else glColor3f(1,.78f,.45f); glBegin(GL_LINES);glVertex2f(-.035f,0);glVertex2f(.035f,0);glVertex2f(0,-.035f);glVertex2f(0,.035f);glEnd(); glEnable(GL_LIGHTING); glEnable(GL_DEPTH_TEST); glPopMatrix(); glMatrixMode(GL_PROJECTION); glPopMatrix(); glMatrixMode(GL_MODELVIEW);
}

static void draw_first_person_launch(GLuint tex, const FirstPersonLaunch &launch) {
  if(!launch.active||!tex||launch.life<=0)return;
  float progress=1.0f-launch.life/launch.duration;
  // The arc overlay is deliberately shallow. It leaves the cannon muzzle and
  // travels across the lower sight line toward the crosshair, rather than
  // climbing to the top of the screen as though the player fired upward.
  const float widths[]={.28f,.52f,.86f},heights[]={.78f,1.03f,.42f};
  float half=widths[launch.weapon]*(.72f+progress*.28f)*.5f;
  float bottom=launch.weapon==2?-.28f+progress*.02f:-.93f+progress*.15f,top=bottom+heights[launch.weapon]*(.84f+progress*.16f);
  glMatrixMode(GL_PROJECTION);glPushMatrix();glLoadIdentity();glOrtho(-1,1,-1,1,-1,1);glMatrixMode(GL_MODELVIEW);glPushMatrix();glLoadIdentity();
  glDisable(GL_DEPTH_TEST);glDepthMask(GL_FALSE);glDisable(GL_LIGHTING);glEnable(GL_TEXTURE_2D);glBindTexture(GL_TEXTURE_2D,tex);glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE);glEnable(GL_ALPHA_TEST);glAlphaFunc(GL_GREATER,.02f);glColor4f(1,1,1,std::fmin(1.0f,launch.life/.06f));
  glBegin(GL_QUADS);glTexCoord2f(0,1);glVertex2f(-half,bottom);glTexCoord2f(1,1);glVertex2f(half,bottom);glTexCoord2f(1,0);glVertex2f(half,top);glTexCoord2f(0,0);glVertex2f(-half,top);glEnd();
  glColor4f(1,1,1,1);glDisable(GL_ALPHA_TEST);glDisable(GL_BLEND);glDepthMask(GL_TRUE);glEnable(GL_LIGHTING);glEnable(GL_DEPTH_TEST);glPopMatrix();glMatrixMode(GL_PROJECTION);glPopMatrix();glMatrixMode(GL_MODELVIEW);
}
static void draw_arc_muzzle_flash(GLuint tex, float life) {
  if(!tex||life<=0)return;
  float alpha=std::fmin(1.0f,life/.035f),half=.17f*(1.0f+(0.10f-life)*1.5f),bottom=-.47f,top=bottom+half*2;
  glMatrixMode(GL_PROJECTION);glPushMatrix();glLoadIdentity();glOrtho(-1,1,-1,1,-1,1);glMatrixMode(GL_MODELVIEW);glPushMatrix();glLoadIdentity();
  glDisable(GL_DEPTH_TEST);glDepthMask(GL_FALSE);glDisable(GL_LIGHTING);glEnable(GL_TEXTURE_2D);glBindTexture(GL_TEXTURE_2D,tex);glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE);glEnable(GL_ALPHA_TEST);glAlphaFunc(GL_GREATER,.02f);glColor4f(1,1,1,alpha);
  glBegin(GL_QUADS);glTexCoord2f(0,1);glVertex2f(-half,bottom);glTexCoord2f(1,1);glVertex2f(half,bottom);glTexCoord2f(1,0);glVertex2f(half,top);glTexCoord2f(0,0);glVertex2f(-half,top);glEnd();
  glColor4f(1,1,1,1);glDisable(GL_ALPHA_TEST);glDisable(GL_BLEND);glDepthMask(GL_TRUE);glEnable(GL_LIGHTING);glEnable(GL_DEPTH_TEST);glPopMatrix();glMatrixMode(GL_PROJECTION);glPopMatrix();glMatrixMode(GL_MODELVIEW);
}

static void quad(GLuint tex, Vec3 a, Vec3 b, Vec3 c, Vec3 d, float repeat_u, float repeat_v, Vec3 normal, float light) {
  glBindTexture(GL_TEXTURE_2D, tex); glColor3f(light, light, light); glNormal3f(normal.x,normal.y,normal.z); glBegin(GL_QUADS);
  glTexCoord2f(0,0); glVertex3f(a.x,a.y,a.z); glTexCoord2f(repeat_u,0); glVertex3f(b.x,b.y,b.z); glTexCoord2f(repeat_u,repeat_v); glVertex3f(c.x,c.y,c.z); glTexCoord2f(0,repeat_v); glVertex3f(d.x,d.y,d.z); glEnd();
}

static bool blocked(float x, float z) {
  if (x < -ARENA_HALF_WIDTH+.65f || x > ARENA_HALF_WIDTH-.65f || z < -ARENA_HALF_DEPTH+.65f || z > ARENA_HALF_DEPTH-.65f) return true;
  for (const auto &p : PILLARS) if (std::hypot(x-p[0],z-p[1]) < .75f) return true;
  for(const auto &wall:ROOM_WALLS)if(x>wall.x0-.42f&&x<wall.x1+.42f&&z>wall.z0-.42f&&z<wall.z1+.42f)return true;
  return false;
}

static float room_hit_distance(Vec3 p, Vec3 ray) {
  float nearest=100.0f;
  if(ray.x>0) nearest=std::fmin(nearest,(ARENA_HALF_WIDTH-p.x)/ray.x); else if(ray.x<0) nearest=std::fmin(nearest,(-ARENA_HALF_WIDTH-p.x)/ray.x);
  if(ray.z>0) nearest=std::fmin(nearest,(ARENA_HALF_DEPTH-p.z)/ray.z); else if(ray.z<0) nearest=std::fmin(nearest,(-ARENA_HALF_DEPTH-p.z)/ray.z);
  if(ray.y>0) nearest=std::fmin(nearest,(ARENA_CEILING-p.y)/ray.y); else if(ray.y<0) nearest=std::fmin(nearest,(0.0f-p.y)/ray.y);
  return nearest>0?nearest:100.0f;
}

static Vec3 enemy_fire_origin(const Enemy &enemy) {
  const EnemyDefinition &def=ENEMY_DEFS[enemy.type];
  return {enemy.pos.x,enemy.pos.y+def.baseline+def.world_height*(enemy.type==1?.62f:.56f),enemy.pos.z};
}
static bool ray_hits_pillar(Vec3 origin, Vec3 ray, float maximum_distance) {
  float horizontal_length=std::hypot(ray.x,ray.z);if(horizontal_length<.0001f)return false;
  for(const auto &pillar_pos:PILLARS){float dx=pillar_pos[0]-origin.x,dz=pillar_pos[1]-origin.z,t=(dx*ray.x+dz*ray.z)/(horizontal_length*horizontal_length);if(t<=0||t>=maximum_distance)continue;float near_x=origin.x+ray.x*t,near_z=origin.z+ray.z*t;if(std::hypot(near_x-pillar_pos[0],near_z-pillar_pos[1])<.63f&&origin.y+ray.y*t>=0&&origin.y+ray.y*t<=ARENA_CEILING-.45f)return true;}
  return false;
}
static bool ray_hits_arena_geometry(Vec3 origin, Vec3 ray, float maximum_distance) {
  // Sampling is deliberate: projectile and sight paths use the same collision
  // volumes as player movement, including every interior room divider.
  for(float distance=.12f;distance<maximum_distance;distance+=.12f)
    if(blocked(origin.x+ray.x*distance,origin.z+ray.z*distance))return true;
  return false;
}
static bool enemy_has_clear_player_shot(const Enemy enemies[], int count, int shooter, Vec3 player) {
  if(shooter<0||shooter>=count||!enemies[shooter].alive)return false;
  Vec3 origin=enemy_fire_origin(enemies[shooter]),target={player.x,player.y-.32f,player.z},delta={target.x-origin.x,target.y-origin.y,target.z-origin.z};float distance=std::sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z);if(distance<.001f)return true;Vec3 ray=delta*(1.0f/distance);
  if(room_hit_distance(origin,ray)<distance-.08f||ray_hits_arena_geometry(origin,ray,distance))return false;
  for(int i=0;i<count;i++){if(i==shooter||!enemies[i].alive)continue;float hit_distance=0;if(ray_enemy_hit(origin,ray,enemies[i],hit_distance)&&hit_distance<distance-.18f)return false;}
  return true;
}

static void pillar(GLuint wall, float x, float z) {
  const float r=.57f, y0=0, y1=ARENA_CEILING-.45f; quad(wall,{x-r,y0,z-r},{x+r,y0,z-r},{x+r,y1,z-r},{x-r,y1,z-r},1,4,{0,0,-1},.8f); quad(wall,{x+r,y0,z-r},{x+r,y0,z+r},{x+r,y1,z+r},{x+r,y1,z-r},1,4,{1,0,0},.9f); quad(wall,{x+r,y0,z+r},{x-r,y0,z+r},{x-r,y1,z+r},{x+r,y1,z+r},1,4,{0,0,1},.7f); quad(wall,{x-r,y0,z+r},{x-r,y0,z-r},{x-r,y1,z-r},{x-r,y1,z+r},1,4,{-1,0,0},.65f);
}
static void wall_block(GLuint wall, const WallBlock &block) {
  float x0=block.x0,x1=block.x1,z0=block.z0,z1=block.z1,y=ARENA_CEILING;
  float width=x1-x0,depth=z1-z0;
  quad(wall,{x0,0,z0},{x1,0,z0},{x1,y,z0},{x0,y,z0},width,4,{0,0,1},.78f);
  quad(wall,{x1,0,z1},{x0,0,z1},{x0,y,z1},{x1,y,z1},width,4,{0,0,-1},.72f);
  quad(wall,{x0,0,z1},{x0,0,z0},{x0,y,z0},{x0,y,z1},depth,4,{1,0,0},.68f);
  quad(wall,{x1,0,z0},{x1,0,z1},{x1,y,z1},{x1,y,z0},depth,4,{-1,0,0},.86f);
  quad(wall,{x0,y,z0},{x1,y,z0},{x1,y,z1},{x0,y,z1},width,depth,{0,-1,0},.55f);
}

static void draw_weapon(int weapon, bool muzzle, bool hit) {
  glMatrixMode(GL_PROJECTION); glPushMatrix(); glLoadIdentity(); glOrtho(-1,1,-1,1,-1,1); glMatrixMode(GL_MODELVIEW); glPushMatrix(); glLoadIdentity(); glDisable(GL_DEPTH_TEST); glDisable(GL_LIGHTING); glDisable(GL_TEXTURE_2D);
  float kick=muzzle?(weapon==1?.09f:weapon==2?.06f:.045f):0; glTranslatef(0,-kick,0); float tint[3] = {weapon==0?.9f:weapon==1?.35f:.08f, weapon==2?.55f:.12f, weapon==2?.95f:.04f}; glColor3f(tint[0],tint[1],tint[2]);
  if(weapon==0){glBegin(GL_QUADS);glVertex2f(-.16f,-1);glVertex2f(.16f,-1);glVertex2f(.12f,-.3f);glVertex2f(-.12f,-.3f);glEnd();glColor3f(.08f,.06f,.05f);glBegin(GL_QUADS);glVertex2f(-.24f,-.35f);glVertex2f(.24f,-.35f);glVertex2f(.16f,.02f);glVertex2f(-.16f,.02f);glEnd();}
  else if(weapon==1){glBegin(GL_QUADS);glVertex2f(-.34f,-1);glVertex2f(.34f,-1);glVertex2f(.27f,-.2f);glVertex2f(-.27f,-.2f);glEnd();glColor3f(.12f,.1f,.09f);glBegin(GL_QUADS);glVertex2f(-.42f,-.24f);glVertex2f(.42f,-.24f);glVertex2f(.28f,.08f);glVertex2f(-.28f,.08f);glEnd();}
  else {glBegin(GL_QUADS);glVertex2f(-.22f,-1);glVertex2f(.22f,-1);glVertex2f(.16f,-.15f);glVertex2f(-.16f,-.15f);glEnd();glColor3f(.04f,.14f,.18f);glBegin(GL_QUADS);glVertex2f(-.3f,-.2f);glVertex2f(.3f,-.2f);glVertex2f(.2f,.28f);glVertex2f(-.2f,.28f);glEnd();}
  if(muzzle){glColor3f(1,.72f,.12f);glBegin(GL_TRIANGLES);glVertex2f(-.12f,.2f);glVertex2f(.12f,.2f);glVertex2f(0,.72f);glEnd();glColor3f(1,.95f,.65f);glBegin(GL_TRIANGLES);glVertex2f(-.045f,.24f);glVertex2f(.045f,.24f);glVertex2f(0,.57f);glEnd();}
  if(hit) glColor3f(.3f,1,.35f); else glColor3f(1,.78f,.45f); glBegin(GL_LINES); glVertex2f(-.035f,0); glVertex2f(.035f,0); glVertex2f(0,-.035f); glVertex2f(0,.035f); glEnd(); glEnable(GL_TEXTURE_2D); glEnable(GL_LIGHTING); glEnable(GL_DEPTH_TEST); glPopMatrix(); glMatrixMode(GL_PROJECTION); glPopMatrix(); glMatrixMode(GL_MODELVIEW);
}

static void room(GLuint wall, GLuint floor, GLuint ceiling) {
  glEnable(GL_TEXTURE_2D); glEnable(GL_LIGHTING); glEnable(GL_LIGHT0); glEnable(GL_COLOR_MATERIAL); glColorMaterial(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE);
  quad(floor,{-ARENA_HALF_WIDTH,0,-ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,0,-ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,0,ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,0,ARENA_HALF_DEPTH},36,30,{0,1,0},1.0f);
  quad(ceiling,{-ARENA_HALF_WIDTH,ARENA_CEILING,-ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,ARENA_CEILING,ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,ARENA_CEILING,ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,ARENA_CEILING,-ARENA_HALF_DEPTH},36,30,{0,-1,0},.55f);
  quad(wall,{-ARENA_HALF_WIDTH,0,ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,0,ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,ARENA_CEILING,ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,ARENA_CEILING,ARENA_HALF_DEPTH},36,4,{0,0,-1},.75f);
  quad(wall,{ARENA_HALF_WIDTH,0,ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,0,-ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,ARENA_CEILING,-ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,ARENA_CEILING,ARENA_HALF_DEPTH},30,4,{-1,0,0},.85f);
  quad(wall,{ARENA_HALF_WIDTH,0,-ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,0,-ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,ARENA_CEILING,-ARENA_HALF_DEPTH},{ARENA_HALF_WIDTH,ARENA_CEILING,-ARENA_HALF_DEPTH},36,4,{0,0,1},.92f);
  quad(wall,{-ARENA_HALF_WIDTH,0,-ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,0,ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,ARENA_CEILING,ARENA_HALF_DEPTH},{-ARENA_HALF_WIDTH,ARENA_CEILING,-ARENA_HALF_DEPTH},30,4,{1,0,0},.62f);
  for(const auto &pillar_pos:PILLARS)pillar(wall,pillar_pos[0],pillar_pos[1]);
  for(const auto &wall_block_data:ROOM_WALLS)wall_block(wall,wall_block_data);
}

static bool enemy_is_ranged(const Enemy &enemy) { return enemy.type==1||enemy.type==2; }
static float enemy_notice_distance(const Enemy &enemy) { return enemy_is_ranged(enemy)?RANGED_NOTICE_DISTANCE:MELEE_NOTICE_DISTANCE; }
static float enemy_attack_distance(const Enemy &enemy) { return enemy_is_ranged(enemy)?RANGED_ATTACK_DISTANCE:MELEE_ATTACK_DISTANCE; }
static bool enemy_notices_player(const Enemy &enemy, Vec3 player) { return std::hypot(player.x-enemy.pos.x,player.z-enemy.pos.z)<=enemy_notice_distance(enemy); }
static Enemy make_enemy(Vec3 pos, float hp, int type) { return {pos,hp,hp,type*1.31f,0,0,0,.75f+type*.23f,type*1.31f,true,false,false,EnemyWalk,type,-1}; }
static void damage_enemy(Enemy &enemy, float damage, bool force_gib, int attacker=-1) {
  if(!enemy.alive)return;
  enemy.hp-=damage;enemy.state_time=0;enemy.event_fired=false;enemy.target_enemy=attacker;
  if(enemy.hp<=0){enemy.hp=0;enemy.alive=false;enemy.gibbed=force_gib;enemy.state=force_gib?EnemyGib:EnemyDeath;}
  else enemy.state=EnemyPain;
}
static bool damage_enemy_from_enemy(Enemy enemies[],int count,int attacker,int victim,float damage){if(attacker<0||attacker>=count||victim<0||victim>=count||!enemies[victim].alive||!enemies_can_infight(enemies[attacker],enemies[victim]))return false;damage_enemy(enemies[victim],damage,false,attacker);return true;}

static int self_test() {
  for(const auto &def:ENEMY_DEFS)if(def.world_height<=PLAYER_HEIGHT)return std::fprintf(stderr,"enemy is not taller than player\n"),1;
  if(std::fabs(WEAPON_COOLDOWNS[0]-.50f)>.0001f||WEAPON_SCREEN_BOTTOM!=-1.0f||PLAYER_SPEED<=1.9f||SPRINT_MULTIPLIER!=2.0f||std::fabs(player_move_speed(true)-PLAYER_SPEED*2.0f)>.0001f||ENEMY_SPEED<=.42f||RANGED_ATTACK_DISTANCE<=5.2f||RANGED_NOTICE_DISTANCE<=RANGED_ATTACK_DISTANCE)return std::fprintf(stderr,"speed or enemy distance constants are wrong\n"),1;
  if(ARENA_HALF_WIDTH<36.0f||ARENA_HALF_DEPTH<30.0f||ARENA_CEILING<5.0f||ENEMY_COUNT<14)return std::fprintf(stderr,"multi-room arena is too small\n"),1;
  if(!blocked(8,9.5f)||blocked(0,8.0f)||blocked(0,11.0f))return std::fprintf(stderr,"north room doorway collision is wrong\n"),1;
  Enemy fighters[]={make_enemy({0,0,0},4,0),make_enemy({0,0,0},4,1),make_enemy({0,0,0},4,0)};if(!damage_enemy_from_enemy(fighters,3,0,1,1)||fighters[1].hp!=3||fighters[1].target_enemy!=0)return std::fprintf(stderr,"cross-type retaliation failed\n"),1;if(damage_enemy_from_enemy(fighters,3,0,2,1)||fighters[2].hp!=4||fighters[2].target_enemy!=-1)return std::fprintf(stderr,"same-type immunity failed\n"),1;
  Enemy sight_test[]={make_enemy({0,0,0},4,1),make_enemy({0,0,2},4,0)};if(enemy_has_clear_player_shot(sight_test,2,0,{0,PLAYER_HEIGHT,5}))return std::fprintf(stderr,"enemy fired through a fellow enemy\n"),1;sight_test[1].pos={3,0,2};if(!enemy_has_clear_player_shot(sight_test,2,0,{0,PLAYER_HEIGHT,5}))return std::fprintf(stderr,"enemy lost a clear player shot\n"),1;
  Vec3 pillar_origin={PILLARS[0][0],1.2f,PILLARS[0][1]-4.0f};if(!ray_hits_pillar(pillar_origin,{0,0,1},8.0f))return std::fprintf(stderr,"pillar line-of-sight collision failed\n"),1;
  Enemy awareness_test=make_enemy({0,0,0},4,1);if(!enemy_notices_player(awareness_test,{0,PLAYER_HEIGHT,RANGED_ATTACK_DISTANCE})||enemy_notices_player(awareness_test,{0,PLAYER_HEIGHT,RANGED_NOTICE_DISTANCE+.1f}))return std::fprintf(stderr,"ranged awareness distance failed\n"),1;
  Enemy collision_test=make_enemy({0,0,0},4,0);collision_test.walk_time=.28f;EnemyCollision walk_collision=enemy_collision(collision_test);collision_test.state=EnemyAttack;collision_test.state_time=.30f;EnemyCollision attack_collision=enemy_collision(collision_test);collision_test.state=EnemyDeath;collision_test.state_time=.31f;EnemyCollision death_collision=enemy_collision(collision_test);if(attack_collision.width<=walk_collision.width||attack_collision.height>=walk_collision.height||death_collision.height>=walk_collision.height)return std::fprintf(stderr,"frame-aware enemy collision profiles failed\n"),1;
  if(projectile_direction({0,0,0},{0,0,1},{0,0,2})!=ProjectileToward||projectile_direction({0,0,0},{1,0,1},{0,0,2})!=ProjectileTowardRight||projectile_direction({0,0,0},{1,0,0},{0,0,2})!=ProjectileRight||projectile_direction({0,0,0},{1,0,-1},{0,0,2})!=ProjectileAwayRight||projectile_direction({0,0,0},{0,0,-1},{0,0,2})!=ProjectileAway||projectile_direction({0,0,0},{-1,0,-1},{0,0,2})!=ProjectileAwayLeft||projectile_direction({0,0,0},{-1,0,0},{0,0,2})!=ProjectileLeft||projectile_direction({0,0,0},{-1,0,1},{0,0,2})!=ProjectileTowardLeft)return std::fprintf(stderr,"projectile direction selection failed\n"),1;
  char path[128];for(int weapon=0;weapon<3;weapon++)for(int frame=0;frame<4;frame++){std::snprintf(path,sizeof(path),"assets/weapons/weapon-%d-frame-%d.bmp",weapon,frame);SDL_Surface *surface=SDL_LoadBMP(path);if(!surface)return std::fprintf(stderr,"%s did not load: %s\n",path,SDL_GetError()),1;SDL_Surface *rgba=SDL_ConvertSurfaceFormat(surface,SDL_PIXELFORMAT_ABGR8888,0);SDL_FreeSurface(surface);Uint8 minimum_alpha=255;for(int y=0;y<rgba->h;y++){Uint8 *pixels=(Uint8*)rgba->pixels+y*rgba->pitch;for(int x=0;x<rgba->w;x++)minimum_alpha=std::min(minimum_alpha,pixels[x*4+3]);}SDL_FreeSurface(rgba);if(minimum_alpha!=0)return std::fprintf(stderr,"%s has an opaque background\n",path),1;}
  const char *projectile_names[]={"player-pistol","player-shotgun","player-arc","cultist-fire","wraith-plasma"},*projectile_directions[]={"toward","toward-right","right","away-right","away","away-left","left","toward-left"};for(const char *name:projectile_names)for(const char *direction:projectile_directions){std::snprintf(path,sizeof(path),"assets/projectiles/%s-dir-%s.bmp",name,direction);SDL_Surface *surface=SDL_LoadBMP(path);if(!surface||surface->w!=256||surface->h!=128){if(surface)SDL_FreeSurface(surface);return std::fprintf(stderr,"%s is not a 256x128 directional projectile sprite\n",path),1;}SDL_Surface *rgba=SDL_ConvertSurfaceFormat(surface,SDL_PIXELFORMAT_ABGR8888,0);SDL_FreeSurface(surface);Uint8 minimum_alpha=255;for(int y=0;y<rgba->h;y++){Uint8 *pixels=(Uint8*)rgba->pixels+y*rgba->pitch;for(int x=0;x<rgba->w;x++)minimum_alpha=std::min(minimum_alpha,pixels[x*4+3]);}SDL_FreeSurface(rgba);if(minimum_alpha!=0)return std::fprintf(stderr,"%s has an opaque background\n",path),1;}
  const char *launch_names[]={"player-pistol","player-shotgun","player-arc-perspective-bolt-v2","player-arc-muzzle-flash"};for(const char *name:launch_names){std::snprintf(path,sizeof(path),"assets/projectiles/first-person-%s.bmp",name);SDL_Surface *surface=SDL_LoadBMP(path);if(!surface||surface->w!=512||surface->h!=512){if(surface)SDL_FreeSurface(surface);return std::fprintf(stderr,"%s is not a 512x512 first-person launch asset\n",path),1;}SDL_Surface *rgba=SDL_ConvertSurfaceFormat(surface,SDL_PIXELFORMAT_ABGR8888,0);SDL_FreeSurface(surface);Uint8 minimum_alpha=255;for(int y=0;y<rgba->h;y++){Uint8 *pixels=(Uint8*)rgba->pixels+y*rgba->pitch;for(int x=0;x<rgba->w;x++)minimum_alpha=std::min(minimum_alpha,pixels[x*4+3]);}SDL_FreeSurface(rgba);if(minimum_alpha!=0)return std::fprintf(stderr,"%s has an opaque background\n",path),1;}
  SDL_AudioSpec music_spec={};Sound music=load_sound("assets/music/furnace-descent-loop.wav",&music_spec);if(!music.data||music_spec.freq!=44100||music_spec.channels!=1){if(music.data)SDL_FreeWAV(music.data);return std::fprintf(stderr,"music loop did not load as 44.1kHz mono PCM\n"),1;}SDL_FreeWAV(music.data);
  for(int weapon_index=0;weapon_index<3;weapon_index++)for(int variant=0;variant<WEAPON_SOUND_VARIANTS;variant++){std::snprintf(path,sizeof(path),"assets/sounds/%s-%d.wav",WEAPON_SOUND_NAMES[weapon_index],variant);SDL_AudioSpec weapon_spec={};Sound weapon_sound=load_sound(path,&weapon_spec);if(!weapon_sound.data||weapon_spec.freq!=44100||weapon_spec.channels!=1){if(weapon_sound.data)SDL_FreeWAV(weapon_sound.data);return std::fprintf(stderr,"%s did not load as a 44.1kHz mono weapon variation\n",path),1;}SDL_FreeWAV(weapon_sound.data);}
  SDL_AudioSpec impact_spec={};Sound projectile_impact=load_sound("assets/sounds/projectile-impact.wav",&impact_spec);if(!projectile_impact.data||impact_spec.freq!=44100||impact_spec.channels!=1){if(projectile_impact.data)SDL_FreeWAV(projectile_impact.data);return std::fprintf(stderr,"projectile impact did not load as 44.1kHz mono PCM\n"),1;}SDL_FreeWAV(projectile_impact.data);
  for(int type=0;type<4;type++){std::snprintf(path,sizeof(path),"assets/sounds/enemy-hit-%d.wav",type);SDL_AudioSpec hit_spec={};Sound enemy_hit=load_sound(path,&hit_spec);if(!enemy_hit.data||hit_spec.freq!=44100||hit_spec.channels!=1){if(enemy_hit.data)SDL_FreeWAV(enemy_hit.data);return std::fprintf(stderr,"%s did not load as 44.1kHz mono PCM\n",path),1;}SDL_FreeWAV(enemy_hit.data);}
  Enemy fresh[]={make_enemy(ENEMY_SPAWNS[0],4,0),make_enemy(ENEMY_SPAWNS[1],4,1)};if(fresh[0].target_enemy!=-1||fresh[1].target_enemy!=-1)return std::fprintf(stderr,"enemies begin infighting without friendly fire\n"),1;
  std::puts("verified multi-room arena, constant-scale projectiles, one-piece arc bolt and trail, recorded hit sounds, and transparent sprite assets");return 0;
}

int main(int argc,char **argv) {
  if(argc>1&&!std::strcmp(argv[1],"--self-test"))return self_test();
  bool recording=argc>1&&!std::strcmp(argv[1],"--record");
  if (SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO) != 0) return std::fprintf(stderr,"SDL: %s\n",SDL_GetError()),1;
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,2); SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,1); SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,1);
  SDL_Window *window=SDL_CreateWindow("Eye Sore — 3D Engine Test Room",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,W,H,SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);
  if (!window) return std::fprintf(stderr,"Window: %s\n",SDL_GetError()),1;
  SDL_GLContext context=SDL_GL_CreateContext(window); SDL_GL_SetSwapInterval(1); SDL_SetWindowGrab(window,SDL_TRUE); SDL_SetRelativeMouseMode(SDL_TRUE);
  glEnable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE); glShadeModel(GL_SMOOTH); glClearColor(.015f,.003f,.006f,1);
  GLuint wall=texture_from_bmp("assets/infernal-wall.bmp"),floor=texture_from_bmp("assets/infernal-floor.bmp"),ceiling=texture_from_bmp("assets/infernal-ceiling.bmp"),enemy_directions[4][EnemyDirectionCount][4]={},enemy_combat[4][4][4]={},weapon_frames[3][4]={},projectile_sprites[ProjectileSpriteCount][ProjectileDirectionCount]={},first_person_launches[3]={},arc_muzzle_flash=0;
  char enemy_path[160];for(int type=0;type<4;type++)for(int direction=0;direction<EnemyDirectionCount;direction++)for(int pose=0;pose<4;pose++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/enemies/directional/enemy-%d-dir-%d-walk-%d.bmp",type,direction,pose);enemy_directions[type][direction][pose]=texture_from_bmp(enemy_path,true);}
  const char *combat_states[]={"pain","attack","death","gib"};for(int type=0;type<4;type++)for(int state=0;state<4;state++)for(int frame=0;frame<4;frame++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/enemies/combat/enemy-%d-%s-%d.bmp",type,combat_states[state],frame);enemy_combat[type][state][frame]=texture_from_bmp(enemy_path,true);}
  for(int weapon_index=0;weapon_index<3;weapon_index++)for(int frame=0;frame<4;frame++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/weapons/weapon-%d-frame-%d.bmp",weapon_index,frame);weapon_frames[weapon_index][frame]=texture_from_bmp(enemy_path);}
  const char *projectile_names[]={"player-pistol","player-shotgun","player-arc","cultist-fire","wraith-plasma"},*projectile_directions[]={"toward","toward-right","right","away-right","away","away-left","left","toward-left"};for(int sprite=0;sprite<ProjectileSpriteCount;sprite++)for(int direction=0;direction<ProjectileDirectionCount;direction++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/projectiles/%s-dir-%s.bmp",projectile_names[sprite],projectile_directions[direction]);projectile_sprites[sprite][direction]=texture_from_bmp(enemy_path);}
  const char *launch_names[]={"player-pistol","player-shotgun","player-arc-perspective-bolt-v2"};for(int weapon_index=0;weapon_index<3;weapon_index++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/projectiles/first-person-%s.bmp",launch_names[weapon_index]);first_person_launches[weapon_index]=texture_from_bmp(enemy_path);}arc_muzzle_flash=texture_from_bmp("assets/projectiles/first-person-player-arc-muzzle-flash.bmp");
  SDL_AudioSpec sound_spec={},music_spec={};Sound weapon_sounds[3][WEAPON_SOUND_VARIANTS]={};for(int weapon_index=0;weapon_index<3;weapon_index++)for(int variant=0;variant<WEAPON_SOUND_VARIANTS;variant++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/sounds/%s-%d.wav",WEAPON_SOUND_NAMES[weapon_index],variant);weapon_sounds[weapon_index][variant]=load_sound(enemy_path,&sound_spec);}Sound impact_sound=load_sound("assets/sounds/projectile-impact.wav",&sound_spec),enemy_hit_sounds[4];for(int type=0;type<4;type++){std::snprintf(enemy_path,sizeof(enemy_path),"assets/sounds/enemy-hit-%d.wav",type);enemy_hit_sounds[type]=load_sound(enemy_path,&sound_spec);}Sound music=load_sound("assets/music/furnace-descent-loop.wav",&music_spec);SDL_AudioDeviceID audio_device=weapon_sounds[0][0].data?SDL_OpenAudioDevice(nullptr,0,&sound_spec,nullptr,0):0,music_device=music.data?SDL_OpenAudioDevice(nullptr,0,&music_spec,nullptr,0):0;if(audio_device)SDL_PauseAudioDevice(audio_device,0);else std::fprintf(stderr,"Effects audio device: %s\n",SDL_GetError());if(music_device){SDL_QueueAudio(music_device,music.data,music.length);SDL_PauseAudioDevice(music_device,0);}else std::fprintf(stderr,"Music audio device: %s\n",SDL_GetError());
  FILE *record_pipe=nullptr;std::vector<unsigned char> record_pixels;float record_accumulator=0;if(recording){record_pipe=popen("ffmpeg -y -loglevel error -f rawvideo -pixel_format rgb24 -video_size 1280x720 -framerate 15 -i - -vf vflip -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p build/eye-sore-playtest.mp4","w");if(record_pipe)record_pixels.resize(W*H*3);else std::fprintf(stderr,"Could not start playtest recorder\n");}
  Vec3 player={0,PLAYER_HEIGHT,0}; float health=100, yaw=0, pitch=0, fire_timer=0, flash=0, fire_anim=0, hit_feedback=0, arc_flash=0; int weapon=0, score=0,weapon_sound_cursor[3]={}; bool running=true,trigger_held=false; Enemy enemies[ENEMY_COUNT]; Projectile projectile={{0,0,0},{0,0,0},0,0,0,PlayerArcSprite,false}; VisualProjectile visual_projectiles[MAX_VISUAL_PROJECTILES]={}; EnemyProjectile enemy_projectiles[MAX_ENEMY_PROJECTILES]={}; Impact impact={{0,0,0},0,0}; FirstPersonLaunch launch={0,0,0,false}; Uint64 last=SDL_GetPerformanceCounter();
  auto setup_test_arena = [&](){for(int i=0;i<ENEMY_COUNT;i++)enemies[i]=make_enemy(ENEMY_SPAWNS[i],ENEMY_HEALTH[i],ENEMY_TYPES[i]);};
  setup_test_arena();
  auto reset_combat = [&](){ player={0,PLAYER_HEIGHT,0};health=100;yaw=0;pitch=0;fire_timer=0;flash=0;fire_anim=0;hit_feedback=0;arc_flash=0;score=0;weapon_sound_cursor[0]=weapon_sound_cursor[1]=weapon_sound_cursor[2]=0;trigger_held=false;projectile.active=false;launch.active=false;for(auto &shot:visual_projectiles)shot.active=false;for(auto &shot:enemy_projectiles)shot.active=false;impact.life=0;setup_test_arena(); };
  auto play_projectile_impact = [&](){if(audio_device&&impact_sound.data&&SDL_GetQueuedAudioSize(audio_device)<impact_sound.length*4)SDL_QueueAudio(audio_device,impact_sound.data,impact_sound.length);};
  auto play_enemy_hit = [&](int type){if(type>=0&&type<4&&audio_device&&enemy_hit_sounds[type].data&&SDL_GetQueuedAudioSize(audio_device)<enemy_hit_sounds[type].length*5)SDL_QueueAudio(audio_device,enemy_hit_sounds[type].data,enemy_hit_sounds[type].length);};
  auto launch_enemy_projectile = [&](const Enemy &enemy,int owner){
    EnemyProjectile *shot=nullptr;for(auto &candidate:enemy_projectiles)if(!candidate.active){shot=&candidate;break;}if(!shot)return;
    int type=enemy.type;Vec3 origin=enemy_fire_origin(enemy),target={player.x,player.y-.32f,player.z};if(enemy.target_enemy>=0&&enemy.target_enemy<ENEMY_COUNT&&enemies[enemy.target_enemy].alive){const Enemy &victim=enemies[enemy.target_enemy];const EnemyDefinition &victim_def=ENEMY_DEFS[victim.type];target={victim.pos.x,victim.pos.y+victim_def.baseline+victim_def.hitbox_height*.55f,victim.pos.z};}Vec3 delta={target.x-origin.x,target.y-origin.y,target.z-origin.z};float length=std::sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z);if(length<.001f)return;float speed=type==1?4.2f:5.0f;
    *shot={origin,delta*(speed/length),3.0f,type==1?.12f:.15f,type==1?9.0f:13.0f,type==1?1:2,type==1?CultistFireSprite:WraithPlasmaSprite,owner,true};
  };
  auto launch_visual_projectile = [&](int sprite,Vec3 origin,Vec3 direction,float speed,float damage,float radius){for(auto &shot:visual_projectiles)if(!shot.active){shot={origin,direction*speed,damage,radius,sprite,true};return;}};
  auto fire_player_weapon = [&](){
    if(fire_timer>0||health<=0)return;
    Vec3 aim={-std::sin(yaw)*std::cos(pitch),-std::sin(pitch),-std::cos(yaw)*std::cos(pitch)},origin={player.x+aim.x*.55f,player.y+aim.y*.55f,player.z+aim.z*.55f};
    if(weapon==2){projectile={origin,aim*20.0f,4.0f,.13f,0,PlayerArcSprite,true};arc_flash=.08f;}
    else launch_visual_projectile(weapon==0?PlayerPistolSprite:PlayerShotgunSprite,origin,aim,weapon==0?18.0f:14.0f,weapon==0?1.0f:2.5f,weapon==0?.09f:.18f);
    launch={weapon==0?.17f:weapon==1?.22f:.15f,weapon==0?.17f:weapon==1?.22f:.15f,weapon,true};
    fire_timer+=WEAPON_COOLDOWNS[weapon];flash=.12f;fire_anim=WEAPON_ANIM_DURATIONS[weapon];int variant=weapon_sound_cursor[weapon]++%WEAPON_SOUND_VARIANTS;Sound &sound=weapon_sounds[weapon][variant];if(audio_device&&sound.data){if(weapon==0)SDL_ClearQueuedAudio(audio_device);SDL_QueueAudio(audio_device,sound.data,sound.length);}
  };
  while(running){ Uint64 now=SDL_GetPerformanceCounter(); float dt=(float)((now-last)/(double)SDL_GetPerformanceFrequency()); last=now; if(dt>.05f)dt=.05f; SDL_Event event;
    while(SDL_PollEvent(&event)){if(event.type==SDL_QUIT)running=false;if(event.type==SDL_KEYDOWN&&event.key.keysym.sym==SDLK_ESCAPE)running=false;if(event.type==SDL_KEYDOWN&&event.key.keysym.sym==SDLK_r&&health<=0)reset_combat();if(event.type==SDL_KEYDOWN&&event.key.keysym.sym>=SDLK_1&&event.key.keysym.sym<=SDLK_3)weapon=event.key.keysym.sym-SDLK_1;if(event.type==SDL_MOUSEBUTTONDOWN&&event.button.button==SDL_BUTTON_LEFT)trigger_held=true;if(event.type==SDL_MOUSEBUTTONUP&&event.button.button==SDL_BUTTON_LEFT)trigger_held=false;if(event.type==SDL_MOUSEMOTION){yaw-=event.motion.xrel*.0026f;pitch+=event.motion.yrel*.0026f;if(pitch>1.2f)pitch=1.2f;if(pitch< -1.2f)pitch=-1.2f;}}
    if(music_device&&music.data&&SDL_GetQueuedAudioSize(music_device)<music.length/2)SDL_QueueAudio(music_device,music.data,music.length);
    const Uint8 *keys=SDL_GetKeyboardState(nullptr);if(trigger_held||keys[SDL_SCANCODE_SPACE])fire_player_weapon();
    fire_timer=std::fmax(0.0f,fire_timer-dt);flash-=dt;fire_anim-=dt;hit_feedback-=dt;arc_flash-=dt;impact.life-=dt;if(launch.active){launch.life-=dt;if(launch.life<=0)launch.active=false;}
    if(projectile.active){float step_length=std::sqrt(projectile.vel.x*projectile.vel.x+projectile.vel.y*projectile.vel.y+projectile.vel.z*projectile.vel.z)*dt;projectile.pos=projectile.pos+projectile.vel*dt;projectile.travelled+=step_length;if(blocked(projectile.pos.x,projectile.pos.z)||projectile.pos.y<=.08f||projectile.pos.y>=ARENA_CEILING-.08f){impact={projectile.pos,.28f,3};projectile.active=false;play_projectile_impact();}for(int i=0;i<ENEMY_COUNT;i++)if(projectile.active&&enemies[i].alive&&projectile_enemy_hit(projectile.pos,projectile.radius,enemies[i])){bool was_alive=enemies[i].alive;damage_enemy(enemies[i],projectile.damage,true,-1);play_enemy_hit(enemies[i].type);impact={projectile.pos,.28f,2};projectile.active=false;play_projectile_impact();hit_feedback=.12f;if(was_alive&&!enemies[i].alive)score+=100;}}
    for(auto &shot:visual_projectiles)if(shot.active){shot.pos=shot.pos+shot.vel*dt;if(blocked(shot.pos.x,shot.pos.z)||shot.pos.y<=.08f||shot.pos.y>=ARENA_CEILING-.08f){impact={shot.pos,.28f,3};shot.active=false;play_projectile_impact();continue;}for(int i=0;i<ENEMY_COUNT&&shot.active;i++)if(enemies[i].alive&&projectile_enemy_hit(shot.pos,shot.radius,enemies[i])){bool was_alive=enemies[i].alive;bool gib=shot.sprite==PlayerShotgunSprite&&enemies[i].hp<=shot.damage*.5f;damage_enemy(enemies[i],shot.damage,gib,-1);play_enemy_hit(enemies[i].type);impact={shot.pos,.28f,shot.sprite==PlayerShotgunSprite?1:0};shot.active=false;play_projectile_impact();hit_feedback=.12f;if(was_alive&&!enemies[i].alive)score+=100;}}
    for(auto &shot:enemy_projectiles)if(shot.active){
      shot.pos=shot.pos+shot.vel*dt;shot.life-=dt;
      if(shot.life<=0||blocked(shot.pos.x,shot.pos.z)||shot.pos.y<=.08f||shot.pos.y>=ARENA_CEILING-.08f){impact={shot.pos,.28f,shot.style==1?1:0};shot.active=false;continue;}
      for(int victim=0;victim<ENEMY_COUNT&&shot.active;victim++)if(victim!=shot.owner&&enemies[victim].alive&&projectile_enemy_hit(shot.pos,shot.radius,enemies[victim])){damage_enemy_from_enemy(enemies,ENEMY_COUNT,shot.owner,victim,shot.damage);impact={shot.pos,.28f,shot.style==1?1:0};shot.active=false;}
      float dx=shot.pos.x-player.x,dz=shot.pos.z-player.z,torso_y=player.y-.32f;if(shot.active&&std::hypot(dx,dz)<=.3f+shot.radius&&std::fabs(shot.pos.y-torso_y)<=.58f+shot.radius){health-=shot.damage;impact={shot.pos,.28f,shot.style==1?1:0};shot.active=false;flash=.08f;}
    }
    float keyboard_turn=(keys[SDL_SCANCODE_RIGHT]?1.0f:0.0f)-(keys[SDL_SCANCODE_LEFT]?1.0f:0.0f);yaw-=keyboard_turn*1.8f*dt;Vec3 forward={-std::sin(yaw),0,-std::cos(yaw)},right={std::cos(yaw),0,-std::sin(yaw)},movement={0,0,0};if(keys[SDL_SCANCODE_W])movement=movement+forward;if(keys[SDL_SCANCODE_S])movement=movement+forward*-1;if(keys[SDL_SCANCODE_D])movement=movement+right;if(keys[SDL_SCANCODE_A])movement=movement+right*-1;float length=std::hypot(movement.x,movement.z);if(length>.01f&&health>0){bool sprinting=keys[SDL_SCANCODE_LSHIFT]||keys[SDL_SCANCODE_RSHIFT];movement=movement*(player_move_speed(sprinting)*dt/length);if(!blocked(player.x+movement.x,player.z))player.x+=movement.x;if(!blocked(player.x,player.z+movement.z))player.z+=movement.z;}
    for(int enemy_index=0;enemy_index<ENEMY_COUNT;enemy_index++){Enemy &enemy=enemies[enemy_index];bool ranged=enemy_is_ranged(enemy);if(enemy.target_enemy<0||enemy.target_enemy>=ENEMY_COUNT||!enemies[enemy.target_enemy].alive||enemies[enemy.target_enemy].type==enemy.type)enemy.target_enemy=-1;bool targets_enemy=enemy.target_enemy>=0,notices_player=health>0&&enemy_notices_player(enemy,player);Vec3 target=targets_enemy?enemies[enemy.target_enemy].pos:player;bool player_shot_clear=!ranged||targets_enemy||enemy_has_clear_player_shot(enemies,ENEMY_COUNT,enemy_index,player);
      enemy.attack_cooldown=std::fmax(0.0f,enemy.attack_cooldown-dt);
      if(enemy.state==EnemyDeath||enemy.state==EnemyGib){enemy.state_time+=dt;const EnemyClip &clip=enemy.state==EnemyGib?GIB_CLIP:DEATH_CLIP;if(enemy.state_time>=clip_duration(clip)){enemy.state=EnemyCorpse;enemy.state_time=0;}}
      else if(enemy.state==EnemyCorpse)continue;
      else if(enemy.state==EnemyPain){enemy.state_time+=dt;if(enemy.state_time>=clip_duration(PAIN_CLIP)){enemy.state=EnemyWalk;enemy.state_time=0;}}
      else if(enemy.state==EnemyAttack){enemy.state_time+=dt;int frame_index=0;clip_frame(ATTACK_CLIP,enemy.state_time,&frame_index);if(!enemy.event_fired&&frame_index>=ATTACK_CLIP.event_frame){if(ranged&&(targets_enemy||(health>0&&enemy_notices_player(enemy,player)&&enemy_has_clear_player_shot(enemies,ENEMY_COUNT,enemy_index,player))) )launch_enemy_projectile(enemy,enemy_index);else if(targets_enemy&&std::hypot(target.x-enemy.pos.x,target.z-enemy.pos.z)<=1.40f)damage_enemy_from_enemy(enemies,ENEMY_COUNT,enemy_index,enemy.target_enemy,12);else if(!targets_enemy&&std::hypot(player.x-enemy.pos.x,player.z-enemy.pos.z)<=1.40f&&health>0)health-=12;enemy.event_fired=true;}if(enemy.state_time>=clip_duration(ATTACK_CLIP)){enemy.state=EnemyWalk;enemy.state_time=0;enemy.attack_cooldown=ranged?1.15f:.65f;}}
      else if(enemy.alive&&(targets_enemy||notices_player)){Vec3 delta={target.x-enemy.pos.x,0,target.z-enemy.pos.z};float dist=std::hypot(delta.x,delta.z),engage_distance=enemy_attack_distance(enemy);if(dist>engage_distance||(!targets_enemy&&ranged&&!player_shot_clear)){float target_facing=std::atan2(delta.x,delta.z);enemy.facing=turn_toward(enemy.facing,target_facing,2.6f*dt);Vec3 step;if(dist>engage_distance)step={std::sin(enemy.facing)*ENEMY_SPEED*dt,0,std::cos(enemy.facing)*ENEMY_SPEED*dt};else{float sign=(enemy_index&1)?1.0f:-1.0f;step={std::cos(enemy.facing)*ENEMY_SPEED*dt*sign,0,-std::sin(enemy.facing)*ENEMY_SPEED*dt*sign};}enemy.walk_time+=dt;if(!blocked(enemy.pos.x+step.x,enemy.pos.z))enemy.pos.x+=step.x;if(!blocked(enemy.pos.x,enemy.pos.z+step.z))enemy.pos.z+=step.z;}else if(enemy.attack_cooldown<=0){enemy.facing=std::atan2(delta.x,delta.z);enemy.state=EnemyAttack;enemy.state_time=0;enemy.event_fired=false;}}
      else if(enemy.alive){enemy.roam_timer-=dt;if(enemy.roam_timer<=0){enemy.roam_timer=1.25f+.35f*(enemy_index%3);enemy.roam_heading+=.95f+(enemy_index%2)*.62f;}enemy.facing=turn_toward(enemy.facing,enemy.roam_heading,1.8f*dt);Vec3 step={std::sin(enemy.facing)*ENEMY_SPEED*.55f*dt,0,std::cos(enemy.facing)*ENEMY_SPEED*.55f*dt};enemy.walk_time+=dt;if(blocked(enemy.pos.x+step.x,enemy.pos.z+step.z)){enemy.roam_heading+=1.5707963f;enemy.roam_timer=.1f;}else{enemy.pos.x+=step.x;enemy.pos.z+=step.z;}}
    }
    if(health<0)health=0;
    glViewport(0,0,W,H); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT); glMatrixMode(GL_PROJECTION); glLoadIdentity(); float near=.05f, far=130, top=near*std::tan(60.0f*3.14159265f/360.0f), right_plane=top*(float)W/H; glFrustum(-right_plane,right_plane,-top,top,near,far); glMatrixMode(GL_MODELVIEW); glLoadIdentity(); float lightpos[]={0,3.3f,0,1}; glLightfv(GL_LIGHT0,GL_POSITION,lightpos); glRotatef(pitch*57.2958f,1,0,0); glRotatef(-yaw*57.2958f,0,1,0); glTranslatef(-player.x,-player.y,-player.z);
    float diffuse[]={1.0f,.28f,.08f,1}; if(flash>0){diffuse[1]=.75f;diffuse[2]=.35f;} glLightfv(GL_LIGHT0,GL_DIFFUSE,diffuse); float ambient[]={.09f,.025f,.02f,1}; glLightModelfv(GL_LIGHT_MODEL_AMBIENT,ambient); room(wall,floor,ceiling); for(int i=0;i<ENEMY_COUNT;i++) enemy_model(enemy_directions,enemy_combat,enemies[i],enemies[i].type,player); if(projectile.active&&projectile.travelled>2.9f)draw_arc_world_trail(projectile.pos,projectile.vel,projectile.travelled);for(const auto &shot:visual_projectiles)if(shot.active)draw_projectile_sprite(projectile_sprites[shot.sprite][projectile_direction(shot.pos,shot.vel,player)],shot.pos,shot.vel,player,shot.sprite==PlayerPistolSprite?.52f:.76f,shot.sprite==PlayerPistolSprite?.24f:.34f);for(const auto &shot:enemy_projectiles)if(shot.active)draw_projectile_sprite(projectile_sprites[shot.sprite][projectile_direction(shot.pos,shot.vel,player)],shot.pos,shot.vel,player,shot.sprite==CultistFireSprite?.68f:.74f,shot.sprite==CultistFireSprite?.42f:.58f); draw_impact(impact); draw_first_person_launch(first_person_launches[launch.weapon],launch); draw_weapon_model(weapon_frames,weapon,fire_anim,hit_feedback>0); draw_arc_muzzle_flash(arc_muzzle_flash,arc_flash); if(health<=0) SDL_SetWindowTitle(window,"Eye Sore — combat down | R to restart"); else {char title[128];int alive=0;for(const auto &enemy:enemies)if(enemy.alive)alive++;std::snprintf(title,sizeof(title),"Eye Sore — %d targets | hp %.0f | score %d | %s",alive,health,score,weapon==0?"ember pistol":weapon==1?"rivet shotgun":"arc cannon");SDL_SetWindowTitle(window,title);}
    if(record_pipe){record_accumulator+=dt;if(record_accumulator>=1.0f/15.0f){record_accumulator-=1.0f/15.0f;glPixelStorei(GL_PACK_ALIGNMENT,1);glReadPixels(0,0,W,H,GL_RGB,GL_UNSIGNED_BYTE,record_pixels.data());std::fwrite(record_pixels.data(),1,record_pixels.size(),record_pipe);}}
    SDL_GL_SwapWindow(window);
  }
  if(wall) glDeleteTextures(1,&wall);
  if(floor) glDeleteTextures(1,&floor);
  if(ceiling) glDeleteTextures(1,&ceiling);
  for(int type=0;type<4;type++)for(int direction=0;direction<EnemyDirectionCount;direction++)for(int pose=0;pose<4;pose++)if(enemy_directions[type][direction][pose])glDeleteTextures(1,&enemy_directions[type][direction][pose]);
  for(int type=0;type<4;type++)for(int state=0;state<4;state++)for(int frame=0;frame<4;frame++)if(enemy_combat[type][state][frame])glDeleteTextures(1,&enemy_combat[type][state][frame]);
  for(auto &weapon_set:weapon_frames)for(GLuint frame:weapon_set)if(frame)glDeleteTextures(1,&frame);
  for(auto &direction_set:projectile_sprites)for(GLuint sprite:direction_set)if(sprite)glDeleteTextures(1,&sprite);
  for(GLuint texture:first_person_launches)if(texture)glDeleteTextures(1,&texture);
  if(arc_muzzle_flash)glDeleteTextures(1,&arc_muzzle_flash);
  if(audio_device)SDL_CloseAudioDevice(audio_device);
  if(music_device)SDL_CloseAudioDevice(music_device);
  for(auto &weapon_bank:weapon_sounds)for(auto &sound:weapon_bank)if(sound.data)SDL_FreeWAV(sound.data);
  if(impact_sound.data)SDL_FreeWAV(impact_sound.data);
  for(auto &sound:enemy_hit_sounds)if(sound.data)SDL_FreeWAV(sound.data);
  if(music.data)SDL_FreeWAV(music.data);
  if(record_pipe)pclose(record_pipe);
  SDL_SetRelativeMouseMode(SDL_FALSE); SDL_GL_DeleteContext(context); SDL_DestroyWindow(window); SDL_Quit(); return 0;
}
