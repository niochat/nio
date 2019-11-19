/* Copyright 2015, 2016 OpenMarket Ltd
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
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <type_traits>

namespace olm {

/** Clear the memory held in the buffer */
void unset(
    void volatile * buffer, std::size_t buffer_length
);

/** Clear the memory backing an object */
template<typename T>
void unset(T & value) {
    unset(reinterpret_cast<void volatile *>(&value), sizeof(T));
}

/** Check if two buffers are equal in constant time. */
bool is_equal(
    std::uint8_t const * buffer_a,
    std::uint8_t const * buffer_b,
    std::size_t length
);

/** Check if two fixed size arrays are equals */
template<typename T>
bool array_equal(
    T const & array_a,
    T const & array_b
) {
    static_assert(
        std::is_array<T>::value
            && std::is_convertible<T, std::uint8_t *>::value
            && sizeof(T) > 0,
        "Arguments to array_equal must be std::uint8_t arrays[]."
    );
    return is_equal(array_a, array_b, sizeof(T));
}

/** Copy into a fixed size array */
template<typename T>
std::uint8_t const * load_array(
    T & destination,
    std::uint8_t const * source
) {
    static_assert(
        std::is_array<T>::value
            && std::is_convertible<T, std::uint8_t *>::value
            && sizeof(T) > 0,
        "The first argument to load_array must be a std::uint8_t array[]."
    );
    std::memcpy(destination, source, sizeof(T));
    return source + sizeof(T);
}

/** Copy from a fixed size array */
template<typename T>
std::uint8_t * store_array(
    std::uint8_t * destination,
    T const & source
) {
    static_assert(
        std::is_array<T>::value
            && std::is_convertible<T, std::uint8_t *>::value
            && sizeof(T) > 0,
        "The second argument to store_array must be a std::uint8_t array[]."
    );
    std::memcpy(destination, source, sizeof(T));
    return destination + sizeof(T);
}

} // namespace olm
