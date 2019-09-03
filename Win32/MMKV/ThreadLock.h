/*
 * Tencent is pleased to support the open source community by making
 * MMKV available.
 *
 * Copyright (C) 2018 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *       https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef MMKV_THREADLOCK_H
#define MMKV_THREADLOCK_H

namespace mmkv {

enum ThreadOnceToken : LONG {
    ThreadOnceUninitialized = 0,
    ThreadOnceInitializing,
    ThreadOnceInitialized
};

class ThreadLock {
private:
    CRITICAL_SECTION m_lock;

    // just forbid it for possibly misuse
    ThreadLock(const ThreadLock &other) = delete;
    ThreadLock &operator=(const ThreadLock &other) = delete;

public:
    ThreadLock();
    ~ThreadLock();

    void initialize();

    void lock();
    void unlock();

    static void ThreadOnce(ThreadOnceToken volatile &onceToken, void (*callback)(void));
};

} // namespace mmkv

#endif //MMKV_THREADLOCK_H