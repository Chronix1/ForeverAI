"""Run a local Lua file using the installed Lua 5.4 shared library."""
import ctypes as c
import ctypes.util
import sys
from pathlib import Path
lib=c.CDLL(ctypes.util.find_library('lua5.4') or 'liblua5.4.so.0')
lib.luaL_newstate.restype=c.c_void_p
lib.luaL_openlibs.argtypes=[c.c_void_p]
lib.luaL_loadstring.argtypes=[c.c_void_p,c.c_char_p]; lib.luaL_loadstring.restype=c.c_int
lib.luaL_loadfilex.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p];lib.luaL_loadfilex.restype=c.c_int
lib.lua_pcallk.argtypes=[c.c_void_p,c.c_int,c.c_int,c.c_int,c.c_longlong,c.c_void_p];lib.lua_pcallk.restype=c.c_int
lib.lua_tolstring.argtypes=[c.c_void_p,c.c_int,c.c_void_p];lib.lua_tolstring.restype=c.c_char_p
lib.lua_close.argtypes=[c.c_void_p]
L=lib.luaL_newstate();lib.luaL_openlibs(L)
try:
 def check(code):
  if code:
   raise RuntimeError((lib.lua_tolstring(L,-1,None) or b'Lua error').decode('utf8','replace'))
 args=sys.argv[2:]
 quote=lambda x: '"'+x.replace('\\','\\\\').replace('"','\\"')+'"'
 check(lib.luaL_loadstring(L,('arg={'+','.join(quote(x) for x in args)+'}').encode()))
 check(lib.lua_pcallk(L,0,0,0,0,None))
 check(lib.luaL_loadfilex(L,str(Path(sys.argv[1])).encode(),None))
 check(lib.lua_pcallk(L,0,-1,0,0,None))
finally: lib.lua_close(L)
