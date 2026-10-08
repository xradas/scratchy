#!/usr/bin/env python3
"""Read the shipped BMPs through the same SDL decoder used by the native game."""
from pathlib import Path
import ctypes as c
import ctypes.util
import subprocess

ROOT = Path(__file__).resolve().parent

class Rect(c.Structure):
    _fields_ = [('x', c.c_int), ('y', c.c_int), ('w', c.c_int), ('h', c.c_int)]

class Surface(c.Structure):
    _fields_ = [('flags', c.c_uint32), ('format', c.c_void_p), ('w', c.c_int), ('h', c.c_int),
                ('pitch', c.c_int), ('pixels', c.c_void_p), ('userdata', c.c_void_p),
                ('locked', c.c_int), ('list_blitmap', c.c_void_p), ('clip_rect', Rect),
                ('map', c.c_void_p), ('refcount', c.c_int)]

sdl = c.CDLL(ctypes.util.find_library('SDL2') or 'libSDL2-2.0.so.0')
sdl.SDL_RWFromFile.argtypes = [c.c_char_p, c.c_char_p]
sdl.SDL_RWFromFile.restype = c.c_void_p
sdl.SDL_LoadBMP_RW.argtypes = [c.c_void_p, c.c_int]
sdl.SDL_LoadBMP_RW.restype = c.POINTER(Surface)
sdl.SDL_ConvertSurfaceFormat.argtypes = [c.POINTER(Surface), c.c_uint32, c.c_uint32]
sdl.SDL_ConvertSurfaceFormat.restype = c.POINTER(Surface)
sdl.SDL_FreeSurface.argtypes = [c.POINTER(Surface)]

count = 0
for path in sorted(ROOT.glob('*/*-dir-*.bmp')):
    raw = sdl.SDL_LoadBMP_RW(sdl.SDL_RWFromFile(str(path).encode(), b'rb'), 1)
    assert raw, path
    converted = sdl.SDL_ConvertSurfaceFormat(raw, 0x16762004, 0)  # SDL_PIXELFORMAT_ABGR8888
    sdl.SDL_FreeSurface(raw)
    assert converted, path
    surface = converted.contents
    assert (surface.w, surface.h) == (384, 256), path
    rows = [c.string_at(surface.pixels + y * surface.pitch, surface.w * 4) for y in range(surface.h)]
    actual = b''.join(rows)
    expected = subprocess.check_output(['magick', str(path.with_suffix('.png')), '-depth', '8', 'rgba:-'])
    assert actual == expected, (path, 'SDL pixel/alpha roundtrip mismatch')
    assert min(actual[3::4]) == 0 and max(actual[3::4]) == 255, path
    sdl.SDL_FreeSurface(converted)
    count += 1
assert count == 96, count
print('SDL decoded all 96 BMPs exactly as their RGBA PNGs, including transparency and dark interiors.')
