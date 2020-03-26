#include "resources/boot.lua.h"
#include "api/api.h"
#include "core/os.h"
#include "core/util.h"
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

int main(int argc, char** argv)
{
  lovrAssert(lovrPlatformInit(), "Failed to initialize platform");

  int status;
  bool restart;

  do {
    lovrPlatformSetTime(0.);
    lua_State* L = luaL_newstate();
    luax_setmainthread(L);
    luaL_openlibs(L);

    // arg table
    lua_newtable(L);
    // push dummy "lovr" 
    lua_pushliteral(L, "lovr");
    lua_setfield(L, -2, "exe");
    lua_setglobal(L, "arg");

    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    luaL_register(L, NULL, lovrModules);
    lua_pop(L, 2);

    lua_pushcfunction(L, luax_getstack);
    if (luaL_loadbuffer(L, (const char*)src_resources_boot_lua, src_resources_boot_lua_len, "@boot.lua") || lua_pcall(L, 0, 1, -2)) {
      fprintf(stderr, "%s\n", lua_tostring(L, -1));
      return 1;
    }

    lua_State* T = lua_newthread(L);
    lua_pushvalue(L, -2);
    lua_xmove(L, T, 1);

    lovrSetErrorCallback(luax_vthrow, T);

    while (lua_resume(T, 0) == LUA_YIELD) {
      lovrPlatformSleep(0.);
    }

    restart = lua_type(T, -1) == LUA_TSTRING && !strcmp(lua_tostring(T, -1), "restart");
    status = lua_tonumber(T, -1);
    lua_close(L);
  } while (restart);

  lovrPlatformDestroy();

  return status;
}
