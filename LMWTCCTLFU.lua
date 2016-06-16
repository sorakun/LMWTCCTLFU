
local class = require 'middleclass'

local LMWTCCTLFU = class 'LMWTCCTLFU'

-- c is a char
-- check if its a valid identifier candidate
local isId = function(c)
  return (string.match(c, '%a') or string.match(c, '%d') or (c == '_')) and true
end

local makeStars = function(c)
  s = ''
  for i=1,c do
    s = s ..'*'
  end
  return s
end

local skipSpaces = function(v, pos)
  while (v:sub(pos, pos) == ' ') or (v:sub(pos, pos) == '\t') do
    pos = pos + 1
  end
  
  return pos
end

local nextId = function(v, pos)
  -- skipping  spaces and tabs
  pos = skipSpaces(v, pos)
    
  local posInit = pos
  while isId(v:sub(pos, pos)) do
    pos=pos+1
  end
  
  local gotit = v:sub(posInit, pos-1)
  
  return gotit, pos
end

function LMWTCCTLFU:initialize(module)
  self.module = module
end


-- make sure you replace unsigned char with u_char and define that typedef!

function checkint(name)
  return name=="size_t" or name == "int" or name == "char" or name == "time_t" or name == "u_int" or name == "u_char"
end

function LMWTCCTLFU:go(input, file)
  local funcs = {}
  -- v is the line to parse
  for i, v in ipairs(input) do
    --print("line ", i, v)
    local fn = {}
    
    local type = ""
    local pos = 1
    local type, pos = nextId(v, pos)
    
    if type == "const" then
      pos = skipSpaces(v, pos)
      type, pos = nextId(v, pos)
    end
    
    local returnType = {name=type, ptr=0}
    
    
    
    pos = skipSpaces(v, pos)
    
    if v:sub(pos, pos) == '*' then
      
      while (v:sub(pos, pos) == ' ') or (v:sub(pos, pos) == '\t') or (v:sub(pos, pos) == '*') do
        if v:sub(pos, pos) == '*' then
          returnType.ptr = returnType.ptr + 1
        end
        pos = pos + 1
      end
    end
    if returnType.name == "char" then
      if returnType.ptr > 0 then
	returnType.ptr = returnType.ptr - 1
      end
      returnType.name = "string"
    end
      
    fn.returnType = returnType
    
    -- func name
    local fname, pos = nextId(v, pos)
    fn.name = fname
    
    skipSpaces(v, pos)
    
    if v:sub(pos, pos) ~= '(' then
      error("invalid input: '(' expected in C Function number: "..i..", pos: "..pos)
    end
    
    fn.args = {}
    
    pos = pos + 1
    
    while v:sub(pos, pos) ~= ')' do
      local arg = {out = false, ptr = 0}
      
      pos = skipSpaces(v, pos)
      
      if v:sub(pos, pos) == '@' then
        arg.out = true
        pos = pos + 1
        pos = skipSpaces(v, pos)
      end
    
    
      local type = {ptr = 0}
    
      type.name, pos = nextId(v, pos)
      
      if type.name == "const" then
      pos = skipSpaces(v, pos)
      type.name, pos = nextId(v, pos)
    end
      
      
      pos = skipSpaces(v, pos)
      
      if v:sub(pos, pos) == '*' then
      
        while (v:sub(pos, pos) == ' ') or (v:sub(pos, pos) == '\t') or (v:sub(pos, pos) == '*') do
          if v:sub(pos, pos) == '*' then
            type.ptr = type.ptr + 1
          end
          pos = pos + 1
        end
      end
      
      arg.type = type
      
      pos = skipSpaces(v, pos)
      
      arg.name, pos = nextId(v, pos)
            
      pos = skipSpaces(v, pos)
      
      while v:sub(pos, pos) == '[' do
	arg.type.ptr = arg.type.ptr+1
	pos = pos + 1
	pos = skipSpaces(v, pos)
	if v:sub(pos, pos) ~= ']' then
	  error("Do you even make correct syntax? where do you close the [] ?")
	end
	pos = pos + 1
	pos = skipSpaces(v, pos)
      end
      
      if arg.type.name == "char" then
	if arg.type.ptr > 0 then
	  arg.type.ptr = arg.type.ptr - 1
	end
	arg.type.name = "string"
      end
      
      table.insert(fn.args, arg)
      
      if v:sub(pos, pos) == ',' then
        pos = pos + 1
      end
      
    end
  
    table.insert(funcs, fn)
  end
  
  local f = io.open(file, "w")
  
  for i,v in ipairs(funcs) do
    f:write("static int lua_"..v.name.."(lua_State *L)\n{\n")
    local counter = 1
    for j, w in ipairs(v.args) do
      if not w.out then
        if w.type.ptr > 0 then
          f:write("\t"..w.type.name .. makeStars(w.type.ptr).." "..w.name.." = *(".. w.type.name..makeStars(w.type.ptr+1)..")luaL_checkudata(L, "..counter..", \""..w.type.name..makeStars(w.type.ptr).."\");\n")
        else
          if checkint(w.type.name) then
            f:write("\t"..w.type.name.." "..w.name.." = lua_tointeger(L, "..counter..");\n")
          elseif (w.type.name== "float") or (w.type.name == "double") then
            f:write("\tdouble "..w.name.." = lua_tonumber(L, "..counter..");\n")
          elseif w.type.name == "string" then
            f:write("\tconst char* "..w.name .." = lua_tostring(L, "..counter..");\n")
          elseif w.type.name == "bool" then
            f:write("\tbool "..w.name .." = lua_toboolean(L, "..counter..");\n")
          else
            f:write("\t"..w.type.name.." "..w.name .. "/* = handle @ "..counter.." Yourself */ ;\n")
          end
        end
        counter = counter + 1
      end
    end
    
    counter = 1
    for j, w in ipairs(v.args) do
      if w.out then
        f:write("\t"..w.type.name)
        for k = 2,w.type.ptr do
          f:write("*")
        end
        f:write(" "..w.name..";\n")
        counter = counter + 1
      end  
    end
    
    local hasRet = true
    
    if (v.returnType.name == "void") and (v.returnType.ptr == 0) then
      f:write("\t")
      hasRet = false
    else
      if v.returnType.name == "string" then
	f:write("\tchar* ")
      else
	f:write("\t"..v.returnType.name)
      end
	
      for k = 1,v.returnType.ptr do
        f:write("*")
      end
      f:write(" fnRetResult_ = ")
    end
    
    f:write(v.name .."(")
    
    for j, w in ipairs(v.args) do
      if w.out then
        f:write("&")
      end
      
      f:write(w.name)
      
      if j < #v.args then
        f:write(", ")
      end
    end
    f:write(");\n")
        
    if hasRet then
      if (v.returnType.ptr > 0)  then
          f:write("\tlua_pushlightuserdata(L, fnRetResult_);\n")
      else
        if checkint(v.returnType.name) then
          f:write("\tlua_pushinteger(L, fnRetResult_);\n")
        elseif (v.returnType.name== "float") or (v.returnType.name== "double") then
          f:write("\tlua_pushnumber(L, fnRetResult_);\n")
        elseif v.returnType.name == "string" then
          f:write("\tlua_pushstring(L, fnRetResult_);\n")
        elseif v.returnType.name == "bool" then
          f:write("\tlua_pushboolean(L, fnRetResult_);\n")
        else
          f:write("\t/* handle return fnRetResult_"..v.returnType.name .." Yourself */\n")
        end
      end
    end
    
    
    hasRet = false
    
    for j, w in ipairs(v.args) do
      if w.out then  
	hasRet = true
	if w.type.ptr > 1 then
          f:write("\tlua_pushlightuserdata(L, "..w.name..");\n")
        else
          if checkint(w.type.name) then
            f:write("\tlua_pushinteger(L, "..w.name..");\n")
          elseif (w.type.name== "float") or (w.type.name == "double") then
            f:write("\tlua_pushnumber(L, "..w.name..");\n")
          elseif (w.type.name== "string") then
            f:write("\tlua_pushstring(L, "..w.name..");\n")
          elseif (w.type.name== "boolean") then
            f:write("\tlua_pushboolean(L, "..w.name..");\n")
          else
            f:write("\t/* handle pushing "..w.name .." @ "..j.." Yourself */\n")
          end
        end
      end
    end
    
    if not hasRet then
      f:write("\tlua_pushnil(L);\n")
    end
    
    f:write("\treturn 1;\n}\n\n")
  end
  
  f:write("int lua_openlib"..self.module.."(lua_State *L)\n{\n\tstruct luaL_Reg driver[] =\n\t{\n")
    
  
  for i, v in ipairs(funcs) do
    f:write("\t\t{\""..v.name.."\", lua_"..v.name.."},\n")
  end
  f:write("\t\t{NULL, NULL}\n")
  f:write("\t};\n")
  f:write("\tluaL_openlib(L, \""..self.module.."\", driver, 0);\n\treturn 1;\n}\n\n")
  
end

return LMWTCCTLFU

