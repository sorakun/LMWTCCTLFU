 
### LET ME WRAP THAT C CODE TO LUA FOR YOU
Because your time is precious and i'm sure you have a lot of things to do

## usage:
This tool simple creates a skeleton that you can extend. It's not precise, and it WILL FAIL.
This tool helps you call C code from lua by automatically generating functions.
You need to check every function and make sure it is correct.
Some C functions may take pointers to store the result, therefor you need to add `@` before each
one for example `mouseGetPosition(int *x, int*y)` becomes `mouseGetPosition(@int *x, @int*y`.
The parser is not smart. It wont parse the following:
  - ...
  - type const -> use const type (const prefixed, example const char*)
  - function pointers

Please note that unsigned char becomes u_char and unsigned int becomes u_int, you have to add 
```c
#define u_char unsigned char 
#define u_int unsigned int
```
You can easily extend the code to add your own types.

```lua
 
local LMWTCCTLFU = require 'LMWTCCTLFU'

local input = {
  "ALLEGRO_EVENT_SOURCE *al_get_display_event_source(ALLEGRO_DISPLAY *display)",
  "ALLEGRO_BITMAP *al_get_backbuffer(ALLEGRO_DISPLAY *display)",
  "void al_flip_display()",
  "ALLEGRO_DISPLAY *al_create_display(int w, int h)",
  "int al_get_new_display_flags()",
  "int al_get_new_display_option(int option, @int *importance)"
  }

x = LMWTCCTLFU:new("Allegro")
x:go(input, "allegro.c")
```

produces:
```c
static int lua_al_get_display_event_source(lua_State *L)
{
	ALLEGRO_DISPLAY* display = *(ALLEGRO_DISPLAY**)luaL_checkudata(L, 1, "ALLEGRO_DISPLAY*");
	ALLEGRO_EVENT_SOURCE* fnRetResult_ = al_get_display_event_source(display);
	lua_pushlightuserdata(L, fnRetResult_);
	lua_pushnil(L);
	return 1;
}

static int lua_al_get_backbuffer(lua_State *L)
{
	ALLEGRO_DISPLAY* display = *(ALLEGRO_DISPLAY**)luaL_checkudata(L, 1, "ALLEGRO_DISPLAY*");
	ALLEGRO_BITMAP* fnRetResult_ = al_get_backbuffer(display);
	lua_pushlightuserdata(L, fnRetResult_);
	lua_pushnil(L);
	return 1;
}

static int lua_al_flip_display(lua_State *L)
{
	al_flip_display();
	lua_pushnil(L);
	return 1;
}

static int lua_al_create_display(lua_State *L)
{
	int w = lua_tointeger(L, 1);
	int h = lua_tointeger(L, 2);
	ALLEGRO_DISPLAY* fnRetResult_ = al_create_display(w, h);
	lua_pushlightuserdata(L, fnRetResult_);
	lua_pushnil(L);
	return 1;
}

static int lua_al_get_new_display_flags(lua_State *L)
{
	int fnRetResult_ = al_get_new_display_flags();
	lua_pushinteger(L, fnRetResult_);
	lua_pushnil(L);
	return 1;
}

static int lua_al_get_new_display_option(lua_State *L)
{
	int option = lua_tointeger(L, 1);
	int importance;
	int fnRetResult_ = al_get_new_display_option(option, &importance);
	lua_pushinteger(L, fnRetResult_);
	lua_pushinteger(L, importance);
	return 1;
}

int lua_openlibAllegro(lua_State *L)
{
	struct luaL_Reg driver[] =
	{
		{"al_get_display_event_source", lua_al_get_display_event_source},
		{"al_get_backbuffer", lua_al_get_backbuffer},
		{"al_flip_display", lua_al_flip_display},
		{"al_create_display", lua_al_create_display},
		{"al_get_new_display_flags", lua_al_get_new_display_flags},
		{"al_get_new_display_option", lua_al_get_new_display_option},
		{NULL, NULL}
	};
	luaL_openlib(L, "Allegro", driver, 0);
	return 1;
}


```
