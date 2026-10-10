"""Read-only native RGB8/RGBA8 PNG identities, with no image transformation writes."""
from __future__ import annotations
import struct
import zlib

def decode_png(data: bytes) -> tuple[int,int,bytes,bool]:
    def require(condition,message):
        if not condition: raise ValueError(message)
    require(data[:8]==b'\x89PNG\r\n\x1a\n','Invalid PNG signature')
    cursor,compressed,header=8,[],None
    while cursor<len(data):
        require(cursor+12<=len(data),'Truncated PNG chunk')
        length,=struct.unpack_from('>I',data,cursor)
        require(cursor+length+12<=len(data),'Truncated PNG payload')
        kind=data[cursor+4:cursor+8]; chunk=data[cursor+8:cursor+8+length]
        crc,=struct.unpack_from('>I',data,cursor+8+length)
        require(zlib.crc32(kind+chunk)&0xffffffff==crc,'PNG CRC mismatch')
        cursor+=length+12
        if kind==b'IHDR': header=struct.unpack('>IIBBBBB',chunk)
        elif kind==b'IDAT':compressed.append(chunk)
        elif kind==b'IEND':break
    require(header is not None and header[2]==8 and header[3] in (2,6) and header[4:]==(0,0,0),'Native noninterlaced RGB8/RGBA8 PNG required')
    width,height=header[:2]; channels=4 if header[3]==6 else 3
    require(0<width<=8192 and 0<height<=8192,'PNG dimensions outside bounded audit')
    raw=zlib.decompress(b''.join(compressed));stride=width*channels
    require(len(raw)==height*(stride+1),'PNG scanline length mismatch')
    previous,output=bytearray(stride),bytearray()
    for y in range(height):
        start=y*(stride+1);mode=raw[start]
        require(mode in range(5),'Unknown PNG filter')
        row=bytearray(raw[start+1:start+1+stride])
        if mode:
            for x in range(stride):
                left=row[x-channels] if x>=channels else 0;upper=previous[x];corner=previous[x-channels] if x>=channels else 0
                if mode==1:predictor=left
                elif mode==2:predictor=upper
                elif mode==3:predictor=(left+upper)//2
                else:
                    p=left+upper-corner;distances=(abs(p-left),abs(p-upper),abs(p-corner))
                    predictor=(left,upper,corner)[distances.index(min(distances))]
                row[x]=(row[x]+predictor)&255
        if channels==4:output.extend(row)
        else:
            for x in range(width):output.extend(row[x*3:x*3+3]);output.append(255)
        previous=row
    return width,height,bytes(output),channels==4
