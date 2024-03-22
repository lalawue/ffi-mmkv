local FFI = require("ffi")
local Buffer = require("string.buffer")
local otype = type
local otonumber = tonumber
local fcast = FFI.cast
local fstr = FFI.string
local fnew = FFI.new
FFI.cdef([[

/// @brief open mmkv
/// @param map id (container)
/// @param dir_path root dir for mmkv files
/// @param multi_process 0 for single process
/// @return context for LuaJIT side
void* ffi_mmkv_open(const char *map_id, const char *dir_path, int multi_process);

/// @brief close mmkv
/// @param mctx context
void ffi_mmkv_close(void *mctx);

/// @brief entry count, including expired keys
/// @param mctx context
/// @return number
int ffi_mmkv_count(void *mctx);

/// @brief file size
/// @param mctx
/// @return number
int ffi_mmkv_total_size(void *mctx);

/// @brief return mmkv all keys vector<string>
void * ffi_mmkv_all_keys(void *mctx);

/// @brief return next key in all_keys()
/// @param keys all_keys() return
/// @param reclaim_now free resources in keys
/// @return
const char * ffi_mmkv_next_key(void *keys, int reclaim_now);

/// @brief set value for key
/// @param mctx context
/// @param key key string
/// @param value obj
/// @param vlen value size
/// @return 1 for success
int ffi_mmkv_set(void *mctx, const char *key, const char *value, uint32_t vlen, uint32_t expire_duration);

struct ffi_mmkv_result {
    uint32_t vsize; // value size
    uint32_t vlen;  // output value length
    char *value;    // value pointer
};

/// @brief caller create result struct base on input memory space
struct ffi_mmkv_result * ffi_mmkv_tmp_result(uint8_t *tmp, uint32_t tmp_size);

/// @brief get value with key from mmkv
/// @param mctx context
/// @param key key string
/// @param r return result
/// @return 1 for success, or < 0 for value space not satisfy, 0 for key not exist
int ffi_mmkv_get(void *mctx, const char *key, struct ffi_mmkv_result *r);

/// @brief check key -> value exist
/// @param mctx
/// @param key
/// @return 1 for contains
int ffi_mmkv_contains(void *mctx, const char *key);

/// @brief remove key then return removed value
/// @param mctx context
/// @param key key string
/// @param r return value holder
/// @return 1 for success, or < 0 for value space not satisfy, 0 for key not exist
int ffi_mmkv_rm(void *mctx, const char *key, struct ffi_mmkv_result *r);

/// @brief reclaim removed key <-> value spaces
/// @param mctx context
void ffi_mmkv_trim(void *mctx);

/// @brief reduce disk space usage
/// @param mctx context
void ffi_mmkv_clear(void *mctx);

/// @brief enabled auto key expired
/// @param mctx context
/// @param seconds to expired
/// @return 1 for success
int ffi_mmkv_enable_auto_key_expired(void *mctx, uint32_t seconds);

/// @brief diable auto key expired
/// @param mctx context
/// @return 1 for success
int ffi_mmkv_disable_auto_key_expire(void *mctx);

]])
local ret, _lib = nil, nil
do
	local loaded = false
	local suffix = (jit.os == "Windows") and "dll" or "so"
	for cpath in package.cpath:gmatch("[^;]+") do
		local path = cpath:sub(1, cpath:len() - 2 - suffix:len()) .. "ffi-mmkv." .. suffix
		ret, _lib = pcall(FFI.load, path)
		if ret then
			loaded = true
			break
		end
	end
	if not loaded then
		error(_lib)
	end
end
local function _checkValueBuffer(m, vsize)
	if not (m._vsize < vsize + 1) then
		return 
	end
	while m._vsize < vsize + 1 do
		m._vsize = vsize + 512
	end
	m._vbuf = fnew("uint8_t[?]", m._vsize)
	m._vr = _lib.ffi_mmkv_tmp_result(m._vbuf, m._vsize)
end
local function _get(m, key)
	if not (otype(key) == "string") then
		return 
	end
	while true do
		ret = _lib.ffi_mmkv_get(m._ctx, key, m._vr)
		if ret < 0 then
			_checkValueBuffer(m, -ret)
		elseif ret == 1 then
			local bin = fstr(m._vr.value, m._vr.vlen)
			return Buffer.decode(bin)
		else 
			return 
		end
	end
end
local function _set(m, key, value, expired_duration)
	if not (otype(key) == "string" and value) then
		return false
	end
	local bin = Buffer.encode(value)
	_checkValueBuffer(m, bin:len())
	expired_duration = (otype(expired_duration) == "number") and expired_duration or 0
	return 1 == _lib.ffi_mmkv_set(m._ctx, key, bin, bin:len(), expired_duration)
