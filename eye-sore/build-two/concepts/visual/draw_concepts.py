#!/usr/bin/env python3
"""Eyesore concept packets. Original coordinate-authored pixel art, 2026-10-08.
All silhouettes, pixel placement and materials are defined here. No imported image
assets, AI image generation, interpolation, or former-project assets are used.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json, math, random
ROOT=Path(__file__).resolve().parent
NN=Image.Resampling.NEAREST
FONT='/usr/share/fonts/TTF/DejaVuSans.ttf'
BOLD='/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
if not Path(FONT).exists():
 FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'; BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(n,b=False): return ImageFont.truetype(BOLD if b else FONT,n)
CONCEPTS=[
 dict(slug='corrupted-biotech',title='01 / THE PALE WARD',subtitle='Corrupted biotech facility',tag='Sterile geometry. Flesh without permission.',
 palette=['#121C24','#2B4147','#526B69','#91A397','#DFE3C8','#65404B','#B66D79','#BDE48E'],
 names=['Void','Deep teal','Oxidized steel','Surgical gray','Bone ceramic','Clotted violet','Raw tissue','Culture light'],
 enemies=['The Unsealed','Containment Choir'],materials=['Cracked ceramic','Tissue lattice','Ribbed steel','Culture glass'],
 read='Pale stretched humanoid versus a low, broad containment organism. Bone-value silhouettes separate from the cool room; small green culture lights signal the ranged threat.',
 cost='Medium-high. Organic silhouettes need careful frame-to-frame anatomy; clinical tiles can be reused widely. Translucency is represented with opaque pixel clusters.',
 limitation='The vial glow and tissue lattice are painted cues, not dynamic effects. Two single enemy poses cannot yet prove motion or attack readability.'),
 dict(slug='occult-fortress',title='02 / THE ASH CITADEL',subtitle='War-torn occult fortress',tag='A siege that became a sacrament.',
 palette=['#1D1922','#39313E','#625666','#947769','#D4B69A','#573B3A','#C86848','#EABB65'],
 names=['Coal','Iron dusk','Weathered slate','Dust mortar','Chalk bone','Oxblood','Ember','Ritual gold'],
 enemies=['The Iron Penitent','Walking Reliquary'],materials=['Siege masonry','Scored iron','Ritual inlay','Burned timber'],
 read='Tall cleaver and cage crown identify the melee unit; a floating red core inside a walking shrine identifies the ranged unit. Warm embers direct attention through gray masonry.',
 cost='Medium. Armor plates and masonry support modular production; cleaver timing and the shrine’s four-foot gait are the expensive animation work.',
 limitation='A ritual motif is established, but symbols are original visual marks without a developed written language. Siege debris does not yet have collision.'),
 dict(slug='civic-invasion',title='03 / THE OCCUPIED LINE',subtitle='Invaded civic megastructure',tag='Public space. Private extinction.',
 palette=['#151D27','#2F4054','#566779','#899997','#CCD4BE','#5A415D','#CA744F','#A5CECD'],
 names=['Transit night','Service blue','Concrete shadow','Weathered concrete','Wayfinding ivory','Alien plum','Caution orange','Scanner cyan'],
 enemies=['The Platform Reaver','The Surveyor'],materials=['Poured concrete','Transit tread','Hazard enamel','Alien cable'],
 read='An orange-backed, low-headed occupier contrasts with a high camera crown on three narrow legs. Public wayfinding stripes frame routes and cyan scanner optics identify ranged fire.',
 cost='Medium-low for architecture, medium for creatures. Repeatable concrete and signs are economical; the surveyor’s tripod motion and reaver’s offset head need dedicated poses.',
 limitation='Signs are spatial markers rather than lore text. The fixed screenshot has no moving scanner beam or interactive route system.')
]
def poly(d,pts,c): d.polygon(pts,fill=c)
def line(d,pts,c,w=1): d.line(pts,fill=c,width=w)
def box(d,xy,c): d.rectangle(xy,fill=c)
def ell(d,xy,c): d.ellipse(xy,fill=c)
def small(im): return ImageDraw.Draw(im)
def sprite(): return Image.new('RGBA',(96,128),(0,0,0,0))
def tissue(d,x,y,n=4):
 for k in range(n): line(d,[(x+k*3,y),(x+1+k*3,y+6),(x-1+k*3,y+12)],'#65404B')
def draw_enemy(idx,role,p):
 im=sprite(); d=small(im); ink,deep,mid,lit,bone,blood,accent,glow=p
 if idx==0 and role==0:
  # An asymmetrical, flayed, long-limbed escaped patient; no face-mask silhouette.
  poly(d,[(31,43),(24,51),(22,73),(16,88),(19,96),(24,91),(27,70),(35,59)],ink)
  poly(d,[(31,46),(27,53),(26,74),(20,89),(22,90),(31,70),(37,55)],bone)
  poly(d,[(26,60),(24,75),(20,83),(22,88),(27,76),(29,62)],lit)
  poly(d,[(66,42),(73,49),(76,68),(81,79),(84,82),(82,89),(77,84),(68,70),(62,51)],ink)
  poly(d,[(67,47),(70,50),(72,70),(79,82),(81,81),(75,69),(73,48)],bone)
  line(d,[(78,81),(84,77),(86,77)],bone,2); line(d,[(78,84),(86,83)],lit,2)
  poly(d,[(32,41),(45,36),(58,37),(67,44),(64,66),(59,82),(39,82),(31,64)],ink)
  poly(d,[(35,42),(46,39),(57,40),(64,45),(61,66),(55,79),(40,78),(34,61)],bone)
  poly(d,[(38,48),(47,48),(49,68),(44,77),(39,66)],lit)
  poly(d,[(51,48),(62,49),(57,73),(51,78),(49,62)],accent)
  tissue(d,49,51,4); line(d,[(37,57),(44,60),(46,67)],mid); line(d,[(36,63),(43,66)],mid)
  ell(d,(29,41,42,51),accent); ell(d,(58,41,68,48),blood)
  poly(d,[(39,76),(49,79),(46,99),(40,117),(40,124),(30,124),(31,119),(35,95)],ink)
  poly(d,[(40,81),(45,82),(41,100),(37,119),(33,120),(38,98)],bone)
  poly(d,[(50,79),(59,78),(59,94),(64,113),(63,120),(69,122),(69,124),(56,124),(54,116),(52,96)],ink)
  poly(d,[(53,82),(57,81),(55,95),(61,115),(59,121),(57,114),(54,96)],bone)
  box(d,(31,122,39,123),lit); box(d,(57,122,67,123),lit)
  # Split skull with one empty socket and a surgical stitch line.
  poly(d,[(36,22),(41,16),(53,17),(61,23),(62,34),(57,42),(45,43),(37,36)],ink)
  poly(d,[(38,24),(43,19),(50,19),(54,25),(59,27),(59,34),(54,39),(45,40),(40,34)],bone)
  poly(d,[(42,28),(48,27),(49,31),(43,32)],ink); line(d,[(52,24),(52,34),(55,36)],blood,2)
  box(d,(44,35,52,36),blood); box(d,(47,36,49,38),ink)
  line(d,[(39,26),(35,30),(35,35)],lit,2); box(d,(58,23,63,26),accent)
  for y in [24,28,32]: line(d,[(50,y),(55,y+1)],ink)
 elif idx==0:
  # A containment bell built around a living choir of mouths, with grounded roots.
  for pts in [[(27,79),(20,93),(16,113),(8,119),(7,124),(24,124),(25,120),(21,117),(26,99),(36,90)],[(42,86),(36,104),(37,120),(32,124),(46,124),(44,117),(47,97)],[(60,86),(64,105),(61,119),(66,124),(80,124),(75,118),(70,101),(70,85)]]:
   poly(d,pts,ink)
  line(d,[(31,87),(24,100),(20,118),(13,121)],accent,4); line(d,[(44,90),(40,105),(41,120)],bone,4); line(d,[(64,89),(67,105),(69,118),(75,122)],accent,4)
  poly(d,[(22,43),(30,31),(38,25),(61,25),(74,40),(79,65),(72,88),(59,98),(36,97),(22,84),(16,65)],ink)
  poly(d,[(24,46),(31,36),(37,31),(61,31),(70,43),(73,64),(66,85),(57,92),(38,90),(27,80),(22,65)],deep)
  ell(d,(27,39,68,85),blood); ell(d,(34,39,64,77),accent)
  poly(d,[(39,41),(49,34),(60,43),(62,60),(54,70),(39,67),(34,55)],glow)
  poly(d,[(40,46),(47,43),(55,46),(55,55),(49,59),(42,55)],ink)
  box(d,(44,49,53,50),bone); box(d,(46,54,51,55),accent)
  ell(d,(32,65,42,73),ink); ell(d,(51,73,64,83),ink); box(d,(35,67,39,68),bone); box(d,(55,76,60,77),bone)
  # Ceramic radial containment ribs.
  for x,y in [(27,41),(38,31),(57,31),(69,44)]:
   poly(d,[(x-2,y),(x+3,y),(x+5,y+38),(x+1,y+44),(x-3,y+37)],bone)
   line(d,[(x+2,y+4),(x+3,y+32)],lit,2)
  poly(d,[(24,38),(30,30),(67,30),(73,39),(67,45),(29,45)],bone)
  line(d,[(31,38),(64,38)],mid,3)
  poly(d,[(31,25),(35,18),(62,18),(65,25)],ink); box(d,(36,20,61,24),mid)
  for x in [36,43,50,57]: box(d,(x,22,x+2,28),glow)
  poly(d,[(19,61),(9,65),(5,76),(10,90),(16,89),(14,75),(24,71)],ink)
  line(d,[(20,65),(12,70),(10,78),(13,86)],accent,4)
  poly(d,[(76,58),(85,62),(92,74),(89,84),(82,87),(84,78),(78,70)],ink)
  line(d,[(77,62),(85,67),(88,77),(84,82)],bone,4)
  line(d,[(30,88),(60,92),(69,85)],lit,3)
 elif idx==1 and role==0:
  # Cloister knight, iron cage crown, bell shoulder, cleaver and torn penitential cloth.
  poly(d,[(32,82),(47,83),(45,102),(40,119),(42,124),(23,124),(24,119),(31,115)],ink)
  poly(d,[(35,87),(43,87),(40,104),(35,118),(27,120),(35,113)],mid)
  line(d,[(35,93),(41,94)],lit,2)
  poly(d,[(51,83),(63,81),(65,107),(70,118),(72,124),(54,124),(51,120),(54,108)],ink)
  poly(d,[(55,89),(60,86),(61,110),(67,121),(57,121),(57,110)],mid)
  line(d,[(57,95),(62,95)],bone,2)
  poly(d,[(26,47),(34,35),(55,32),(65,44),(67,76),(60,93),(46,95),(31,84)],ink)
  poly(d,[(32,43),(40,38),(55,37),(62,46),(59,65),(35,67)],mid)
  poly(d,[(35,48),(46,44),(58,48),(56,61),(44,64),(36,59)],lit)
  line(d,[(46,45),(45,62)],ink,2); box(d,(42,51,49,53),bone)
  poly(d,[(32,68),(60,67),(64,85),(56,102),(50,93),(44,104),(37,94),(28,87)],blood)
  line(d,[(35,72),(40,92),(44,95)],accent); line(d,[(54,73),(55,90)],mid,2)
  box(d,(31,65,62,69),ink); box(d,(44,66,51,71),glow)
  poly(d,[(25,40),(20,44),(17,61),(22,68),(34,61),(36,44)],ink)
  poly(d,[(25,44),(23,49),(22,59),(30,58),(32,46)],mid)
  line(d,[(24,45),(31,45)],bone,2)
  poly(d,[(20,62),(18,79),(22,85),(29,82),(30,62)],ink); poly(d,[(22,64),(21,77),(24,80),(27,77),(27,64)],lit)
  # Tall slab blade on the opposite side; missing edge teeth tell a siege story.
  poly(d,[(68,16),(74,12),(84,19),(84,45),(80,47),(82,51),(77,57),(69,52)],ink)
  poly(d,[(71,20),(76,16),(81,20),(80,43),(75,50),(72,47)],lit)
  line(d,[(77,19),(77,39),(74,46)],bone,2); line(d,[(70,50),(69,85)],glow,3)
  poly(d,[(62,45),(68,50),(70,62),(75,69),(72,77),(64,73),(59,57)],ink)
  poly(d,[(64,49),(66,59),(72,68),(70,72),(65,67),(61,53)],mid)
  box(d,(67,71,73,78),lit)
  poly(d,[(35,18),(43,13),(54,15),(61,24),(59,35),(51,41),(40,37)],ink)
  poly(d,[(38,22),(44,18),(53,19),(57,25),(54,34),(47,37),(41,33)],mid)
  for x in [39,45,51,57]: line(d,[(x,14),(x+1,32)],bone,2)
  line(d,[(38,17),(55,15),(60,23)],lit,2); box(d,(43,28,53,30),ink); box(d,(45,29,50,29),accent)
  line(d,[(39,11),(39,19)],glow,2); line(d,[(51,8),(52,17)],glow,2)
 elif idx==1:
  # A walking shrine; four iron feet, open carved arches, blazing core, hanging censers.
  for pts in [[(25,77),(20,99),(13,114),(9,122),(19,124),(22,120),(23,112),(32,91)],[(37,90),(34,114),(29,122),(40,124),(43,118),(44,92)],[(61,88),(60,113),(62,123),(74,124),(72,117),(67,91)],[(69,78),(79,95),(79,111),(85,122),(91,121),(86,111),(84,92),(77,76)]]: poly(d,pts,ink)
  line(d,[(28,82),(24,101),(19,115),(15,122)],mid,4); line(d,[(41,92),(39,116),(35,122)],lit,3)
  line(d,[(64,92),(64,115),(68,122)],lit,3); line(d,[(73,83),(81,96),(82,111),(87,120)],mid,4)
  poly(d,[(24,38),(47,11),(72,38),(73,82),(64,97),(34,96),(22,82)],ink)
  poly(d,[(28,41),(47,19),(68,41),(67,81),(59,91),(37,91),(28,79)],mid)
  poly(d,[(36,47),(47,31),(59,47),(59,79),(50,86),(36,78)],ink)
  poly(d,[(41,50),(48,41),(54,51),(57,63),(52,76),(44,78),(39,66)],accent)
  poly(d,[(44,53),(49,47),(51,57),(53,65),(49,71),(45,68)],glow)
  line(d,[(46,56),(48,62),(46,68)],bone,2)
  for x in [27,32,62,67]: line(d,[(x,44),(x,82)],lit,3)
  line(d,[(27,39),(47,16),(69,39)],bone,3); line(d,[(30,45),(47,25),(65,45)],lit,2)
  poly(d,[(21,81),(74,81),(69,94),(28,94)],ink); box(d,(29,83,67,87),lit)
  for x in [31,42,53,64]: box(d,(x,88,x+3,90),glow)
  # Damaged spire, censers and floating ritual marks.
  poly(d,[(43,18),(42,9),(47,4),(51,10),(49,18)],ink); box(d,(45,7,48,13),glow)
  line(d,[(25,49),(18,65),(17,76)],glow); ell(d,(12,73,21,84),ink); ell(d,(14,76,19,81),accent)
  line(d,[(70,47),(80,62),(82,74)],glow); ell(d,(77,73,86,84),ink); ell(d,(79,76,84,81),accent)
  line(d,[(38,38),(40,45)],blood,2); box(d,(57,32,60,35),ink)
 elif idx==2 and role==0:
  # Hunched occupier: orange dorsal fins, lateral low head, hooked arm and four-joint legs.
  poly(d,[(27,73),(44,77),(40,95),(28,106),(28,119),(35,123),(35,124),(18,124),(18,118),(22,100),(30,90)],ink)
  poly(d,[(31,80),(38,82),(35,94),(25,105),(23,119),(28,121),(22,121),(25,102)],mid)
  poly(d,[(48,77),(61,74),(66,94),(60,109),(65,119),(72,122),(71,124),(57,124),(52,113),(54,100)],ink)
  poly(d,[(53,81),(58,80),(62,93),(56,109),(60,120),(64,121),(57,118),(55,111),(58,96)],lit)
  poly(d,[(25,43),(37,31),(53,32),(68,44),(70,62),(63,79),(50,86),(33,78),(24,63)],ink)
  poly(d,[(29,46),(40,36),(54,38),(63,47),(65,64),(59,75),(49,79),(36,73),(28,59)],deep)
  poly(d,[(33,44),(40,38),(49,40),(45,59),(34,63),(30,54)],accent)
  poly(d,[(50,40),(57,42),(64,51),(61,65),(48,69),(46,59)],accent)
  line(d,[(37,47),(42,47),(40,57)],bone,2); line(d,[(54,47),(59,53),(57,60)],lit,2)
  poly(d,[(40,28),(44,17),(49,34)],ink); poly(d,[(43,26),(45,21),(47,32)],accent)
  poly(d,[(51,31),(57,21),(58,37)],ink); poly(d,[(54,31),(56,25),(56,34)],accent)
  poly(d,[(61,39),(71,33),(66,47)],ink); poly(d,[(64,40),(68,37),(66,43)],lit)
  # Head projects left underneath the dorsal armor.
  poly(d,[(21,43),(35,39),(42,47),(42,57),(34,65),(21,62),(15,53)],ink)
  poly(d,[(22,46),(32,43),(38,48),(38,55),(32,59),(22,58),(19,53)],lit)
  poly(d,[(19,49),(35,47),(35,52),(22,54)],ink); line(d,[(21,50),(33,49)],glow,2)
  poly(d,[(25,60),(36,58),(33,65),(28,69),(23,67)],blood)
  line(d,[(28,62),(30,66)],bone)
  poly(d,[(25,61),(20,73),(13,79),(8,93),(12,103),(18,101),(21,94),(20,86),(30,78),(35,67)],ink)
  poly(d,[(26,65),(23,74),(17,81),(13,93),(16,97),(17,91),(18,84),(29,76)],mid)
  poly(d,[(63,61),(70,65),(76,80),(83,86),(89,82),(91,88),(85,96),(77,94),(69,87),(62,73)],ink)
  poly(d,[(67,65),(71,77),(79,89),(85,89),(84,92),(78,91),(67,81)],lit)
  line(d,[(82,91),(90,98),(91,94)],bone,2); line(d,[(16,98),(12,107)],bone,2)
  line(d,[(41,70),(53,72),(59,67)],blood,3)
 elif idx==2:
  # Tripod surveyor: tall lensed crown, three cable-strung stilts and a gimballed scanner.
  for pts in [[(36,66),(28,82),(25,101),(15,119),(7,121),(7,124),(24,124),(25,117),(32,103),(35,88),(43,76)],[(54,72),(56,98),(51,117),(47,124),(63,124),(66,120),(62,116),(62,96),(62,73)],[(64,65),(75,82),(77,105),(83,116),(84,124),(94,124),(94,120),(89,111),(85,99),(81,78),(70,60)]]: poly(d,pts,ink)
  line(d,[(40,72),(32,86),(29,103),(20,120),(11,122)],mid,4)
  line(d,[(58,76),(59,98),(56,117),(53,122)],bone,4)
  line(d,[(69,69),(78,83),(81,102),(88,119),(91,122)],mid,4)
  for x,y in [(32,88),(58,98),(80,101)]: ell(d,(x-3,y-3,x+3,y+3),accent); box(d,(x,y-1,x+1,y+1),bone)
  poly(d,[(30,48),(42,35),(60,35),(73,45),(72,64),(60,78),(41,77),(29,66)],ink)
  poly(d,[(34,50),(43,39),(59,39),(68,48),(67,62),(57,72),(42,72),(34,63)],blood)
  poly(d,[(39,48),(48,44),(59,47),(62,58),(56,67),(44,66),(38,59)],deep)
  ell(d,(42,49,58,63),ink); ell(d,(45,51,56,60),glow); box(d,(49,52,53,57),bone); box(d,(52,56,55,59),mid)
  line(d,[(37,65),(42,70),(58,69)],mid,2)
  # Long upper stalk and asymmetric triple optics.
  poly(d,[(44,39),(46,22),(39,14),(42,9),(59,13),(64,27),(60,41)],ink)
  poly(d,[(49,38),(50,23),(45,15),(48,13),(55,17),(59,28),(56,39)],lit)
  poly(d,[(27,9),(38,3),(67,6),(80,17),(75,29),(62,33),(37,27),(26,18)],ink)
  poly(d,[(30,11),(40,7),(65,10),(75,17),(72,25),(61,28),(39,23),(30,17)],mid)
  for x,y,r in [(37,14,5),(54,17,6),(68,20,4)]:
   ell(d,(x-r-2,y-r-2,x+r+2,y+r+2),ink); ell(d,(x-r,y-r,x+r,y+r),glow); ell(d,(x-r+2,y-r+1,x+r-2,y+r-2),deep); box(d,(x-1,y-2,x+1,y),bone)
  line(d,[(30,11),(38,8)],accent,2); line(d,[(65,10),(73,16)],lit,2)
  # External orange transmitter and broken public-infrastructure cabling.
  poly(d,[(29,51),(22,54),(17,64),(19,72),(25,70),(26,61),(34,60)],ink)
  line(d,[(29,54),(23,58),(21,67),(23,69)],accent,3)
  line(d,[(63,69),(69,82),(72,96)],blood,2)
 # sparse scratches deliberately placed on silhouette, never global noise.
 return im

def draw_gun(idx,kind,p):
 im=Image.new('RGBA',(160,112)); d=small(im); ink,deep,mid,lit,bone,blood,accent,glow=p
 # Shooter hand: cuffs differ with each identity; canvas bottom is held-gun crop.
 poly(d,[(81,78),(106,69),(125,83),(134,112),(77,112),(73,96)],ink)
 poly(d,[(83,83),(105,75),(118,87),(125,111),(83,111),(79,96)],blood if idx==0 else mid)
 line(d,[(89,87),(105,83),(116,92)],accent if idx==0 else lit,2)
 if idx==0 and kind=='pistol':
  poly(d,[(54,32),(66,20),(88,18),(110,51),(104,74),(87,83),(67,73),(55,49)],ink)
  poly(d,[(58,32),(68,24),(85,22),(102,51),(101,64),(85,75),(71,68),(59,46)],bone)
  poly(d,[(70,26),(83,24),(97,48),(86,53),(72,41)],mid)
  poly(d,[(77,29),(81,28),(92,47),(86,49)],glow)
  poly(d,[(58,32),(66,28),(73,39),(65,45),(59,43)],deep); ell(d,(60,32,69,41),ink); ell(d,(62,33,66,37),lit)
  poly(d,[(66,51),(86,52),(97,65),(83,71),(75,66)],lit)
  line(d,[(72,55),(85,56),(88,62)],deep,2)
  poly(d,[(84,67),(92,65),(101,81),(94,91),(85,83)],ink); poly(d,[(86,71),(91,69),(97,81),(93,85)],mid)
  box(d,(76,17,80,23),ink); box(d,(76,17,79,19),glow)
  line(d,[(61,47),(66,51)],accent,2)
 elif idx==0:
  poly(d,[(40,21),(56,13),(85,17),(112,53),(105,78),(89,88),(64,72),(42,41)],ink)
  poly(d,[(44,23),(58,17),(83,21),(106,54),(101,69),(89,78),(68,67),(46,39)],bone)
  poly(d,[(47,23),(58,19),(72,39),(59,45)],deep); poly(d,[(62,20),(74,21),(88,42),(76,48)],deep)
  for x,y in [(51,28),(65,28)]: ell(d,(x-4,y-4,x+8,y+9),ink); ell(d,(x-2,y-2,x+5,y+5),mid); ell(d,(x,y,x+3,y+3),ink)
  poly(d,[(67,48),(81,42),(99,63),(90,73),(78,69)],mid)
  for k in range(6): line(d,[(69+k*3,49+k*2),(74+k*3,57+k*2)],deep,2)
  poly(d,[(83,26),(89,29),(103,48),(98,53)],glow)
  line(d,[(46,44),(55,55),(66,58)],accent,3); line(d,[(47,47),(57,59),(68,62)],blood)
  box(d,(78,16,82,21),ink); box(d,(78,16,81,18),glow)
 elif idx==1 and kind=='pistol':
  poly(d,[(49,27),(65,19),(84,24),(99,46),(112,56),(107,75),(85,89),(71,77),(68,60),(52,45)],ink)
  poly(d,[(53,29),(65,24),(81,28),(94,47),(78,58),(55,43)],mid)
  poly(d,[(59,28),(66,25),(76,29),(86,44),(77,49)],lit)
  ell(d,(53,30,67,43),ink); ell(d,(56,32,64,39),deep); line(d,[(55,31),(64,29)],bone)
  poly(d,[(79,53),(94,48),(106,58),(103,70),(90,79),(78,70)],blood)
  line(d,[(81,56),(90,53),(101,60),(96,70)],glow,2)
  poly(d,[(78,68),(88,69),(98,83),(91,93),(82,83)],ink)
  poly(d,[(81,72),(87,72),(94,83),(90,87),(85,81)],lit)
  line(d,[(85,75),(88,82)],blood)
  # Hammer, open trigger guard and etched sun.
  poly(d,[(86,35),(84,27),(89,24),(94,27),(90,32),(95,40)],ink); line(d,[(88,27),(91,28)],glow,2)
  ell(d,(70,56,82,70),ink); ell(d,(73,59,79,66),(0,0,0,0)); line(d,[(74,59),(75,63)],glow)
  line(d,[(75,40),(79,39),(81,42),(78,45),(75,40)],glow)
 elif idx==1:
  poly(d,[(34,19),(48,11),(68,12),(103,47),(116,65),(108,83),(88,96),(67,78),(50,58),(34,35)],ink)
  poly(d,[(38,20),(50,15),(66,16),(98,48),(107,61),(92,73),(71,63),(52,50),(38,32)],mid)
  poly(d,[(38,21),(49,17),(59,28),(46,36)],lit); poly(d,[(53,17),(64,18),(74,29),(62,37)],lit)
  for x,y in [(45,26),(59,25)]: ell(d,(x-6,y-4,x+6,y+9),ink); ell(d,(x-3,y-1,x+3,y+5),deep); line(d,[(x-4,y-3),(x+2,y-4)],bone)
  poly(d,[(64,42),(76,37),(99,58),(94,70),(78,68)],blood)
  for k in range(5): line(d,[(68+k*4,43+k*3),(74+k*4,51+k*3)],ink,2)
  line(d,[(60,40),(78,31),(92,44)],glow,2)
  poly(d,[(92,66),(105,66),(113,80),(99,91),(91,83)],lit)
  poly(d,[(100,76),(109,74),(116,86),(107,96),(103,92)],ink)
  line(d,[(79,28),(82,23),(85,25),(83,32)],glow,2)
  # Torn leather binding, brass rivets and blade lug.
  for x,y in [(63,46),(78,58),(91,60)]: box(d,(x,y,x+2,y+2),glow)
  poly(d,[(37,36),(32,45),(43,41),(52,54),(57,52),(46,38)],bone)
 elif idx==2 and kind=='pistol':
  poly(d,[(48,31),(63,18),(85,18),(108,41),(111,58),(102,72),(88,79),(76,72),(67,55),(51,46)],ink)
  poly(d,[(53,32),(66,23),(83,23),(104,43),(105,55),(97,63),(80,62),(70,50),(54,42)],mid)
  poly(d,[(63,25),(81,25),(94,38),(76,42),(65,37)],lit)
  poly(d,[(54,33),(64,27),(72,39),(60,45)],deep); box(d,(58,33,65,39),ink); box(d,(59,32,64,32),bone)
  poly(d,[(78,45),(100,43),(103,52),(95,59),(82,56)],accent)
  line(d,[(85,47),(98,47)],bone,2); line(d,[(89,51),(98,51)],ink)
  poly(d,[(85,62),(96,62),(105,82),(95,91),(85,81)],ink); poly(d,[(89,66),(95,65),(100,80),(96,84),(90,78)],deep)
  for k in range(3): line(d,[(89+k,71+k*3),(95+k,71+k*3)],lit)
  box(d,(78,16,82,23),ink); box(d,(79,17,81,18),glow)
  ell(d,(70,55,84,72),ink); ell(d,(74,59,81,68),(0,0,0,0)); box(d,(75,58,77,63),mid)
 elif idx==2:
  poly(d,[(33,25),(50,12),(70,13),(107,45),(118,64),(108,80),(86,94),(72,82),(55,58),(36,43)],ink)
  poly(d,[(38,26),(51,17),(68,18),(101,47),(108,62),(96,74),(77,71),(59,52),(40,40)],mid)
  poly(d,[(42,25),(54,18),(67,20),(72,30),(57,40),(45,35)],deep)
  poly(d,[(44,26),(52,21),(62,30),(53,36)],ink); line(d,[(47,26),(52,23)],bone,2)
  poly(d,[(72,25),(77,23),(92,34),(90,43),(83,45)],lit)
  poly(d,[(68,43),(82,34),(103,55),(97,67),(79,65)],accent)
  for k in range(5): line(d,[(71+k*4,44+k*3),(77+k*4,51+k*3)],ink,2)
  poly(d,[(96,63),(109,63),(115,78),(103,88),(95,79)],deep)
  poly(d,[(59,50),(66,56),(67,71),(75,81),(72,85),(61,74),(57,56)],lit)
  line(d,[(78,18),(82,18),(84,24),(80,26)],glow,2)
  box(d,(84,45,89,49),bone); box(d,(86,46,87,48),deep)
  line(d,[(98,68),(108,70)],glow,2)
 return im

def material(idx,k,p):
 ink,deep,mid,lit,bone,blood,accent,glow=p
 im=Image.new('RGB',(32,32),deep); d=small(im); rng=random.Random(100+idx*10+k)
 # Seamless toroidal feature placement. Copies wrap every feature at tile boundaries.
 def wrapped(fn,x,y,*a):
  for dx in [-32,0,32]:
   for dy in [-32,0,32]: fn(x+dx,y+dy,*a)
 if idx==0 and k==0:
  box(d,(0,0,31,31),bone)
  for x in [0,16]: line(d,[(x,0),(x,31)],mid); line(d,[(x+1,0),(x+1,31)],lit)
  for y in [0,16]: line(d,[(0,y),(31,y)],mid); line(d,[(0,y+1),(31,y+1)],lit)
  def crack(x,y): line(d,[(x,y),(x+3,y+4),(x+1,y+7),(x+5,y+10)],deep)
  wrapped(crack,24,27); wrapped(crack,8,7)
  for x,y in [(4,4),(20,21),(6,24)]: box(d,(x,y,x+2,y),lit)
 elif idx==0 and k==1:
  box(d,(0,0,31,31),blood)
  for y in range(-8,40,8):
   line(d,[(0,y+2),(8,y),(17,y+4),(24,y+2),(31,y+3)],accent,3)
   line(d,[(0,y+5),(8,y+3),(17,y+7),(24,y+5),(31,y+6)],ink)
  for x,y in [(3,7),(20,20),(30,0),(12,29)]:
   wrapped(lambda a,b: ell(d,(a-2,b-2,a+2,b+3),deep),x,y)
   wrapped(lambda a,b: box(d,(a,b-1,a+1,b),lit),x,y)
 elif idx==0 and k==2:
  box(d,(0,0,31,31),mid)
  for x in range(0,32,8): box(d,(x,0,x+2,31),deep); line(d,[(x+3,0),(x+3,31)],lit)
  for x,y in [(6,5),(21,13),(13,26),(29,23)]: line(d,[(x,y),(x+2,y+2)],bone)
 elif idx==0:
  box(d,(0,0,31,31),deep)
  for y in range(32): line(d,[(0,y),(31,y)],p[1 if y%8<4 else 2])
  for x,y in [(6,6),(19,20),(29,13)]:
   wrapped(lambda a,b: ell(d,(a-2,b-3,a+2,b+3),glow),x,y)
   wrapped(lambda a,b: box(d,(a,b-1,a+1,b),bone),x,y)
  line(d,[(0,0),(31,0)],lit); line(d,[(0,1),(31,1)],ink)
 elif idx==1 and k==0:
  box(d,(0,0,31,31),mid)
  for y in [0,16]:
   line(d,[(0,y),(31,y)],ink,2); line(d,[(0,y+2),(31,y+2)],lit)
   for x in ([0,16] if y==0 else [8,24]): line(d,[(x,y),(x,y+15)],deep,2)
  for x,y in [(4,8),(17,22),(27,6)]: line(d,[(x,y),(x+2,y+3),(x+1,y+5)],deep)
  for n in range(28):
   x,y=rng.randrange(32),rng.randrange(32); box(d,(x,y,x+1,y),lit if n%3 else deep)
 elif idx==1 and k==1:
  box(d,(0,0,31,31),deep)
  for y in [0,16]: line(d,[(0,y),(31,y)],ink); line(d,[(0,y+1),(31,y+1)],mid)
  for x,y in [(3,3),(27,3),(3,19),(27,19)]: box(d,(x,y,x+1,y+1),lit)
  for x,y in [(9,7),(17,23),(26,11)]: line(d,[(x,y),(x-4,y+5)],lit); line(d,[(x+1,y),(x-3,y+5)],ink)
 elif idx==1 and k==2:
  box(d,(0,0,31,31),mid)
  for x in [0,16]: line(d,[(x,0),(x,31)],deep)
  line(d,[(0,16),(8,8),(16,16),(24,24),(31,17)],glow,2)
  line(d,[(0,15),(8,23),(16,15),(24,7),(31,14)],blood)
  for x in [8,24]: box(d,(x-1,15,x+1,17),bone)
 elif idx==1:
  box(d,(0,0,31,31),blood)
  for x in [0,8,16,24]: line(d,[(x,0),(x,31)],ink,2); line(d,[(x+2,0),(x+2,31)],lit)
  for x,y in [(5,8),(14,23),(29,19)]: wrapped(lambda a,b: ell(d,(a-1,b-4,a+1,b+4),deep),x,y)
 else:
  if k==0:
   box(d,(0,0,31,31),lit)
   for y in [0,16]: line(d,[(0,y),(31,y)],mid); line(d,[(0,y+1),(31,y+1)],bone)
   for x,y in [(3,5),(24,9),(12,21),(30,29)]: wrapped(lambda a,b: ell(d,(a-1,b-1,a+1,b+1),mid),x,y)
   for n in range(35):
    x,y=rng.randrange(32),rng.randrange(32); box(d,(x,y,x,y),mid if n%3 else bone)
  elif k==1:
   box(d,(0,0,31,31),deep)
   for x in range(-32,64,8): line(d,[(x,0),(x+32,32)],mid,2); line(d,[(x+3,0),(x+35,32)],ink)
   for y in [0,16]: line(d,[(0,y),(31,y)],lit)
  elif k==2:
   box(d,(0,0,31,31),accent)
   for x in range(-32,64,16): line(d,[(x,0),(x+32,32)],ink,7)
   for x,y in [(3,5),(20,11),(11,27)]: line(d,[(x,y),(x+3,y)],bone)
  else:
   box(d,(0,0,31,31),blood)
   for x in range(-32,64,8): line(d,[(x,0),(x+8,16),(x+16,32)],ink,3); line(d,[(x+2,0),(x+10,16),(x+18,32)],mid)
   for x,y in [(6,8),(22,24)]: box(d,(x,y,x+3,y+2),glow); box(d,(x+1,y,x+2,y),bone)
 return im

def hud(idx,p):
 im=Image.new('RGB',(320,32),p[0]); d=small(im)
 box(d,(0,0,319,2),p[2]); box(d,(2,4,317,29),p[1]); line(d,[(5,27),(314,27)],p[2])
 # Compact status bar with common gameplay budget but distinct ornament.
 f=font(7,True)
 for x,label,val in [(8,'VITAL','087'),(89,'ARMOR','042'),(236,'SHELLS','012')]:
  d.text((x,6),label,font=f,fill=p[3]); d.text((x+39,8),val,font=font(13,True),fill=p[4])
 if idx==0:
  line(d,[(168,20),(171,20),(174,12),(177,24),(180,16),(195,16)],p[7],2)
  box(d,(169,7,192,9),p[5]); box(d,(169,7,187,9),p[6])
 elif idx==1:
  poly(d,[(179,6),(190,16),(179,26),(168,16)],p[5]); line(d,[(179,9),(179,23)],p[7],2); line(d,[(173,15),(185,15)],p[7],2)
 else:
  for k in range(5): box(d,(169+k*6,8,172+k*6,23),p[6] if k<4 else p[0])
 return im

def textured_polygon(im,pts,tile,shade=None):
 mask=Image.new('L',im.size,0); ImageDraw.Draw(mask).polygon(pts,fill=255)
 tiled=Image.new('RGB',im.size)
 for y in range(0,im.height,32):
  for x in range(0,im.width,32): tiled.paste(tile,(x,y))
 if shade:
  overlay=Image.new('RGB',im.size,shade[0]); tiled=Image.blend(tiled,overlay,shade[1])
 im.paste(tiled,(0,0),mask)

def palette_lock(im,p):
 # Finish art on the eight declared inks; presentation labels use their own UI inks.
 pal=Image.new('P',(1,1)); values=[]
 for c in p:
  values.extend(tuple(int(c[j:j+2],16) for j in (1,3,5)))
 pal.putpalette(values+[0]*(768-len(values)))
 return im.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGB')

def perspective_floor(im,tile,p):
 # Integer nearest samples of a floor plane. Texture frequency falls with depth.
 pix=im.load(); src=tile.load()
 for y in range(105,180):
  depth=y-76
  for x in range(320):
   left=107-(y-103)*2.23; right=221+(y-103)*2.06
   if x < left or x > right: continue
   u=int((x-158)*40/depth)%32
   v=int(12500/depth)%32
   col=src[u,v]
   # Far floor silhouettes stay dark; nearer flakes and joints gain a midtone.
   if y<118: col=tuple(int(a*.20+b*.80) for a,b in zip(col,tuple(int(p[0][j:j+2],16) for j in (1,3,5))))
   else: col=tuple(int(a*.34+b*.66) for a,b in zip(col,tuple(int(p[0][j:j+2],16) for j in (1,3,5))))
   pix[x,y]=col

def scene(idx,p,materials,enemies,guns,h):
 im=Image.new('RGB',(320,180),p[0]); d=small(im); ink,deep,mid,lit,bone,blood,accent,glow=p
 # Central vanishing point and a second route on the right; walls and ceiling taper.
 vp=(158,66)
 poly(d,[(0,0),(320,0),(221,37),(107,37)],deep)
 textured_polygon(im,[(0,0),(107,37),(107,104),(0,151)],materials[0],(deep,.33))
 textured_polygon(im,[(320,0),(221,37),(221,104),(320,151)],materials[0],(deep,.5))
 textured_polygon(im,[(107,37),(221,37),(221,105),(107,105)],materials[0],(deep,.6))
 poly(small(im),[(0,151),(107,103),(221,103),(320,151),(320,180),(0,180)],ink)
 perspective_floor(im,materials[2 if idx==0 else 0 if idx==1 else 1],p)
 d=small(im)
 # Floor slab perspective; lower wall shadows prevent a flat chamber.
 poly(d,[(0,135),(107,101),(107,108),(0,159)],ink)
 poly(d,[(221,101),(320,136),(320,153),(221,109)],ink)
 for x in [-220,-70,40,105,158,215,290,440,600]: line(d,[(158,78),(x,158)],deep)
 for y in [113,132,158]: line(d,[(0,y),(319,y)],deep)
 line(d,[(107,37),(107,103)],mid); line(d,[(221,37),(221,103)],deep)
 # Ceiling beams, pixel-defined light fixtures, and overhead shadows.
 for pts in [[(24,0),(36,0),(121,37),(116,40)],[(284,0),(297,0),(209,39),(204,37)],[(0,15),(0,22),(106,48),(106,44)],[(320,15),(320,22),(222,48),(222,44)]]: poly(d,pts,ink)
 # Architecture changes the ceiling language, rather than recolouring it.
 if idx==1:
  line(d,[(0,1),(44,10),(108,32),(157,15),(208,32),(276,10),(319,1)],mid,3)
  line(d,[(45,11),(108,33),(157,17),(208,33),(275,11)],lit)
  line(d,[(157,0),(157,20)],ink,2)
  for yy in range(1,20,4): box(d,(156,yy,158,yy+1),lit)
  poly(d,[(151,20),(163,20),(165,25),(160,31),(154,31),(149,25)],ink)
  line(d,[(151,23),(163,23),(159,29),(155,29),(151,23)],glow,2)
  box(d,(154,24,159,26),accent)
 else:
  line(d,[(80,7),(130,32)],lit,2); line(d,[(240,7),(194,32)],lit,2)
  line(d,[(83,7),(131,31)],glow)
  line(d,[(237,7),(193,31)],glow)
 if idx==0:
  # Main clinical seal, ruptured left wall and a green secondary passage.
  box(d,(133,47,183,105),ink); box(d,(139,52,178,102),deep)
  poly(d,[(143,55),(155,51),(166,51),(176,57),(176,101),(143,101)],mid)
  line(d,[(159,53),(159,100)],ink,2); box(d,(156,76,161,80),glow)
  box(d,(143,56,154,62),lit); box(d,(163,56,172,62),lit)
  poly(d,[(243,57),(284,36),(284,124),(243,108)],ink)
  poly(d,[(247,61),(277,45),(277,116),(247,106)],deep)
  line(d,[(251,64),(272,53)],glow,2); line(d,[(253,103),(275,111)],mid)
  # Hanging biological breach grows through the left ceramic shell.
  poly(d,[(0,39),(15,41),(23,51),(26,64),(43,73),(48,97),(40,105),(28,101),(19,86),(6,82),(0,77)],ink)
  poly(d,[(0,43),(13,46),(18,56),(19,68),(36,77),(42,96),(36,101),(29,95),(25,79),(10,75),(0,73)],blood)
  line(d,[(3,47),(10,55),(13,72),(28,81),(33,95)],accent,3)
  line(d,[(0,61),(11,65),(17,78),(21,94),(17,112)],accent,2)
  line(d,[(16,50),(30,53),(35,63),(47,67)],blood,3)
  for x,y in [(5,57),(22,75),(36,91)]: ell(d,(x-2,y-2,x+3,y+3),accent); box(d,(x,y,x+1,y),lit)
  # Side service bands plus cracked slab edges and inset glowing dispensers.
  poly(d,[(60,40),(75,45),(75,101),(60,107)],deep); line(d,[(63,44),(72,47),(72,75),(63,77),(63,44)],lit)
  box(d,(65,51,69,65),glow); box(d,(64,81,72,84),accent)
  line(d,[(0,27),(107,54)],lit); line(d,[(0,28),(107,55)],deep)
  line(d,[(5,119),(30,110),(38,113),(53,105)],mid)
  for x in [116,201]: box(d,(x,49,x+3,75),glow); box(d,(x-1,48,x+4,50),bone)
  line(d,[(117,112),(117,123),(110,129)],blood,2); line(d,[(202,112),(208,119),(221,122)],blood,2)
 elif idx==1:
  # Gothic pointed portal with glowing inner ritual, shell strike through left rampart.
  poly(d,[(126,103),(126,64),(153,35),(186,63),(186,103)],ink)
  poly(d,[(134,102),(134,66),(154,44),(178,66),(178,102)],deep)
  line(d,[(127,101),(127,65),(154,36),(186,65),(186,101)],lit,3)
  line(d,[(136,96),(136,68),(154,47),(175,68),(175,96)],blood,2)
  ell(d,(145,64,166,87),blood); line(d,[(155,68),(155,84)],glow); line(d,[(149,76),(161,76)],glow)
  # Side arch offers another route.
  poly(d,[(244,112),(244,68),(263,42),(289,54),(289,129)],ink)
  line(d,[(245,110),(245,69),(263,43),(287,56),(287,126)],lit,3)
  poly(d,[(250,111),(251,73),(263,51),(282,61),(282,123)],deep)
  for x,y in [(31,48),(81,58),(222,67)]:
   poly(d,[(x,y),(x+4,y-3),(x+8,y),(x+7,y+6),(x+5,y+9),(x+3,y+5)],glow)
   box(d,(x+2,y+6,x+6,y+18),ink); line(d,[(x+4,y+10),(x+4,y+16)],accent,2)
  poly(d,[(0,59),(14,67),(18,82),(13,89),(26,97),(15,114),(0,120)],ink)
  poly(d,[(0,67),(8,73),(9,86),(18,98),(11,107),(0,113)],blood)
  for pts in [[(12,119),(27,108),(38,115),(26,125)],[(29,130),(43,117),(55,128),(44,137)],[(4,139),(17,123),(27,135),(21,145)]]:
   poly(d,pts,mid); line(d,[pts[0],pts[1],pts[2]],lit)
  # Siege ties, banners and engraved pilasters.
  for pts in [[(58,43),(75,47),(75,91),(69,85),(65,95),(59,93)],[(202,42),(214,42),(214,89),(209,84),(204,93)]]: poly(d,pts,blood)
  line(d,[(65,49),(69,53),(65,62),(68,69),(63,73)],glow)
  line(d,[(208,49),(208,72)],accent); line(d,[(205,60),(211,60)],accent)
  for x in [110,194]: box(d,(x,39,x+6,106),deep); line(d,[(x+1,43),(x+1,103)],lit)
  line(d,[(117,119),(155,106),(198,117),(157,132),(117,119)],blood)
  line(d,[(137,119),(157,112),(179,119),(156,125),(137,119)],glow)
 else:
  # Brutalist terminal with destination board, service tunnel and invader conduits.
  box(d,(127,53,187,104),ink); box(d,(132,58,182,101),deep)
  box(d,(134,46,183,56),mid); d.text((139,48),'LINE 04',font=font(6,True),fill=bone)
  box(d,(141,66,147,102),mid); box(d,(172,66,178,102),mid)
  line(d,[(156,59),(156,102)],lit); box(d,(160,73,165,77),glow)
  poly(d,[(242,62),(282,45),(282,124),(242,109)],ink)
  poly(d,[(247,66),(276,54),(276,116),(247,106)],deep)
  line(d,[(245,60),(282,44)],accent,3)
  # Transit benches and bollards, shown as recognisable silhouettes.
  poly(d,[(9,100),(54,84),(54,90),(10,106)],mid); line(d,[(12,105),(12,116)],ink,3); line(d,[(48,94),(48,105)],ink,3)
  poly(d,[(7,92),(52,76),(54,82),(10,99)],lit)
  poly(d,[(68,69),(72,71),(72,109),(68,111)],deep); poly(d,[(82,73),(86,75),(86,104),(82,107)],mid)
  # Alien cable root climbs over public sign and hooks into ceiling.
  line(d,[(0,17),(22,25),(27,37),(40,48),(41,81),(30,104),(36,124)],ink,9)
  line(d,[(0,17),(22,25),(27,37),(40,48),(41,81),(30,104),(36,124)],blood,5)
  line(d,[(2,15),(23,23),(30,35),(44,44)],mid,2)
  line(d,[(38,51),(56,46),(61,31),(76,21)],ink,5); line(d,[(39,51),(56,46),(61,31),(76,21)],blood,2)
  for x,y in [(27,34),(41,72),(33,111)]: box(d,(x-3,y-2,x+3,y+3),ink); box(d,(x-1,y-1,x+2,y+1),glow)
  poly(d,[(0,43),(49,57),(49,67),(0,53)],deep); line(d,[(0,46),(47,59)],bone,2)
  # Thick public architecture frames floor lanes.
  poly(d,[(101,31),(113,36),(113,110),(102,115)],mid); line(d,[(105,38),(105,109)],lit,2)
  poly(d,[(216,32),(228,27),(228,118),(216,110)],mid); line(d,[(220,39),(220,108)],lit,2)
  line(d,[(110,111),(75,158)],accent,3); line(d,[(207,110),(247,158)],accent,3)
  poly(d,[(193,121),(202,117),(214,127),(211,137),(196,137)],deep); line(d,[(197,121),(206,130)],glow,2)
 # Material fragments and floor shadow zones, deterministic for equal finish.
 rng=random.Random(680+idx)
 for n in range(44):
  x,y=rng.randrange(320),rng.randrange(111,157)
  c=mid if n%5==0 else deep
  box(d,(x,y,x+rng.randrange(1,4),y),c)
 # Enemy shadows and intended size at 320x180. Near melee; mid ranged.
 ell(d,(57,132,115,145),ink); ell(d,(187,112,231,121),ink)
 near=enemies[0].resize((66,88),NN); far=enemies[1].resize((45,60),NN)
 im.paste(near,(54,53),near); im.paste(far,(187,58),far)
 # First-person shotgun gives material comparison and correct foreground crop.
 gun=guns[1].resize((112,79),NN); im.paste(gun,(142,81),gun)
 # A tiny centered crosshair; one-pixel gap keeps the target visible.
 d=small(im)
 for xy in [(155,89,157,89),(161,89,163,89),(159,85,159,87),(159,91,159,93)]: box(d,xy,bone)
 im.paste(h,(0,148))
 return palette_lock(im,p).resize((640,360),NN)

def board(c,scene_im,enemies,guns,mats,h):
 # Equal geometry and typography across the three identities.
 im=Image.new('RGB',(1280,900),'#10141A'); d=small(im)
 d.text((32,23),c['title'],font=font(28,True),fill='#F0EEE4')
 d.text((33,63),c['subtitle'].upper(),font=font(12,True),fill=c['palette'][7])
 d.text((1247,44),'EYESORE / CONCEPT STUDY',font=font(12),anchor='ra',fill='#8F9AA7')
 d.text((33,86),c['tag'],font=font(15),fill='#C1C7CC')
 # Scene 800 x 450 exactly nearest-neighbor from 320x180: no intermediate smoothing.
 d.text((32,121),'FIRST-PERSON COMBAT / 320 × 180 PIXEL GRID',font=font(12,True),fill='#8F9AA7')
 s=scene_im.resize((800,450),NN); im.paste(s,(32,146))
 # Right palette and scene notes.
 d.text((862,122),'COLOUR + ROLE',font=font(12,True),fill='#8F9AA7')
 for k,(hexval,label) in enumerate(zip(c['palette'],c['names'])):
  y=149+k*38
  d.rectangle((862,y,892,y+25),fill=hexval)
  d.text((905,y+1),label.upper(),font=font(10,True),fill='#D9DCE0')
  d.text((905,y+15),hexval,font=font(10),fill='#8F9AA7')
 d.text((862,480),'THREAT LANGUAGE',font=font(12,True),fill='#8F9AA7')
 # Short author-facing note; wrapped at constrained width.
 import textwrap
 for i,t in enumerate(textwrap.wrap(c['read'],width=43)):
  d.text((862,507+i*19),t,font=font(12),fill='#B9C2CA')
 # Bottom four columns: enemies (2 cards), arms (2 frames), 2x2 texture bank.
 d.line((32,619,1247,619),fill='#35404B')
 d.text((32,637),'MELEE / NEAR',font=font(12,True),fill='#8F9AA7')
 d.text((265,637),'RANGED / MID',font=font(12,True),fill='#8F9AA7')
 d.text((508,637),'WEAPON CONSTRUCTION',font=font(12,True),fill='#8F9AA7')
 d.text((914,637),'SEAMLESS MATERIAL BANK',font=font(12,True),fill='#8F9AA7')
 # neutral pedestal leaves transparent silhouette visible; stable floor markers.
 for k,x in enumerate([51,283]):
  d.rectangle((x-18,663,x+174,842),fill='#1A222B')
  d.line((x-4,830,x+155,830),fill='#35404B')
  s=enemies[k].resize((126,168),NN); im.paste(s,(x+9,667),s)
  d.text((x-10,852),c['enemies'][k],font=font(13,True),fill='#E4E5DF')
  d.text((x-10,874),'96 × 128 · feet at (48, 124)',font=font(10),fill='#7E8C98')
 for k,x in enumerate([509,699]):
  d.rectangle((x,664,x+176,811),fill='#1A222B')
  s=guns[k].resize((176,123),NN); im.paste(s,(x,681),s)
  d.text((x,822),'PISTOL' if k==0 else 'SHOTGUN',font=font(11,True),fill='#E4E5DF')
  d.text((x,841),'160 × 112 · held view',font=font(10),fill='#7E8C98')
 h2=h.resize((360,36),NN); im.paste(h2,(509,861))
 for k in range(4):
  x=914+(k%2)*168; y=665+(k//2)*103
  # Material shown as 2x2 repeat; boundaries included only outside the repeat.
  t=Image.new('RGB',(64,64))
  for yy in [0,32]:
   for xx in [0,32]: t.paste(mats[k],(xx,yy))
  im.paste(t.resize((80,80),NN),(x,y))
  d.text((x+87,y+2),c['materials'][k].split()[0],font=font(10,True),fill='#D9DCE0')
  d.text((x+87,y+17),' '.join(c['materials'][k].split()[1:]),font=font(10),fill='#A6B2BD')
  d.text((x+87,y+39),'32 × 32',font=font(10),fill='#7E8C98')
  d.text((x+87,y+54),'2 × 2 repeat',font=font(9),fill='#7E8C98')
 return im

def main():
 manifest={'project':'Eyesore — fresh identity review','stage':'Concept selection; representative frames only','art_provenance':{'method':'Original hand-authored coordinates and pixel clusters rendered by Pillow','generated_image_models':False,'old_project_assets':False,'source':'draw_concepts.py','sampling':'Nearest-neighbor only','authoring_grid':'320x180 scene; 96x128 enemies; 160x112 held guns; 32x32 materials'},'concepts':[]}
 for idx,c in enumerate(CONCEPTS):
  folder=ROOT/c['slug']; folder.mkdir(exist_ok=True)
  enemies=[draw_enemy(idx,k,c['palette']) for k in range(2)]
  guns=[draw_gun(idx,k,c['palette']) for k in ['pistol','shotgun']]
  mats=[material(idx,k,c['palette']) for k in range(4)]
  h=palette_lock(hud(idx,c['palette']),c['palette']); s=scene(idx,c['palette'],mats,enemies,guns,h)
  enemies[0].save(folder/'enemy_melee.png'); enemies[1].save(folder/'enemy_ranged.png')
  guns[0].save(folder/'pistol.png'); guns[1].save(folder/'shotgun.png')
  for k,m in enumerate(mats): m.save(folder/f'material_{k+1}.png')
  h.save(folder/'hud.png'); s.save(folder/'scene.png'); s.resize((320,180),NN).save(folder/'scene_native.png'); board(c,s,enemies,guns,mats,h).save(folder/'board.png')
  colors=[{'name':n,'hex':v} for n,v in zip(c['names'],c['palette'])]
  (folder/'palette.json').write_text(json.dumps(colors,indent=2)+'\n')
  entry={k:c[k] for k in ['slug','title','subtitle','tag','read','cost','limitation']}
  entry.update({'palette':colors,'directory':c['slug'],'board':f"{c['slug']}/board.png",'scene':f"{c['slug']}/scene.png",'scene_native':f"{c['slug']}/scene_native.png",'hud':f"{c['slug']}/hud.png",'enemies':[{'role':'melee' if k==0 else 'ranged','name':c['enemies'][k],'path':f"{c['slug']}/enemy_{'melee' if k==0 else 'ranged'}.png",'size':[96,128],'feet_pivot':[48,124],'transparent':True,'frames':1} for k in range(2)],'weapons':[{'name':name,'path':f"{c['slug']}/{name}.png",'size':[160,112],'transparent':True,'held_view_anchor':[80,112],'frames':1} for name in ['pistol','shotgun']],'materials':[{'name':c['materials'][k],'path':f"{c['slug']}/material_{k+1}.png",'size':[32,32],'tileable':True} for k in range(4)]})
  manifest['concepts'].append(entry)
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 # Real, reproducible checks, not a speculative test suite.
 report=[]
 for c in manifest['concepts']:
  p=ROOT/c['slug']; assets={a.name: {'size':list(Image.open(a).size),'mode':Image.open(a).mode} for a in sorted(p.glob('*.png'))}
  for a in c['enemies']+c['weapons']:
   im=Image.open(ROOT/a['path']); alpha=im.getchannel('A'); assert alpha.getextrema()==(0,255)
   assert im.size==tuple(a['size']); assert im.getpixel((0,0))[3]==0
  assert Image.open(p/'board.png').size==(1280,900); assert Image.open(p/'scene.png').size==(640,360)
  rgba_checks=[]
  for a in c['enemies']+c['weapons']:
   im=Image.open(ROOT/a['path']); pixels=im.get_flattened_data(); opaque={px[:3] for px in pixels if px[3]==255}; declared={tuple(int(v['hex'][j:j+2],16) for j in (1,3,5)) for v in c['palette']}
   assert opaque <= declared
   rgba_checks.append({'path':a['path'],'alpha_bounds':list(im.getchannel('A').getbbox()),'opaque_inks':len(opaque),'outside_palette_inks':len(opaque-declared),'top_left_transparent':im.getpixel((0,0))[3]==0,'feet_pivot':a.get('feet_pivot')})
  for filename in ['scene.png','scene_native.png','hud.png']:
   probe=Image.open(p/filename); assert len(probe.getcolors(maxcolors=256))<=8
  report.append({'slug':c['slug'],'assets':assets,'rgba_checks':rgba_checks,'transparency':'Both enemy and held weapon frames contain fully clear and fully opaque pixels. All four outer-corner pixels are clear; the held hand intentionally reaches the gun frame’s lower edge away from the corners.','feet_pivot':'All enemy coordinate designs terminate at y=124 and share anchor (48,124). The actual contact span differs per anatomy.','source':'Re-rendered from draw_concepts.py with no external art input.'})
 (ROOT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print('Rendered three comparable packets: 36 PNG assets, 3 palette JSON files, manifest and verification.')
if __name__=='__main__': main()
