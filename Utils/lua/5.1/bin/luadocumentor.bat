@echo off
"C:\Program Files\lua\5.1\bin\lua.exe" -e "package.path=\"C:\\Users\\svenv\\AppData\\Roaming/luarocks/share/lua/5.1/?.lua;C:\\Users\\svenv\\AppData\\Roaming/luarocks/share/lua/5.1/?/init.lua;c:\\program files\\lua\\5.1\\/share/lua/5.1/?.lua;c:\\program files\\lua\\5.1\\/share/lua/5.1/?/init.lua;C:\\Program Files (x86)\\LuaRocks\\lua\\?.lua;\"..package.path; package.cpath=\"C:\\Users\\svenv\\AppData\\Roaming/luarocks/lib/lua/5.1/?.dll;c:\\program files\\lua\\5.1\\/lib/lua/5.1/?.dll;\"..package.cpath" -e "local k,l,_=pcall(require,\"luarocks.loader\") _=k and l.add_context(\"luadocumentor\",\"0.1.5-1\")" "c:\program files\lua\5.1\\lib\luarocks\rocks\luadocumentor\0.1.5-1\bin\luadocumentor" %*
exit /b %ERRORLEVEL%