end
local function _rm(m, key)
	if not (otype(key) == "string") then
		return 
	end
	while true do
		ret = _lib.ffi_mmkv_rm(m._ctx, key, m._vr)
		if ret < 0 then
			_checkValueBuffer(m, -ret)
		elseif ret == 1 then
			local bin = fstr(m._vr.value, m._vr.vlen)
			return Buffer.decode(bin)
		else 
			return 
		end
	end
end
local MMKV = { __tn = 'MMKV', __tk = 'class', __st = nil }
do
	local __st = nil
	local __ct = MMKV
	__ct.__ct = __ct
	__ct.isKindOf = function(c, a) return a and c and ((c.__ct == a) or (c.__st and c.__st:isKindOf(a))) or false end
	-- declare class var and methods
	__ct._ctx = false
	__ct._vsize = 0
	__ct._vbuf = false
	__ct._vr = false
	__ct._all_keys = false
	function __ct:init(map_id, fpath, multi_process)
		if not (otype(map_id) == "string" and otype(fpath) == "string") then
			return false
		end
		self._ctx = _lib.ffi_mmkv_open(map_id, fpath, multi_process and 1 or 0)
		if not (self._ctx ~= nil) then
			return false
		end
		self._vsize = 0
		_checkValueBuffer(self, 1024)
	end
	function __ct:clear()
		if self._ctx then
			_lib.ffi_mmkv_clear(self._ctx)
			self._ctx = nil
		end
	end
	function __ct:count()
		if not (self._ctx) then
			return 0
		end
		return otonumber(_lib.ffi_mmkv_count(self._ctx))
	end
	function __ct:totalSize()
		if not (self._ctx) then
			return 0
		end
		return otonumber(_lib.ffi_mmkv_total_size(self._ctx))
	end
	function __ct:contains(key)
		if not (self._ctx and otype(key) == "string") then
			return false
		end
		return 1 == _lib.ffi_mmkv_contains(self._ctx, key)
	end
	function __ct:get(key)
		if not (self._ctx) then
			return 
		end
		return _get(self, key)
	end
	function __ct:set(key, value, expired_duration)
		if not (self._ctx) then
			return 
		end
		return _set(self, key, value, expired_duration)
	end
	function __ct:rm(key)
		if not (self._ctx) then
			return 
		end
		return _rm(self, key)
	end
	function __ct:setAutoKeyExpired(seconds)
		if not (self._ctx and otype(seconds) == "number") then
			return 
		end
		if seconds >= 0 then
			_lib.ffi_mmkv_enable_auto_key_expired(self._ctx, seconds)
		else 
			_lib.ffi_mmkv_disable_auto_key_expire(self._ctx)
		end
	end
	function __ct:allKeys()
		local tbl = {  }
		if not (self._ctx and self:count() > 0) then
			return tbl
		end
		local keys = _lib.ffi_mmkv_all_keys(self._ctx)
		if not (keys) then
			return tbl
		end
		repeat
			local value = _lib.ffi_mmkv_next_key(keys, 0)
			if value ~= nil then
				tbl[#tbl + 1] = fstr(value)
			end
		until value == nil
		return tbl
	end
	function __ct:trim()
		if self._ctx then
			_lib.ffi_mmkv_trim(self._ctx)
		end
	end
	function __ct:clear()
		if self._ctx then
			_lib.ffi_mmkv_clear(self._ctx)
		end
	end
	function __ct:toDictionary()
		local dctx = { _ctx = self._ctx, _vsize = self._vsize, _vbuf = self._vbuf, _vr = self._vr }
		return setmetatable({  }, { __tostring = function(_)
			return "<class MMKV_Dictionary>"
		end, __len = function(_)
			return otonumber(_lib.smb_count())
		end, __index = function(_, key)
			return _get(dctx, key)
		end, __newindex = function(_, key, value)
			if not (otype(key) == "string") then
				return 
			end
			if value then
				_set(dctx, key, value)
			else 
				_rm(dctx, key)
			end
		end })
	end
	-- declare end
	local __imt = {
		__tostring = function(t) return "<class MMKV" .. t.__ins_name .. ">" end,
		__index = function(t, k)
			local v = __ct[k]
			if v ~= nil then rawset(t, k, v) end
			return v
		end,
	}
	setmetatable(__ct, {
		__tostring = function() return "<class MMKV>" end,
		__index = function(t, k)
			local v = __st and __st[k]
			if v ~= nil then rawset(t, k, v) end
			return v
		end,
		__call = function(_, ...)
			local t = {}; t.__ins_name = tostring(t):sub(6)
			local ins = setmetatable(t, __imt)
			if type(rawget(__ct,'init')) == 'function' and __ct.init(ins, ...) == false then return nil end
			return ins
		end,
	})
end
return MMKV
