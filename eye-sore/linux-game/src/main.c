#include <SDL2/SDL.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>

#define W 960
#define H 600
#define MW 16
#define MH 9
#define FOV 1.0471975512

static const char map[MH][MW + 1] = {
  "1111111111111111", "1......1.......1", "1.111..1.1111..1",
  "1...1..1....1..1", "1.1.1..111..1..1", "1.1............1",
  "1.111111.1111..1", "1..............1", "1111111111111111"
};
typedef struct { float x, y, hp; int alive, kind; float bob; } Fiend;
typedef struct { float x, y, a, hp; int score, shot, won, weapon, key, medkit, ammo_pickup; int ammo[3]; Fiend f[4]; } Game;

static float wrap(float x) { while (x < 0) x += 6.2831853f; while (x >= 6.2831853f) x -= 6.2831853f; return x; }
static int wall(float x, float y) { int ix=(int)x, iy=(int)y; return ix < 0 || iy < 0 || ix >= MW || iy >= MH || map[iy][ix] == '1'; }
static void rect(SDL_Renderer *r, int x, int y, int w, int h, Uint8 a, Uint8 b, Uint8 c) { SDL_SetRenderDrawColor(r,a,b,c,255); SDL_RenderFillRect(r,&(SDL_Rect){x,y,w,h}); }
static void reset(Game *g) { *g=(Game){.x=1.55f,.y=1.55f,.hp=100,.medkit=1,.ammo_pickup=1,.ammo={120,36,14},.f={{6.2f,2.2f,5,1,0,0},{12.4f,3.4f,4,1,1,1},{10.5f,7,3,1,2,2},{4.5f,7,8,1,3,3}}}; }

static SDL_Texture *load_sprites(SDL_Renderer *r) { SDL_Surface *s=SDL_LoadBMP("assets/infernal-sprite-sheet.bmp"); if(!s){char path[1024];char *base=SDL_GetBasePath();if(base){snprintf(path,sizeof path,"%s../assets/infernal-sprite-sheet.bmp",base);s=SDL_LoadBMP(path);SDL_free(base);}} if(!s){fprintf(stderr,"Missing sprite sheet: %s\n",SDL_GetError());return NULL;} SDL_SetColorKey(s,SDL_TRUE,SDL_MapRGB(s->format,0,0,0)); SDL_Texture *t=SDL_CreateTextureFromSurface(r,s); SDL_FreeSurface(s); return t; }
static SDL_Texture *load_material(SDL_Renderer *r, const char *name) { SDL_Surface *s=SDL_LoadBMP(name); if(!s){char path[1024];char *base=SDL_GetBasePath();if(base){snprintf(path,sizeof path,"%s../%s",base,name);s=SDL_LoadBMP(path);SDL_free(base);}} if(!s){fprintf(stderr,"Missing material: %s\n",name);return NULL;} SDL_Texture *t=SDL_CreateTextureFromSurface(r,s); SDL_FreeSurface(s); return t; }
static SDL_Texture *load_fire(SDL_Renderer *r) { SDL_Surface *s=SDL_LoadBMP("assets/infernal-firing-sheet.bmp"); if(!s){char path[1024];char *base=SDL_GetBasePath();if(base){snprintf(path,sizeof path,"%s../assets/infernal-firing-sheet.bmp",base);s=SDL_LoadBMP(path);SDL_free(base);}} if(!s)return NULL; SDL_SetColorKey(s,SDL_TRUE,SDL_MapRGB(s->format,0,0,0)); SDL_Texture *t=SDL_CreateTextureFromSurface(r,s); SDL_FreeSurface(s); return t; }
static void tile_material(SDL_Renderer *r, SDL_Texture *t, int top, int height) { if(!t)return; for(int y=top;y<top+height;y+=192) for(int x=0;x<W;x+=192) SDL_RenderCopy(r,t,NULL,&(SDL_Rect){x,y,192,192}); }
static SDL_Rect source_for(int kind) { SDL_Rect q[]={{0,0,445,440},{450,0,440,440},{890,0,430,440},{1325,0,449,440}}; return q[kind%4]; }
static void fire(Game *g) { int dmg[]={1,3,5}, cost[]={1,1,1}; if(g->weapon<0||g->weapon>2||g->ammo[g->weapon]<cost[g->weapon]||g->hp<=0||g->won)return; g->ammo[g->weapon]-=cost[g->weapon];g->shot=24; for(int i=0;i<4;i++){Fiend*f=&g->f[i];if(!f->alive)continue;float dx=f->x-g->x,dy=f->y-g->y,d=hypotf(dx,dy),a=fabsf(atan2f(sinf(atan2f(dy,dx)-g->a),cosf(atan2f(dy,dx)-g->a)));float cone=g->weapon==1?.23f:.12f;if(a<cone&&d<11){f->hp-=dmg[g->weapon];if(f->hp<=0){f->alive=0;g->score+=300+f->kind*100;}if(g->weapon!=1)break;}}}
static void marker(SDL_Renderer*r,Game*g,float*z,float px,float py,Uint8 cr,Uint8 cg,Uint8 cb){float dx=px-g->x,dy=py-g->y,d=hypotf(dx,dy),a=atan2f(sinf(atan2f(dy,dx)-g->a),cosf(atan2f(dy,dx)-g->a));if(fabsf(a)>FOV*.55f)return;int sx=(int)(W*.5f+a/FOV*W),col=sx<0?0:sx>=W?W-1:sx,size=(int)fminf(120,160/d);if(d>z[col])return;rect(r,sx-size/2,H/2-size/2,size,size,cr,cg,cb);rect(r,sx-size/3,H/2-size*2/3,size*2/3,size/3,255,210,120);}

