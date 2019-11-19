/* Copyright 2015 OpenMarket Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include "olm/memory.hh"
#include "olm/memory.h"

void _olm_unset(
    void volatile * buffer, size_t buffer_length
) {
    olm::unset(buffer, buffer_length);
}

void olm::unset(
    void volatile * buffer, std::size_t buffer_length
) {
    char volatile * pos = reinterpret_cast<char volatile *>(buffer);
    char volatile * end = pos + buffer_length;
    while (pos != end) {
        *(pos++) = 0;
    }
}


bool olm::is_equal(
    std::uint8_t const * buffer_a,
    std::uint8_t const * buffer_b,
    std::size_t length
) {
    std::uint8_t volatile result = 0;
    while (length--) {
        result |= (*(buffer_a++)) ^ (*(buffer_b++));
    }
    return result == 0;
}
