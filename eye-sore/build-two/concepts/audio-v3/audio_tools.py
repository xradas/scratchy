import pathlib,subprocess,re,json,hashlib,math,array
B=pathlib.Path(__file__).resolve().parent
F=['ffmpeg','-hide_banner','-nostdin','-y']
def run(a):
 p=subprocess.run(a,text=True,capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr)
 return p.stderr
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def probe(p):return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=channels,sample_rate,codec_name','-of','json',str(p)],text=True))
def ff(src,dst,start=0,duration=None,filters=''):
 a=F+['-i',str(src),'-ss',str(start)]
 if duration is not None:a+=['-t',str(duration)]
 if filters:a+=['-af',filters]
 run(a+['-ar','48000','-ac','1','-c:a','pcm_s16le',str(dst)])
def peak(src,dst,target):
 txt=run(F+['-i',str(src),'-af','volumedetect','-f','null','-']);v=float(re.search(r'max_volume: ([\-0-9.]+) dB',txt)[1]);ff(src,dst,filters=f'volume={target-v}dB')
def mix(ev,dst,duration=None):
 a=F.copy();g=[]
 for i,(p,t,gain) in enumerate(ev):
  a+=['-i',str(p)];g.append(f'[{i}:a]aresample=48000,aformat=channel_layouts=mono,volume={gain},adelay={int(t*1000)}[e{i}]')
 tail=f',apad,atrim=duration={duration}' if duration else ''
 g.append(''.join(f'[e{i}]' for i in range(len(ev)))+f'amix=inputs={len(ev)}:normalize=0'+tail+'[out]');run(a+['-filter_complex',';'.join(g),'-map','[out]','-ar','48000','-ac','1','-c:a','pcm_s16le',str(dst)])
def ogg(p):run(F+['-i',str(p),'-c:a','libvorbis','-q:a','6',str(p.with_suffix('.ogg'))])
def active_start(p):
 raw=subprocess.check_output(F+['-i',str(p),'-ar','48000','-ac','1','-f','f32le','-'],stderr=subprocess.DEVNULL);a=array.array('f');a.frombytes(raw);pk=max(abs(x) for x in a);idx=next(i for i,x in enumerate(a) if abs(x)>=pk*.1);return max(0,idx/48000-.006)
def build(layers,out,target,stemname):
 ev=[];dryev=[];ledger=[]
 for i,(p,start,duration,pitch,filters,gain,delay) in enumerate(layers):
  raw=B/'stems'/f'{stemname}-{i}-raw.wav';ff(p,raw,start,duration)
  dn=B/'stems'/f'{stemname}-{i}-dry.wav';peak(raw,dn,-12);dryev.append((dn,delay,gain))
  fx=f'asetrate=48000*{pitch},aresample=48000,'+filters
  tmp=B/'stems'/f'{stemname}-{i}-fx.wav';ff(raw,tmp,filters=fx.rstrip(','));d=float(probe(tmp)['format']['duration']);fade=min(.035,d*.25)
  tail=B/'stems'/f'{stemname}-{i}-tail.wav';ff(tmp,tail,filters=f'afade=t=in:d=0.002,afade=t=out:st={d-fade}:d={fade}')
  norm=B/'stems'/f'{stemname}-{i}-norm.wav';peak(tail,norm,-12);ev.append((norm,delay,gain))
  ledger.append({'original':str(p.relative_to(B)),'original_sha256':sha(p),'start_seconds':start,'duration_seconds':duration,'pitch_playback_ratio':pitch,'filters':filters,'layer_gain':gain,'delay_seconds':delay,'fade_in_seconds':.002,'fade_out_seconds':fade})
 tmp=B/'stems'/f'{stemname}-mix.wav';mix(ev,tmp);peak(tmp,out,target);ogg(out)
 dry=B/'dry'/f'{stemname}.wav';mix(dryev,tmp);peak(tmp,dry,target)
 return dry,ledger
