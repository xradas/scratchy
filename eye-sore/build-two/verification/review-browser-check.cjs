const { chromium } = require('/usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium',args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});
 const page=await browser.newPage({viewport:{width:1280,height:1000}});const problems=[];
 page.on('pageerror',err=>problems.push(String(err)));
 page.on('response',r=>{if(r.status()>=400 && !r.url().endsWith('favicon.ico'))problems.push(r.status()+' '+r.url());});
 await page.goto('http://127.0.0.1:8764/index.html',{waitUntil:'networkidle'});
 const choices=await page.locator('.choice').all();const checks=[];
 for(let i=0;i<choices.length;i++){
  await choices[i].click();const slug=await choices[i].getAttribute('data-packet');
  const packet=page.locator('#'+slug);if(!await packet.isVisible())throw new Error('Packet did not open '+slug);
  const controls=packet.locator('audio');const metadata=await controls.evaluateAll(p=>p.map(a=>({src:a.getAttribute('src'),duration:a.duration,error:a.error?.message||null,ready:a.readyState})));
  if(metadata.some((m,j)=>!Number.isFinite(m.duration)||m.error||Math.abs(m.duration-[25,10,25][j])>0.05))throw new Error('Audio metadata '+JSON.stringify(metadata));
  await controls.nth(2).evaluate(a=>{return a.play().then(()=>{a.currentTime=16;});}); await page.waitForTimeout(1000); const warningTime=await controls.nth(2).evaluate(a=>({time:a.currentTime,paused:a.paused,duration:a.duration,buffered:Array.from({length:a.buffered.length},(_,i)=>[a.buffered.start(i),a.buffered.end(i)])})); if(warningTime.time<=16.2)throw new Error('Warning section inaccessible '+JSON.stringify(warningTime)); await controls.nth(0).evaluate(a=>a.play());await page.waitForTimeout(500);
  const time=await controls.nth(0).evaluate(a=>a.currentTime);if(time<=0)throw new Error('Playback not advancing');
  await controls.nth(1).evaluate(a=>a.play());if(!await controls.nth(0).evaluate(a=>a.paused))throw new Error('Overlapping players');
  await packet.locator('summary').click();
  await page.screenshot({path:__dirname+'/review-'+slug+'.png',fullPage:true});
  await packet.locator('summary').click();checks.push({slug,metadata,playback_advances:true,one_player_at_a_time:true});
 }
 const sharedDuration=await page.locator('.shared audio').evaluate(a=>a.duration); if(Math.abs(sharedDuration-12)>0.05)throw new Error('Shared comparison duration');
 await choices[0].click();
 if((await page.locator('audio').evaluateAll(p=>p.filter(a=>!a.paused).length))!==0)throw new Error('Switch does not stop old audio');
 await page.setViewportSize({width:390,height:844});
 await page.screenshot({path:__dirname+'/review-mobile.png',fullPage:true});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);if(overflow)throw new Error('Mobile horizontal overflow');
 if(problems.length)throw new Error(JSON.stringify(problems));
 fs.writeFileSync(__dirname+'/review-browser-check.json',JSON.stringify({checks,errors:problems,packet_switch_pauses_audio:true,mobile_overflow:false,scope:'Technical browser playback only; no subjective listening validation.'},null,2)+'\n');
 console.log('All 3 packets, 10 audio controls, playback, switching, error checks and mobile layout verified.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
