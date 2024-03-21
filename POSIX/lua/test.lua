package.path = package.path .. ";./POSIX/lua/?.lua;"
local MMKV = require("ffi-mmkv")
print(MMKV)
local a = MMKV("test", "/tmp/mmkv_test", true)
a:set("hello", "world")
print(a:get("hello"))
