const {chromium}=require('/usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium',args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});
 const page=await browser.newPage({viewport:{width:1280,height:900}});const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('response',r=>{if(r.status()>=400&&!r.url().endsWith('favicon.ico'))errors.push(r.status()+' '+r.url())});
 await page.goto('http://127.0.0.1:8764/audio-v3/',{waitUntil:'networkidle'});
 const metadata=await page.locator('audio').evaluateAll(async players=>{const result=[];for(const a of players){if(a.readyState===0){await new Promise((resolve,reject)=>{a.addEventListener('loadedmetadata',resolve,{once:true});a.addEventListener('error',()=>reject(new Error(a.src)),{once:true});a.load()})}result.push({file:a.getAttribute('src'),duration:a.duration,error:a.error?.message||null})}return result});
 if(metadata.some(a=>a.error||!Number.isFinite(a.duration)||a.duration<=0))throw Error('Bad metadata');
 const deaths=page.locator('audio[src*="death-screams-vs-short-hurt-9s"]');if(await deaths.count()!==1)throw Error('Missing death comparison');
 await deaths.evaluate(a=>{a.currentTime=2;return a.play()});await page.waitForTimeout(450);if(await deaths.evaluate(a=>a.currentTime)<=2.2)throw Error('Seek/play did not advance');
 const pistol=page.locator('audio[src="cues/pistol_flesh.ogg"]');await pistol.evaluate(a=>a.play());await page.waitForTimeout(30);if(!await deaths.evaluate(a=>a.paused))throw Error('Audio overlap');
 await page.screenshot({path:__dirname+'/combat/audio-review-desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:__dirname+'/combat/audio-review-mobile.png',fullPage:true});
 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Mobile overflow');
 if(errors.length)throw Error(JSON.stringify(errors));
 fs.writeFileSync(__dirname+'/combat/audio-browser-check.json',JSON.stringify({metadata,errors,seek_play:true,one_player_at_a_time:true,mobile_overflow:false,scope:'Technical browser verification; human listening approval remains pending.'},null,2)+'\n');
 console.log('Dry audio review: all '+metadata.length+' controls, metadata, seeking, one-player policy and mobile layout passed.');await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
