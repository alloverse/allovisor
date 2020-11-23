#define LOVR_ENABLE_EVENT 1
#include "resources/boot.lua.h"
#include "api/api.h"
#include "modules/event/event.h"
#include "core/os.h"
#include "core/util.h"
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

extern int luaopen_liballonet(lua_State* L);
extern bool AskMicrophonePermission(void);

// call from gdb to print lua stack
void allo_printstacks(lua_State* L)
{
  luax_traceback(L, L, "", 0);
  printf("%s\n", lua_tostring(L, -1));
  lua_pop(L, 1);
}

int main(int argc, char** argv)
{
  lovrAssert(lovrPlatformInit(), "Failed to initialize platform");
  
  #if __APPLE__
    AskMicrophonePermission();
  #endif

  int status;
  bool restart;
  Variant cookie;
  cookie.type = TYPE_NIL;

  if (argc == 1)
  {
    printf("using bundled assets\n");
    argc = 2;
    argv = (char*[]){
      argv[0],
      "lua"
    };
  }

  do {
    lovrPlatformSetTime(0.);
    lua_State* L = luaL_newstate();
    luax_setmainthread(L);
    luaL_openlibs(L);



    // arg table
    // Args follow the lua standard https://en.wikibooks.org/wiki/Lua_Programming/command_line_parameter
    // In this standard, the contents of argv are put in a global table named "arg", but with
    // indices offset such that the "script" (in lovr, the game path) is at index 0. So all
    // arguments (if any) intended for the script/game are at successive indices starting with 1,
    // and the exe and its arguments are in normal order but stored in negative indices.
    //
    // LÖVR can be run in ways normal Lua can't. It can be run with an empty argv, or with no script
    // (if fused).  So in the case of LÖVR:
    // * The script path will always be at index 0, but it can be nil.
    // * For a fused executable, whatever is given in argv as script name is still at 0, but will be ignored.
    // * The exe (argv[0]) will always be the lowest-integer index. If it's present, it will always be -1 or less.
    // * Any named arguments parsed by Lovr will be stored in the arg table at their named keys.
    // * An exe name will always be stored in the arg table at string key "exe", even if none was supplied in argv.
    lua_newtable(L);
    // push dummy "lovr" in case argv is empty
    lua_pushliteral(L, "lovr");
    lua_setfield(L, -2, "exe");

    typedef enum { // What flag is being searched for?
      ARGFLAG_NONE, // Not processing a flag
      ARGFLAG_ROOT
    } ArgFlag;

    ArgFlag currentFlag = ARGFLAG_NONE;
    int lovrArgs = 0; // Arg count up to but not including the game path
    // One pass to parse flags
    for (int i = 0; i < argc; i++) {
      if (lovrArgs > 0) {
        // This argument is an argument to a -- flag
        if (currentFlag == ARGFLAG_ROOT) {
          lua_pushstring(L, argv[i]);
          lua_setfield(L, -2, "root");
          currentFlag = ARGFLAG_NONE;

          // This argument is a -- flag
        }
        else if (!strcmp(argv[i], "--root") || !strcmp(argv[i], "-r")) {
          currentFlag = ARGFLAG_ROOT;

        }
        else if (!strcmp(argv[i], "--console")) {
          lovrPlatformOpenConsole();

          // This is the game path
        }
        else {
          break;
        }
      }
      else { // Found exe name
        lua_pushstring(L, argv[i]);
        lua_setfield(L, -2, "exe");
      }

      lovrArgs++;
    }
    // Now that we know the negative offset to start at, copy all args in the table
    for (int i = 0; i < argc; i++) {
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, -lovrArgs + i);
    }

    lua_setglobal(L, "arg");





    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    luaL_register(L, NULL, lovrModules);
    lua_pop(L, 2);
    luaopen_liballonet(L);

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

    while (lua_resume(T, 0) == LUA_YIELD) {
      lovrPlatformSleep(0.);
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

  lovrPlatformDestroy();

  return status;
}
