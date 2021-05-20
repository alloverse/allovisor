#define LOVR_ENABLE_EVENT 1
#include "resources/boot.lua.h"
#include "api/api.h"

#include "modules/event/event.h"
#include "core/os.h"
#include "core/util.h"

#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

extern int luaopen_liballonet(lua_State* L);
extern bool AskMicrophonePermission(void);
extern void AlloPlatformInit();

// call from gdb to print lua stack
void allo_printstacks(lua_State* L)
{
  luax_traceback(L, L, "", 0);
  printf("%s\n", lua_tostring(L, -1));
  lua_pop(L, 1);
}

bool wasFocused = false;
static void onFocus(bool focused) {
  lovrEventPush((Event) { .type = EVENT_FOCUS, .data.boolean = { focused } });
  wasFocused = focused;
}

static Variant cookie;

int main(int argc, char** argv)
{
  lovrAssert(os_init(), "Failed to initialize platform");
  lovrEventInit();
  os_on_focus(onFocus);
  
  #if __APPLE__
    AlloPlatformInit();
    AskMicrophonePermission();
  #endif

  const char *defaultArgv = (char*[]){
    argv[0],
    "lua"
  };

  if (argc == 1)
  {
    printf("using bundled assets\n");
    argc = 2;
    argv = defaultArgv;
  }

  int status;
  bool restart;

  do {
    lua_State* L = luaL_newstate();
    luax_setmainthread(L);
    luaL_openlibs(L);
    luax_preload(L);
    luaopen_liballonet(L);

    // arg table
    lua_newtable(L);
    lua_pushstring(L, argc > 0 ? argv[0] : "lovr");
    lua_setfield(L, -2, "exe");
    luax_pushvariant(L, &cookie);
    lua_setfield(L, -2, "restart");

    int argOffset = 1;
    for (int i = 1; i < argc; i++, argOffset++) {
      if (!strcmp(argv[i], "--console")) {
        os_open_console();
      } else {
        break; // This is the project path
      }
    }

    // Now that we know the negative offset to start at, copy all args in the table
    for (int i = 0; i < argc; i++) {
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, -argOffset + i);
    }
    lua_setglobal(L, "arg");

    lua_pushcfunction(L, luax_getstack);
    if (luaL_loadbuffer(L, (const char*)src_resources_boot_lua, src_resources_boot_lua_len, "@boot.lua") || lua_pcall(L, 0, 1, -2)) {
      fprintf(stderr, "%s\n", lua_tostring(L, -1));
      return 1;
    }

    lua_State* T = lua_newthread(L);
    lua_pushvalue(L, -2);
    lua_xmove(L, T, 1);

    lovrSetErrorCallback(luax_vthrow, T);
    lovrSetLogCallback(luax_vlog, T);

    onFocus(wasFocused);

    while (luax_resume(T, 0) == LUA_YIELD) {
      os_sleep(0.);
    }

    restart = lua_type(T, 1) == LUA_TSTRING && !strcmp(lua_tostring(T, 1), "restart");
    status = lua_tonumber(T, 1);
    luax_checkvariant(T, 2, &cookie);
    if (cookie.type == TYPE_OBJECT) {
      cookie.type = TYPE_NIL;
      memset(&cookie.value, 0, sizeof(cookie.value));
    }
    lua_close(L);
  } while (restart);

  os_destroy();

  return status;
}
