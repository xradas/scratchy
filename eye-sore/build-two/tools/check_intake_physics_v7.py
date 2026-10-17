#!/usr/bin/env python3
"""Run isolated native physics and actual Compatibility rate probes; no generation."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/intake-v7/physics'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def run(name,arguments):
    report=OUT/(name+'.json'); log=OUT/(name+'.log')
    cmd=[str(ROOT/'tools/godot.sh'),*arguments,'--script','res://tools/check_intake_physics_v7.gd','--','--report='+str(report)]
    if name.startswith('render-'):cmd.append('--rate-only')
    start=time.time()
    with log.open('w') as stream:
        result=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=300)
    raw=json.loads(report.read_text()) if report.exists() else {}
    launch={'command':cmd,'cwd':str(ROOT),'exit_code':result.returncode,'wall_seconds':time.time()-start,'report_sha256':sha(report) if report.exists() else None,'log_sha256':sha(log),'scene_sha256':sha(ROOT/'scenes/campaign/pale_ward_01.tscn'),'fixture_sha256':sha(ROOT/'tools/check_intake_physics_v7.gd')}
    (OUT/(name+'-launch.json')).write_text(json.dumps(launch,indent=2)+'\n')
    assert result.returncode==0 and raw.get('passed'),(name,raw.get('failures'),log)
    return raw

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--headless-only',action='store_true');a=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    frozen=sha(ROOT/'scenes/campaign/pale_ward_01.tscn')
    results={'headless-60':run('headless-60',['--headless','--fixed-fps','60'])}
    if not a.headless_only:
        for fps in [30,60,120]:
            results[f'render-{fps}']=run(f'render-{fps}',['--rendering-method','gl_compatibility','--max-fps',str(fps),'--disable-vsync','--no-focus','--position','20000,20000','--resolution','320x180','--audio-driver','Dummy'])
    comparisons=[]
    if not a.headless_only:
        reference=results['render-60']['walks']
        for fps in [30,120]:
            for expected,actual in zip(reference,results[f'render-{fps}']['walks'],strict=True):
                item={'rate':fps,'link':expected['link'],'key':expected['key'],'reverse':expected['reverse'],'ticks_delta':actual['ticks']-expected['ticks'],'terminal_xz_difference':sum((actual['terminal'][i]-expected['terminal'][i])**2 for i in [0,2])**.5,'same_success':actual['reached']==expected['reached'] and actual['grounded']==expected['grounded']}
                comparisons.append(item)
                assert item['same_success'] and abs(item['ticks_delta'])<=1 and item['terminal_xz_difference']<.15,item
    assert frozen==sha(ROOT/'scenes/campaign/pale_ward_01.tscn'),'Scene changed during isolated physics checks'
    summary={'passed':True,'scene_sha256':frozen,'fixture_sha256':sha(ROOT/'tools/check_intake_physics_v7.gd'),'runner_sha256':sha(Path(__file__)),'runs':{name:{'checks':r['checks'],'walks':len(r['walks']),'rays':r['ray_queries'],'shapes':r['shape_queries'],'display_server':r['display_server'],'physics_rate':r['physics_rate'],'reported_average_fps':r['reported_average_fps']} for name,r in results.items()},'render_rate_comparisons':comparisons,'scope':('Headless production CharacterBody fixed60 isolated geometry checks only.' if a.headless_only else 'Actual production player input with fixed 60 Hz physics and actual 30/60/120 FPS native Compatibility render caps; no-focus windows positioned away from the user screen. Independent initial placements and all access/trap doors activated before probes. This is not campaign progression or live enemy proof.')}
    if comparisons:
        summary['maximum_tick_difference']=max(abs(x['ticks_delta']) for x in comparisons)
        summary['maximum_terminal_xz_difference']=max(x['terminal_xz_difference'] for x in comparisons)
    matrix=OUT/'lift-matrix.json'
    if matrix.exists():
        matrix_data=json.loads(matrix.read_text())
        assert not matrix_data['hazards'] and not matrix_data['errors']
        summary['lift_matrix']={'receipt':'lift-matrix.json','sha256':sha(matrix),'maps':len(matrix_data['levels']),'lifts':sum(len(level['lifts']) for level in matrix_data['levels']),'hazards':len(matrix_data['hazards']),'fixture_errors':len(matrix_data['errors']),'exit_warning':'4 leaked ObjectDB instances and 1 resource still in use; process exit 0. Raw log retained.'}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
