#include "combat_world.h"

#include <algorithm>
#include <cmath>

namespace combat_world {
namespace {
constexpr float epsilon = 1.0e-6f;
float component(Vec3 v, int axis) { return axis == 0 ? v.x : axis == 1 ? v.y : v.z; }
void set_component(Vec3 &v, int axis, float value) { if (axis == 0) v.x = value; else if (axis == 1) v.y = value; else v.z = value; }
Vec3 at(Vec3 a, Vec3 b, float t) { return {a.x + (b.x-a.x)*t, a.y + (b.y-a.y)*t, a.z + (b.z-a.z)*t}; }
bool inside(Vec3 p, Box b) {
  return p.x >= b.min.x && p.x <= b.max.x && p.y >= b.min.y && p.y <= b.max.y && p.z >= b.min.z && p.z <= b.max.z;
}
float distance_squared(Vec3 p, Box b) {
  float x = std::max(b.min.x-p.x, std::max(0.0f, p.x-b.max.x));
  float y = std::max(b.min.y-p.y, std::max(0.0f, p.y-b.max.y));
  float z = std::max(b.min.z-p.z, std::max(0.0f, p.z-b.max.z));
  return x*x+y*y+z*z;
}
Vec3 contact_normal(Vec3 p, Box b) {
  Vec3 nearest{std::max(b.min.x,std::min(p.x,b.max.x)),std::max(b.min.y,std::min(p.y,b.max.y)),std::max(b.min.z,std::min(p.z,b.max.z))};
  Vec3 n{p.x-nearest.x,p.y-nearest.y,p.z-nearest.z};
  float length=std::sqrt(n.x*n.x+n.y*n.y+n.z*n.z);
  return length>epsilon ? Vec3{n.x/length,n.y/length,n.z/length} : Vec3{};
}
// Slab intersection retains the entering face. It works for axis-aligned and
// vertical rays and for rays beginning inside the box.
bool ray_box(Vec3 a, Vec3 b, Box box, float &fraction, Vec3 &normal) {
  float enter=0.0f, leave=1.0f;
  Vec3 enter_normal{};
  for(int axis=0;axis<3;axis++) {
    float origin=component(a,axis), delta=component(b,axis)-origin;
    float low=component(box.min,axis), high=component(box.max,axis);
    if(std::fabs(delta)<epsilon) { if(origin<low||origin>high)return false; continue; }
    float near_t=(low-origin)/delta, far_t=(high-origin)/delta;
    Vec3 face{};set_component(face,axis,-1.0f);
    if(near_t>far_t) {std::swap(near_t,far_t);set_component(face,axis,1.0f);}
    if(near_t>enter) {enter=near_t;enter_normal=face;}
    leave=std::min(leave,far_t);
    if(enter>leave)return false;
  }
  fraction=enter;normal=enter_normal;
  return leave>=0.0f&&enter<=1.0f;
}
bool sphere_box_segment(Vec3 a, Vec3 b, Box box, float radius, float &fraction, Vec3 &normal) {
  if(radius<=0)return ray_box(a,b,box,fraction,normal);
  float radius2=radius*radius;
  if(distance_squared(a,box)<=radius2) {fraction=0;normal=contact_normal(a,box);return true;}
  // Squared distance from a segment to a convex box is convex in time. Find
  // its minimum, then bisect the first crossing for a rounded-box contact.
  float low=0,high=1;
  for(int i=0;i<40;i++) {
    float left=(2*low+high)/3, right=(low+2*high)/3;
    if(distance_squared(at(a,b,left),box)<distance_squared(at(a,b,right),box))high=right;else low=left;
  }
  float minimum=(low+high)*.5f;
  if(distance_squared(at(a,b,minimum),box)>radius2)return false;
  low=0;high=minimum;
  for(int i=0;i<32;i++) {
    float mid=(low+high)*.5f;
    if(distance_squared(at(a,b,mid),box)<=radius2)high=mid;else low=mid;
  }
  fraction=high;normal=contact_normal(at(a,b,fraction),box);return true;
}
}

World descent_world() {
  World world;
  world.room={{-36.0f,0.0f,-30.0f},{36.0f,5.0f,30.0f}};
  constexpr float pillars[][2]={{-18,-19},{18,-19},{-18,19},{18,19},{0,18},{0,-18},{-26,0},{26,0}};
  constexpr float walls[][4]={{-36,9,-7,10},{7,9,36,10},{-36,-10,-7,-9},{7,-10,36,-9},{-15,10,-14,21},{-15,25,-14,30},{14,10,15,21},{14,25,15,30},{-15,-30,-14,-21},{-15,-25,-14,-9},{14,-30,15,-21},{14,-25,15,-9}};
  world.solids.reserve(8+12+5);
  for(const auto &p:pillars)world.solids.push_back({{{p[0]-.57f,0,p[1]-.57f},{p[0]+.57f,4.55f,p[1]+.57f}},Surface::pillar});
  for(const auto &w:walls)world.solids.push_back({{{w[0],0,w[1]},{w[2],5.0f,w[3]}},Surface::wall});
  // Kneehigh-to-chest-high forge baffles give the broad middle court readable
  // cover and break the long cross-map firing lane without sealing routes.
  world.solids.push_back({{{-9.0f,0.0f,-1.4f},{-5.4f,1.32f,0.0f}},Surface::pillar});
  world.solids.push_back({{{5.6f,0.0f,-7.8f},{9.2f,1.18f,-6.5f}},Surface::pillar});
  world.solids.push_back({{{-1.0f,0.0f,4.0f},{2.2f,1.05f,5.25f}},Surface::pillar});
  world.solids.push_back({{{-12.0f,0.0f,-5.0f},{-9.7f,1.5f,-3.6f}},Surface::pillar});
  world.solids.push_back({{{10.3f,0.0f,3.2f},{12.6f,1.4f,4.6f}},Surface::pillar});
  return world;
}

World starling_rink_world() {
  World world;
  world.room={{-14.0f,0.0f,-22.0f},{14.0f,5.0f,16.0f}};
  // Two broad gate openings connect the lobby, rink, chicane and finish court.
  // A low central bumper island genuinely occludes the far Lap Counter shot.
  auto add=[&](float x0,float z0,float x1,float z1,float height){world.solids.push_back({{{x0,0,z0},{x1,height,z1}},Surface::wall});};
  add(-14,9,-4,10,5); add(4,9,14,10,5);
  add(-14,-6,-5,-5,5); add(5,-6,14,-5,5);
  add(-1.65f,-1.6f,1.65f,1.65f,1.25f);
  add(-8.2f,3.4f,-5.5f,4.35f,1.1f); add(5.5f,3.4f,8.2f,4.35f,1.1f);
  add(10.2f,2.2f,12.0f,3.4f,2.3f);
  return world;
}

bool blocks_actor(const World &world, Vec3 feet, float radius, float height) {
  if(radius<0||height<0)return true;
  const Box &room=world.room;
  if(feet.x-radius<room.min.x||feet.x+radius>room.max.x||feet.z-radius<room.min.z||feet.z+radius>room.max.z||feet.y<room.min.y||feet.y+height>room.max.y)return true;
  for(const auto &solid:world.solids) {
    const Box &box=solid.box;
    if(feet.y>=box.max.y||feet.y+height<=box.min.y)continue;
    float dx=std::max(box.min.x-feet.x,std::max(0.0f,feet.x-box.max.x));
    float dz=std::max(box.min.z-feet.z,std::max(0.0f,feet.z-box.max.z));
    if(dx*dx+dz*dz<radius*radius || (radius==0&&dx==0&&dz==0))return true;
  }
  return false;
}

Hit trace_segment(const World &world, Vec3 start, Vec3 end, float radius) {
  Hit hit;hit.position=end;
  radius=std::max(0.0f,radius);
  const Box inner={{world.room.min.x+radius,world.room.min.y+radius,world.room.min.z+radius},
                   {world.room.max.x-radius,world.room.max.y-radius,world.room.max.z-radius}};
  if(!inside(start,inner)) {hit.blocked=true;hit.fraction=0;hit.position=start;hit.surface=Surface::room;return hit;}
  // The room is containment geometry. Test each exit plane, including floor
  // and ceiling, rather than tracing the room as a solid box.
  for(int axis=0;axis<3;axis++) {
    float a=component(start,axis),d=component(end,axis)-a;
    float edge=d>0?component(inner.max,axis):component(inner.min,axis);
    if(std::fabs(d)<epsilon)continue;
    float t=(edge-a)/d;
    if(t>=0&&t<=1&&(!hit.blocked||t<hit.fraction)) {
      hit.blocked=true;hit.fraction=t;hit.surface=Surface::room;
      hit.normal={};set_component(hit.normal,axis,d>0?-1.0f:1.0f);
    }
  }
  for(std::size_t i=0;i<world.solids.size();i++) {
    float t;Vec3 normal;
    if(sphere_box_segment(start,end,world.solids[i].box,radius,t,normal)&&(!hit.blocked||t<hit.fraction)) {
      hit.blocked=true;hit.fraction=t;hit.normal=normal;
      hit.surface=world.solids[i].surface;hit.solid_index=i;
    }
  }
  hit.position=at(start,end,hit.fraction);
  return hit;
}

bool clear_line(const World &world, Vec3 start, Vec3 end) {
  Hit hit=trace_segment(world,start,end);
  return !hit.blocked||hit.fraction>=1.0f-epsilon;
}
} // namespace combat_world
