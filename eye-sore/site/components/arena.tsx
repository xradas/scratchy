'use client';

import { useEffect, useRef, useState } from 'react';

type Enemy = { x: number; y: number; hp: number; speed: number; phase: number };
type Shot = { x: number; y: number; vx: number; vy: number; life: number };
const W = 960, H = 600;

export function Arena() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const keys = useRef(new Set<string>());
  const game = useRef({ player:{x:W/2,y:H/2,hp:100}, enemies:[] as Enemy[], shots:[] as Shot[], score:0, wave:1, tick:0, running:false, over:false, aimX:W/2+100, aimY:H/2, cooldown:0 });
  const [hud, setHud] = useState({score:0,hp:100,wave:1,ready:true,over:false});

  const spawnWave = (g = game.current) => {
    for (let i=0; i<4+g.wave*2; i++) {
      const edge = Math.floor(Math.random()*4);
      const x = edge===0 ? 35 : edge===1 ? W-35 : 70+Math.random()*(W-140);
      const y = edge===2 ? 70 : edge===3 ? H-60 : 85+Math.random()*(H-150);
      g.enemies.push({x,y,hp:2+Math.floor(g.wave/2),speed:.34+g.wave*.035,phase:Math.random()*6.28});
    }
  };
  const start = () => { const g=game.current; g.player={x:W/2,y:H/2,hp:100}; g.enemies=[];g.shots=[];g.score=0;g.wave=1;g.tick=0;g.running=true;g.over=false;g.cooldown=0;spawnWave(g);setHud({score:0,hp:100,wave:1,ready:false,over:false}); };
  const shoot = () => { const g=game.current; if(!g.running||g.cooldown>0)return; const dx=g.aimX-g.player.x,dy=g.aimY-g.player.y,d=Math.hypot(dx,dy)||1; g.shots.push({x:g.player.x,y:g.player.y,vx:dx/d*9.5,vy:dy/d*9.5,life:42});g.cooldown=8; };
  const control = (key:string, pressed:boolean) => { if(pressed)keys.current.add(key);else keys.current.delete(key); };

  useEffect(() => {
    const canvas=canvasRef.current,ctx=canvas?.getContext('2d');if(!canvas||!ctx)return;let raf=0,frame=0;
    const down=(e:KeyboardEvent)=>{const k=e.key.toLowerCase();if(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright',' '].includes(k))e.preventDefault();if(k===' ')shoot();else control(k,true);};
    const up=(e:KeyboardEvent)=>control(e.key.toLowerCase(),false);window.addEventListener('keydown',down);window.addEventListener('keyup',up);
    const iso=(x:number,y:number)=>({x:W/2+(x-W/2)*.79-(y-H/2)*.79,y:92+(x-W/2)*.32+(y-H/2)*.32});
    const unit=(u:{x:number;y:number},color:string,r:number,rotation=0)=>{const p=iso(u.x,u.y);ctx.save();ctx.translate(p.x,p.y);ctx.rotate(rotation);ctx.beginPath();ctx.moveTo(0,-r);ctx.lineTo(r*.88,r*.78);ctx.lineTo(-r*.88,r*.78);ctx.closePath();ctx.fillStyle=color;ctx.fill();ctx.strokeStyle='#f4f7ff';ctx.lineWidth=1.5;ctx.stroke();ctx.restore();};
    const loop=()=>{const g=game.current;ctx.fillStyle='#0b0c15';ctx.fillRect(0,0,W,H);
      for(let y=0;y<=H;y+=55)for(let x=0;x<=W;x+=55){const p=iso(x,y),q=iso(x+55,y),r=iso(x+55,y+55),s=iso(x,y+55);ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(q.x,q.y);ctx.lineTo(r.x,r.y);ctx.lineTo(s.x,s.y);ctx.closePath();ctx.fillStyle=((x/55+y/55)%2?'#131827':'#101523');ctx.fill();ctx.strokeStyle='rgba(202,255,60,.085)';ctx.stroke();}
      if(g.running){let dx=0,dy=0,k=keys.current;if(k.has('w')||k.has('arrowup'))dy-=2.5;if(k.has('s')||k.has('arrowdown'))dy+=2.5;if(k.has('a')||k.has('arrowleft'))dx-=2.5;if(k.has('d')||k.has('arrowright'))dx+=2.5;if(dx&&dy){dx*=.707;dy*=.707;}g.player.x=Math.max(35,Math.min(W-35,g.player.x+dx));g.player.y=Math.max(55,Math.min(H-45,g.player.y+dy));g.cooldown=Math.max(0,g.cooldown-1);
        for(const shot of g.shots){shot.x+=shot.vx;shot.y+=shot.vy;shot.life--;}g.shots=g.shots.filter(s=>s.life>0&&s.x>0&&s.x<W&&s.y>0&&s.y<H);
        for(const e of g.enemies){const dx=g.player.x-e.x,dy=g.player.y-e.y,d=Math.hypot(dx,dy)||1;e.x+=dx/d*e.speed;e.y+=dy/d*e.speed;if(d<26)g.player.hp=Math.max(0,g.player.hp-.17);}
        for(const shot of g.shots)for(const e of g.enemies)if(Math.hypot(shot.x-e.x,shot.y-e.y)<25&&shot.life>0){e.hp--;shot.life=0;}
        const before=g.enemies.length;g.enemies=g.enemies.filter(e=>e.hp>0);g.score+=(before-g.enemies.length)*125;if(!g.enemies.length){g.wave++;spawnWave(g);}if(g.player.hp<=0){g.running=false;g.over=true;}g.tick++;
      }
      for(const shot of g.shots){const p=iso(shot.x,shot.y);ctx.beginPath();ctx.arc(p.x,p.y,4,0,6.28);ctx.fillStyle='#caff3c';ctx.fill();}
      for(const e of g.enemies){unit(e,'#ff547d',16,e.phase+g.tick*.03);const p=iso(e.x,e.y);ctx.fillStyle='#ffbdca';ctx.fillRect(p.x-11,p.y-22,22,3);ctx.fillStyle='#ff547d';ctx.fillRect(p.x-10,p.y-21,20*(e.hp/(2+Math.floor(g.wave/2))),1);}
      const angle=Math.atan2(g.aimY-g.player.y,g.aimX-g.player.x);unit(g.player,'#caff3c',19,angle+Math.PI/2);const p=iso(g.player.x,g.player.y);ctx.strokeStyle='rgba(202,255,60,.55)';ctx.beginPath();ctx.arc(p.x,p.y,27,0,6.28);ctx.stroke();
      if(frame++%8===0)setHud({score:g.score,hp:Math.ceil(g.player.hp),wave:g.wave,ready:!g.running&&!g.over,over:g.over});raf=requestAnimationFrame(loop);};loop();
    return()=>{cancelAnimationFrame(raf);window.removeEventListener('keydown',down);window.removeEventListener('keyup',up);};
  },[]);
  const aim=(e:React.PointerEvent<HTMLCanvasElement>)=>{const r=e.currentTarget.getBoundingClientRect(),g=game.current;g.aimX=(e.clientX-r.left)*W/r.width;g.aimY=(e.clientY-r.top)*H/r.height;};
  return <main className="game-shell"><header className="topbar"><div className="wordmark"><h1>Eye Sore</h1><span>Isometric arena</span></div><div className="top-note">Original neon shooter // build 01</div></header><section className="game-grid"><div className="arena-frame"><div className="hud"><span>Integrity<br/><strong className={hud.hp<35?'danger':''}>{hud.hp}%</strong></span><span>Wave<br/><strong>{String(hud.wave).padStart(2,'0')}</strong></span><span>Score<br/><strong>{String(hud.score).padStart(6,'0')}</strong></span></div><canvas ref={canvasRef} width={W} height={H} onPointerMove={aim} onPointerDown={e=>{aim(e);shoot();}}/>{(hud.ready||hud.over)&&<div className="start-panel"><div><p className="eyebrow">{hud.over?'Signal lost':'Containment breach'}</p><h2>{hud.over?'Run ended':'Enter the grid'}</h2><p>{hud.over?`Final score: ${hud.score}. The grid has not forgiven you.`:'Move through the arena, point to aim, and fire through the incoming signal.'}</p><button className="launch" onClick={start}>{hud.over?'Reboot run':'Start run'}</button></div></div>}</div><aside className="side-panel"><p className="eyebrow">Play protocol</p><h2>Bright grid. Bad odds.</h2><p>An original, compact arcade shooter with the pressure and chunky isometric energy of 90s action games.</p><div className="rule"/><div className="keys"><div>WASD<span>move</span></div><div>Pointer<span>aim</span></div><div>Click<span>fire</span></div><div>Space<span>fire</span></div></div><div className="touch-controls"><button className="touch-button" onPointerDown={()=>control('a',true)} onPointerUp={()=>control('a',false)}>←</button><button className="touch-button" onPointerDown={()=>control('w',true)} onPointerUp={()=>control('w',false)}>↑</button><button className="touch-button" onPointerDown={()=>control('d',true)} onPointerUp={()=>control('d',false)}>→</button><button className="touch-button" onPointerDown={()=>control('s',true)} onPointerUp={()=>control('s',false)}>↓</button><button className="touch-button fire" onPointerDown={shoot}>Fire</button></div></aside></section><footer className="foot">Eye Sore is an original prototype. It uses no Doom artwork, levels, audio, code, or other game assets.</footer></main>;
}
