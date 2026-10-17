#!/usr/bin/env python3
"""Exact six-actor Intake staff placement patch. Dry run by default; no author import."""
from __future__ import annotations
import argparse,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CONTRACT=ROOT/'docs/production-v11/placements.json'
def digest(value):return hashlib.sha256(value).hexdigest()
def patch(text,contract):
 records=[];output=text
 for item in contract['placements']:
  old=item['expected_original_block']
  assert digest(old.encode())==item['block_sha256'],'Sealed original marker block changed'
  new=old.replace('metadata/kind = "'+item['kind']+'"','metadata/kind = "'+item['new_kind']+'"',1)
  assert old!=new
  pattern=r'^\[node name="'+re.escape(item['marker'])+r'"[^\n]*\]\n.*?(?=^\[node|\Z)'
  matches=list(re.finditer(pattern,output,re.M|re.S))
  assert len(matches)==1,'Missing/duplicate target '+item['marker']
  actual=matches[0].group()
  assert actual in (old,new),'Unexpected target properties '+item['marker']
  if actual==old:output=output[:matches[0].start()]+new+output[matches[0].end():]
  records.append({'marker':item['marker'],'before_kind':item['kind'],'after_kind':item['new_kind'],'changed':actual==old})
 # Reverse only approved changes to prove all other scene bytes are preserved.
 reverse=output
 for item in contract['placements']:
  old=item['expected_original_block'];new=old.replace('metadata/kind = "'+item['kind']+'"','metadata/kind = "'+item['new_kind']+'"',1)
  original_match=re.search(r'^\[node name="'+re.escape(item['marker'])+r'"[^\n]*\]\n.*?(?=^\[node|\Z)',text,re.M|re.S).group()
  reverse=reverse.replace(new,original_match,1)
 assert reverse==text,'Unapproved scene mutation'
 return output,records
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
 contract=json.loads(CONTRACT.read_text());path=ROOT/contract['scene'];before=path.read_text();after,records=patch(before,contract)
 again,_=patch(after,contract);assert again==after,'Non-idempotent patch'
 if args.apply and before!=after:path.write_text(after)
 print(json.dumps({'status':'passed','applied':args.apply,'changed':before!=after,'scene':contract['scene'],'before_sha256':digest(before.encode()),'after_sha256':digest(after.encode()),'placements':records,'preserved':'All other scene bytes;36 actor transforms/markers/activation/arena membership, all resources and other maps.'},indent=2))
if __name__=='__main__':main()