static void draw_fiend(SDL_Renderer *r, SDL_Texture *sprites, int kind, int sx, int base, int size, float t, int hp) {
  if(sprites){ SDL_Rect src=source_for(kind), dst={sx-size/2,base-size+(int)(sinf(t*7)*size*.055f),size,size}; SDL_RenderCopy(r,sprites,&src,&dst); rect(r,sx-size/2,base-size-2,size,5,60,4,7); rect(r,sx-size/2,base-size-2,size*hp/8,5,255,76,35); return; }
  int bob=(int)(sinf(t*7)*size*.055f), top=base-size+bob, half=size/2;
  rect(r,sx-half,top+size/4,size,size*3/4,83,10,16); rect(r,sx-half+size/7,top+size/5,size*5/7,size*3/5,186,28,22);
  rect(r,sx-half+size/5,top+size/3,size/5,size/7,255,104,34); rect(r,sx+size/12,top+size/3,size/5,size/7,255,104,34);
  rect(r,sx-half,top+size/12,size/3,size/5,110,18,15); rect(r,sx+size/6,top+size/12,size/3,size/5,110,18,15);
  rect(r,sx-half,top-2,size,5,60,4,7); rect(r,sx-half,top-2,size*hp/4,5,255,76,35);
}

static void render(SDL_Renderer *r, SDL_Texture *sprites, SDL_Texture *walltex, SDL_Texture *floortex, SDL_Texture *ceilingtex, SDL_Texture *firetex, Game *g, float t) {
  float z[W]; SDL_SetRenderDrawColor(r,20,2,5,255); SDL_RenderClear(r);
  for(int y=0;y<H/2;y++){ Uint8 rr=20+(Uint8)(y*.08f); rect(r,0,y,W,1,rr,3,8); }
  for(int y=H/2;y<H;y++){ Uint8 rr=47-(Uint8)((y-H/2)*.11f); rect(r,0,y,W,1,rr,10,8); }
  tile_material(r,ceilingtex,0,H/2);
  tile_material(r,floortex,H/2,H/2);
  for(int x=0;x<W;x++) { float a=g->a-FOV*.5f+FOV*x/W, d=.02f; while(d<18 && !wall(g->x+cosf(a)*d,g->y+sinf(a)*d)) d+=.018f; float hitx=g->x+cosf(a)*d,hity=g->y+sinf(a)*d; float u=fabsf(fabsf(cosf(a))>fabsf(sinf(a)) ? hity-floorf(hity) : hitx-floorf(hitx)); float q=d*cosf(a-g->a), hh=fminf(H*1.3f,480/q); z[x]=q; int top=(int)(H*.5f-hh*.5f); Uint8 glow=(Uint8)fmaxf(19,190-q*17); if(walltex){int tx=(int)(u*400);if(tx>399)tx=399;SDL_Rect src={tx,0,1,300},dst={x,top,1,(int)hh};SDL_RenderCopy(r,walltex,&src,&dst);SDL_SetRenderDrawBlendMode(r,SDL_BLENDMODE_BLEND);SDL_SetRenderDrawColor(r,22,0,4,(Uint8)fminf(225,q*17));SDL_RenderFillRect(r,&dst);SDL_SetRenderDrawBlendMode(r,SDL_BLENDMODE_NONE);}else rect(r,x,top,1,(int)hh,glow,(Uint8)(glow*.12f),(Uint8)(glow*.09f)); if(x%9==0) rect(r,x,top,1,(int)hh,20,1,4); }
  if (g->medkit) marker(r,g,z,3.5f,5.5f,65,225,110);
  if (g->ammo_pickup) marker(r,g,z,11.5f,5.5f,60,150,255);
  if (!g->key) marker(r,g,z,8.5f,5.5f,255,135,24);
  else marker(r,g,z,14.1f,7.1f,70,180,255);
  for(int pass=0;pass<4;pass++){ int best=-1; float far=-1; for(int i=0;i<4;i++){ Fiend *f=&g->f[i]; if(!f->alive)continue; float dx=f->x-g->x,dy=f->y-g->y,d=hypotf(dx,dy); if(d>far){far=d;best=i;} } if(best<0)break; Fiend *f=&g->f[best]; f->alive=2; float dx=f->x-g->x,dy=f->y-g->y,d=hypotf(dx,dy),rel=atan2f(sinf(atan2f(dy,dx)-g->a),cosf(atan2f(dy,dx)-g->a)); int sx=(int)(W*.5f+rel/FOV*W), col=sx<0?0:sx>=W?W-1:sx; if(fabsf(rel)<FOV*.65f && d<z[col]+.12f){ int size=(int)fminf(430,600/d); draw_fiend(r,sprites,f->kind,sx,H/2+size/2,size,t+f->bob,(int)f->hp); } f->alive=1; }
  rect(r,W/2-2,H/2-14,4,28,255,198,137); rect(r,W/2-14,H/2-2,28,4,255,198,137);
  int kick=g->shot?18:0; if(sprites){ SDL_Rect ws[]={{0,445,440,440},{445,445,445,440},{890,445,450,440}}; SDL_Rect dst={W/2-150,H-285+kick,300,300}; SDL_RenderCopy(r,sprites,&ws[g->weapon],&dst); } else { rect(r,W/2-78,H-93+kick,156,93,91,20,18); rect(r,W/2-26,H-138+kick,52,54,g->shot?255:162,g->shot?203:45,37); } if(g->shot)rect(r,W/2-40,H-160+kick,80,35,255,240,178);
  if(firetex && g->shot){ int frame=(24-g->shot)/6; if(frame>3)frame=3; SDL_Rect src={frame*384,g->weapon*341,384,341},dst={W/2-240,H-335+kick,480,341}; SDL_RenderCopy(r,firetex,&src,&dst); }
  int alive=g->f[0].alive+g->f[1].alive+g->f[2].alive+g->f[3].alive; rect(r,15,15,(int)fmaxf(0,g->hp)*2,12,255,68,36); rect(r,15,32,g->ammo[g->weapon]*2,8,70,170,255); SDL_SetRenderDrawColor(r,255,95,45,255); SDL_RenderDrawRect(r,&(SDL_Rect){15,15,240,26}); if(g->key)rect(r,270,15,18,18,255,160,30); if(!alive&&g->key)rect(r,300,15,18,18,70,180,255);
  if(g->hp<=0 || g->won){ rect(r,0,0,W,H,5,0,2); rect(r,W/2-245,H/2-72,490,144,35,4,8); SDL_SetRenderDrawColor(r,g->won?70:255,g->won?180:83,g->won?255:40,255); SDL_RenderDrawRect(r,&(SDL_Rect){W/2-245,H/2-72,490,144}); }
  SDL_RenderPresent(r);
}

