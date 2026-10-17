"""Closed authored room shells: orthogonal concave cells or convex prisms.

Construction-time only. Concave outlines never enter the existing convex runtime
prism helper. Every boundary wall is a visible closed box with its own collider.
"""
from __future__ import annotations
import math


def inside(point, ring):
    x,z=point;hit=False
    for a,b in zip(ring,ring[1:]+ring[:1]):
        cross=(b[0]-a[0])*(z-a[1])-(b[1]-a[1])*(x-a[0])
        if abs(cross)<1e-7 and min(a[0],b[0])-1e-7<=x<=max(a[0],b[0])+1e-7 and min(a[1],b[1])-1e-7<=z<=max(a[1],b[1])+1e-7:return True
        if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:hit=not hit
    return hit


def cells(room):
    ring=room['outline_xz'];n=len(ring)
    assert sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1]))>0,'CCW required'
    turns=[(ring[(i+1)%n][0]-ring[i][0])*(ring[(i+2)%n][1]-ring[(i+1)%n][1])-(ring[(i+1)%n][1]-ring[i][1])*(ring[(i+2)%n][0]-ring[(i+1)%n][0]) for i in range(n)]
    if all(t>=0 for t in turns):return [{'kind':'convex','outline_xz':ring}]
    assert all(a[0]==b[0] or a[1]==b[1] for a,b in zip(ring,ring[1:]+ring[:1])),'Only orthogonal concave outlines supported'
    xs=sorted(set(p[0] for p in ring));zs=sorted(set(p[1] for p in ring));result=[]
    for x0,x1 in zip(xs,xs[1:]):
        for z0,z1 in zip(zs,zs[1:]):
            if inside(((x0+x1)/2,(z0+z1)/2),ring):result.append({'kind':'box','bounds_xz':[x0,x1,z0,z1]})
    return result


def slab(sc,room,name,bottom,thickness,material):
    x,y,z=room['center']
    for i,cell in enumerate(cells(room)):
        ident=name+'_Cell'+str(i)
        if cell['kind']=='box':
            x0,x1,z0,z1=cell['bounds_xz'];sc.box(ident,(x+(x0+x1)/2,y+bottom+thickness/2,z+(z0+z1)/2),(x1-x0+.02,thickness,z1-z0+.02),material)
        else:sc.prism(ident,(x,y+bottom,z),cell['outline_xz'],thickness,material)


def walls(sc,room,cuts,material):
    x,y,z=room['center'];ring=room['outline_xz'];height=room['size'][1]
    for edge,(a,b) in enumerate(zip(ring,ring[1:]+ring[:1])):
        dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz);assert length>.1
        side=('N' if dx>0 else 'S') if dz==0 else ('E' if dz>0 else 'W') if dx==0 else None
        axis=0 if dz==0 else 2;origin=x+a[0] if axis==0 else z+a[1];direction=1 if (dx if axis==0 else dz)>0 else -1
        openings=[]
        if side:
            for lo,hi,bottom,top in cuts[side]:
                start,end=sorted([(lo-origin)*direction,(hi-origin)*direction]);start=max(0,start);end=min(length,end)
                if end>start:openings.append((start,end,max(y,bottom),min(y+height,top)))
        spans=sorted({0,length}|{q for opening in openings for q in opening[:2]});ys=sorted({y,y+height}|{q for opening in openings for q in opening[2:]})
        for i,(lo,hi) in enumerate(zip(spans,spans[1:])):
            for j,(bottom,top) in enumerate(zip(ys,ys[1:])):
                if top<=bottom or any(c[0]<(lo+hi)/2<c[1] and c[2]<(bottom+top)/2<c[3] for c in openings):continue
                t=(lo+hi)/2/length;at=(x+a[0]+dx*t,(bottom+top)/2,z+a[1]+dz*t)
                sc.box(room['id']+'_OutlineWall_'+str(edge)+'_'+str(i)+'_'+str(j),at,(hi-lo+.015,top-bottom,.4),material,rot=(0,-math.degrees(math.atan2(dz,dx)),0))


