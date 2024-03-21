/*
 * Copyright (c) 2024 lalawue
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#include <iostream>
#include <string>
#include "string.h"
#include "MMKV.h"

using namespace std;
using namespace mmkv;

extern void initialize();

/// @brief open mmkv
/// @param map id (container)
/// @param dir_path root dir for mmkv files
/// @param multi_process 0 for single process
/// @return context for LuaJIT side
extern "C" void*
ffi_mmkv_open(const char *map_id, const char *dir_path, int multi_process)
{
    if (map_id == NULL || dir_path == NULL) {
        return NULL;
    }
    string rootId = map_id;
    string rootDir = dir_path;
    initialize();
    MMKVMode mode = multi_process ? MMKV_MULTI_PROCESS : MMKV_SINGLE_PROCESS;
    return MMKV::mmkvWithID(rootId, (MMKVMode)mode, NULL, &rootDir);
}

/// @brief close mmkv
/// @param mctx context
extern "C" void
ffi_mmkv_close(void *mctx)
{
    if (mctx == NULL) {
        return;
    }
    ((MMKV *)mctx)->close();
}

/// @brief entry count, including expired keys
/// @param mctx context
/// @return number
extern "C" int
ffi_mmkv_count(void *mctx)
{
    if (mctx == NULL) {
        return -1;
    }
    return ((MMKV *)mctx)->count();
}

/// @brief file size
/// @param mctx
/// @return
extern "C" int
ffi_mmkv_total_size(void *mctx)
{
    if (mctx == NULL) {
        return 0;
    }
    return ((MMKV *)mctx)->totalSize();
}

struct ffi_mmkv_keys {
    size_t index;
    vector<string> datas;
};

/// @brief return mmkv all keys vector<string>
extern "C" void *
ffi_mmkv_all_keys(void *mctx)
{
    if (mctx == NULL) {
        return NULL;
    }
    struct ffi_mmkv_keys *mkeys = (struct ffi_mmkv_keys *)calloc(1, sizeof(struct ffi_mmkv_keys));
    mkeys->datas = ((MMKV *)mctx)->allKeys();
    return mkeys;
}

/// @brief return next key in all_keys()
/// @param keys all_keys() return
/// @param reclaim_now free resources in keys
/// @return
extern "C" const char *
ffi_mmkv_next_key(void *keys, int reclaim_now)
{
    struct ffi_mmkv_keys *mkeys = (struct ffi_mmkv_keys *)keys;
    if (mkeys == NULL || mkeys->index < 0) {
        return NULL;
    }

    if (reclaim_now || mkeys->index >= mkeys->datas.size()) {
        mkeys->index = -1;
        free(mkeys);
        return NULL;
    }

    const char *key = mkeys->datas[mkeys->index].c_str();
    mkeys->index += 1;
    return key;
}

/// @brief set value for key
/// @param mctx context
/// @param key key string
/// @param value obj
/// @param vlen value size
/// @return 1 for success
extern "C" int
ffi_mmkv_set(void *mctx, const char *key, void *value, uint32_t vlen)
{
    if (mctx == NULL || key == NULL || value == NULL || vlen <= 0)
    {
        return 0;
    }
    MMKV *mmkv = (MMKV *)mctx;
    string skey = key;
    MMBuffer sbuffer(value, vlen);
    return true == mmkv->set(sbuffer, skey);
}

struct ffi_mmkv_result {
    uint32_t vsize; // value size
    uint32_t vlen;  // output value length
    void *value;    // value pointer
};

/// @brief caller create result struct base on input memory space
extern "C" struct ffi_mmkv_result *
ffi_mmkv_tmp_result(uint8_t *tmp, uint32_t tmp_size)
{
    if (tmp == NULL || tmp_size <= sizeof(struct ffi_mmkv_result))
    {
        return NULL;
    }
    memset(tmp, 0, tmp_size);
    struct ffi_mmkv_result *r = (struct ffi_mmkv_result *)tmp;
    r->vsize = tmp_size - sizeof(struct ffi_mmkv_result);
    r->vlen = 0;
    r->value = tmp + sizeof(struct ffi_mmkv_result);
    return r;
}

/// @brief get value with key from mmkv
/// @param mctx context
/// @param key key string
/// @param r return result
/// @return 1 for success, or < 0 for value space not satisfy, 0 for key not exist
extern "C" int
ffi_mmkv_get(void *mctx, const char *key, struct ffi_mmkv_result *r)
{
    if (mctx == NULL || key == NULL || r == NULL)
    {
        return 0;
    }
    MMKV *mmkv = (MMKV *)mctx;
    string skey = key;
    MMBuffer svalue;
    if (true == mmkv->getBytes(skey, svalue)) {
        if (r->vsize > svalue.length()) {
            memcpy(r->value, svalue.getPtr(), svalue.length());
            ((uint8_t*)r->value)[svalue.length()] = 0;
            r->vlen = svalue.length();
            return 1;
        } else {
            return -svalue.length();
        }
    }
    return 0;
}

/// @brief check key -> value exist
/// @param mctx
/// @param key
/// @return 1 for contains
extern "C" int
ffi_mmkv_contains(void *mctx, const char *key)
{
    if (mctx == NULL || key == NULL) {
        return 0;
    }
    string mkey = key;
    return ((MMKV *)mctx)->containsKey(mkey);
}

/// @brief remove key then return removed value
/// @param mctx context
/// @param key key string
/// @param r return value holder
/// @return 1 for success, or < 0 for value space not satisfy, 0 for key not exist
extern "C" int
ffi_mmkv_rm(void *mctx, const char *key, struct ffi_mmkv_result *r)
{
    if (mctx == NULL || key == NULL || r == NULL) {
        return 0;
    }
    MMKV *mmkv = (MMKV *)mctx;
    string skey = key;
    MMBuffer svalue;
    if (true == mmkv->getBytes(skey, svalue)) {
        if (r->vsize > svalue.length()) {
            memcpy(r->value, svalue.getPtr(), svalue.length());
            ((uint8_t*)r->value)[svalue.length()] = 0;
            r->vlen = svalue.length();
            mmkv->removeValueForKey(skey);
            return 1;
        } else {
            return -svalue.length();
        }
    }
    return 0;
}

/// @brief reclaim removed key <-> value spaces
/// @param mctx context
extern "C" void
ffi_mmkv_trim(void *mctx)
{
    if (mctx == NULL) {
        return;
    }
    ((MMKV *)mctx)->trim();
}

/// @brief reduce disk space usage
/// @param mctx context
extern "C" void
ffi_mmkv_clear(void *mctx)
{
    if (mctx == NULL) {
        return;
    }
    ((MMKV *)mctx)->clearAll();
}

/// @brief enabled auto key expired
/// @param mctx context
/// @param seconds to expired
/// @return 1 for success
extern "C" int
ffi_mmkv_enable_auto_key_expired(void *mctx, uint32_t seconds)
{
    if (mctx == NULL) {
        return 0;
    }
    if (((MMKV *)mctx)->enableAutoKeyExpire(seconds)) {
        return 1;
    }
    return 0;
}

/// @brief diable auto key expired
/// @param mctx context
/// @return 1 for success
extern "C" int
ffi_mmkv_disable_auto_key_expire(void *mctx)
{
    if (mctx == NULL) {
        return 0;
    }
    if (((MMKV *)mctx)->disableAutoKeyExpire()) {
        return 1;
    }
    return 0;
}