int main(void) {
  if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO)!=0){fprintf(stderr,"SDL error: %s\n",SDL_GetError());return 1;} SDL_Window *win=SDL_CreateWindow("Eye Sore — Furnace Descent",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,W,H,SDL_WINDOW_SHOWN|SDL_WINDOW_ALWAYS_ON_TOP); if(!win){fprintf(stderr,"Window error: %s\n",SDL_GetError());return 1;} SDL_ShowWindow(win); SDL_RaiseWindow(win); SDL_Renderer *r=SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED|SDL_RENDERER_PRESENTVSYNC); if(!r)r=SDL_CreateRenderer(win,-1,SDL_RENDERER_SOFTWARE); if(!r){fprintf(stderr,"Renderer error: %s\n",SDL_GetError());SDL_DestroyWindow(win);return 1;}
  SDL_Texture *sprites=load_sprites(r),*walltex=load_material(r,"assets/infernal-wall.bmp"),*floortex=load_material(r,"assets/infernal-floor.bmp"),*ceilingtex=load_material(r,"assets/infernal-ceiling.bmp"),*firetex=load_fire(r); Game g; reset(&g); SDL_SetRelativeMouseMode(SDL_TRUE); bool on=true; Uint32 prev=SDL_GetTicks();
  while(on){ Uint32 now=SDL_GetTicks(); float dt=fminf(.04f,(now-prev)/1000.f); prev=now; SDL_Event e; while(SDL_PollEvent(&e)){if(e.type==SDL_QUIT)on=false; if(e.type==SDL_KEYDOWN&&e.key.keysym.sym==SDLK_ESCAPE)on=false; if(e.type==SDL_KEYDOWN&&e.key.keysym.sym==SDLK_RETURN&&(g.hp<=0||g.won))reset(&g); if(e.type==SDL_KEYDOWN&&e.key.keysym.sym>=SDLK_1&&e.key.keysym.sym<=SDLK_3)g.weapon=e.key.keysym.sym-SDLK_1; if(e.type==SDL_MOUSEMOTION)g.a=wrap(g.a+e.motion.xrel*.003f); if((e.type==SDL_MOUSEBUTTONDOWN&&e.button.button==SDL_BUTTON_LEFT)||(e.type==SDL_KEYDOWN&&e.key.keysym.sym==SDLK_SPACE))fire(&g); }
    const Uint8*k=SDL_GetKeyboardState(NULL); float forward=(k[SDL_SCANCODE_W]?1:0)-(k[SDL_SCANCODE_S]?1:0),side=(k[SDL_SCANCODE_D]?1:0)-(k[SDL_SCANCODE_A]?1:0),speed=2.2f*dt; float nx=g.x+(cosf(g.a)*forward+cosf(g.a+1.5708f)*side)*speed,ny=g.y+(sinf(g.a)*forward+sinf(g.a+1.5708f)*side)*speed;if(!wall(nx,g.y))g.x=nx;if(!wall(g.x,ny))g.y=ny;
    for(int i=0;i<4;i++){Fiend*f=&g.f[i];if(!f->alive)continue;float dx=g.x-f->x,dy=g.y-f->y,d=hypotf(dx,dy),speed=.23f+.05f*f->kind;f->bob+=dt;if(d>.68f){f->x+=dx/d*dt*speed;f->y+=dy/d*dt*speed;}else g.hp-=dt*(10+4*f->kind);} if(g.medkit&&hypotf(g.x-3.5f,g.y-5.5f)<.55f){g.medkit=0;g.hp=fminf(100,g.hp+35);g.score+=100;} if(g.ammo_pickup&&hypotf(g.x-11.5f,g.y-5.5f)<.55f){g.ammo_pickup=0;g.ammo[0]+=50;g.ammo[1]+=10;g.ammo[2]+=3;g.score+=100;} if(!g.key&&hypotf(g.x-8.5f,g.y-5.5f)<.65f){g.key=1;g.score+=750;g.ammo[1]+=12;g.ammo[2]+=4;} if(!g.f[0].alive&&!g.f[1].alive&&!g.f[2].alive&&!g.f[3].alive&&g.key&&g.x>13.2f&&g.y>6.2f)g.won=1; if(g.shot)g.shot--; render(r,sprites,walltex,floortex,ceilingtex,firetex,&g,now/1000.f); }
  SDL_SetRelativeMouseMode(SDL_FALSE); if(sprites)SDL_DestroyTexture(sprites); if(walltex)SDL_DestroyTexture(walltex); if(floortex)SDL_DestroyTexture(floortex); if(ceilingtex)SDL_DestroyTexture(ceilingtex); if(firetex)SDL_DestroyTexture(firetex); SDL_DestroyRenderer(r); SDL_DestroyWindow(win); SDL_Quit(); return 0;
}