def rectangle_fits(room,at,size,margin=0):
    x,_,z=room['center'];sx,_,sz=size
    return all(inside((at[0]-x+dx*(sx/2+margin),at[2]-z+dz*(sz/2+margin)),room['outline_xz']) for dx in [-1,1] for dz in [-1,1])


def fits_old_boundary_embedding(room,at,size):
    """Keep accepted trim embedded in the old outside wall; fit new cutouts only."""
    x,_,z=room['center'];sx,_,sz=room['size']
    return all(inside((max(-sx/2+.001,min(sx/2-.001,at[0]-x+dx*size[0]/2)),max(-sz/2+.001,min(sz/2-.001,at[2]-z+dz*size[2]/2))),room['outline_xz']) for dx in [-1,1] for dz in [-1,1])


def fit_box(room,at,size,margin=.22):
    """Minimum axis trimming for shell-only beams/ducts; no gameplay prop fit."""
    if fits_old_boundary_embedding(room,at,size):return list(at),list(size)
    x,_,z=room['center'];ring=room['outline_xz'];axis=0 if size[0]>=size[2] else 2;cross=2 if axis==0 else 0
    # Candidate boundaries are polygon-edge intersections at both width edges.
    ranges=[]
    for lateral in [at[cross]-size[cross]/2-margin,at[cross],at[cross]+size[cross]/2+margin]:
        local=lateral-(x if cross==0 else z);intersections=[]
        for a,b in zip(ring,ring[1:]+ring[:1]):
            ca,cb=a[0 if cross==0 else 1],b[0 if cross==0 else 1]
            if ca==cb:continue
            if min(ca,cb)<=local<=max(ca,cb):
                t=(local-ca)/(cb-ca);intersections.append(a[0 if axis==0 else 1]+t*(b[0 if axis==0 else 1]-a[0 if axis==0 else 1]))
        intersections=sorted(set(intersections));valid=[]
        for lo,hi in zip(intersections,intersections[1:]):
            point=((lo+hi)/2,local) if axis==0 else (local,(lo+hi)/2)
            if inside(point,ring):valid.append((lo,hi))
        if not valid:return None
        origin=x if axis==0 else z
        valid=[(max(lo+origin+margin,at[axis]-size[axis]/2),min(hi+origin-margin,at[axis]+size[axis]/2)) for lo,hi in valid]
        valid=[v for v in valid if v[1]-v[0]>.05]
        if not valid:return None
        ranges.append(max(valid,key=lambda v:v[1]-v[0]))
    lo=max(v[0] for v in ranges);hi=min(v[1] for v in ranges)
    if hi-lo<.05:return None
    result=list(at);extent=list(size);result[axis]=(lo+hi)/2;extent[axis]=hi-lo
    return (result,extent) if rectangle_fits(room,result,extent,0) else None


def fit_feature(room,at,size,margin=.22):
    if rectangle_fits(room,at,size,margin):return list(at)
    x,_,z=room['center'];xs={at[0],x};zs={at[2],z}
    for px,pz in room['outline_xz']:
        for sign in [-1,1]:xs.add(x+px+sign*(size[0]/2+margin));zs.add(z+pz+sign*(size[2]/2+margin))
    options=[(xx,at[1],zz) for xx in xs for zz in zs if rectangle_fits(room,(xx,at[1],zz),size,margin)]
    assert options,(room['id'],at,size,'no shell feature fit')
    return list(min(options,key=lambda p:(p[0]-at[0])**2+(p[2]-at[2])**2))


def observation(room):
    lo,hi=4,9
    if room.get('outline_xz'):
        east=room['size'][0]/2
        spans=[sorted([a[1],b[1]]) for a,b in zip(room['outline_xz'],room['outline_xz'][1:]+room['outline_xz'][:1]) if a[0]==b[0]==east]
        valid=[(max(lo,a+.25),min(hi,b-.25)) for a,b in spans];valid=[q for q in valid if q[1]>q[0]]
        assert valid,(room['id'],'observation alcove no actual east boundary')
        lo,hi=max(valid,key=lambda q:q[1]-q[0])
    return lo,hi
