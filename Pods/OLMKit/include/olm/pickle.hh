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
#ifndef OLM_PICKLE_HH_
#define OLM_PICKLE_HH_

#include "olm/list.hh"
#include "olm/crypto.h"

#include <cstring>
#include <cstdint>

namespace olm {

inline std::size_t pickle_length(
    const std::uint32_t & value
) {
    return 4;
}

std::uint8_t * pickle(
    std::uint8_t * pos,
    std::uint32_t value
);

std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    std::uint32_t & value
);


inline std::size_t pickle_length(
    const bool & value
) {
    return 1;
}

std::uint8_t * pickle(
    std::uint8_t * pos,
    bool value
);

std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    bool & value
);


template<typename T, std::size_t max_size>
std::size_t pickle_length(
    olm::List<T, max_size> const & list
) {
    std::size_t length = pickle_length(std::uint32_t(list.size()));
    for (auto const & value : list) {
        length += pickle_length(value);
    }
    return length;
}


template<typename T, std::size_t max_size>
std::uint8_t * pickle(
    std::uint8_t * pos,
    olm::List<T, max_size> const & list
) {
    pos = pickle(pos, std::uint32_t(list.size()));
    for (auto const & value : list) {
        pos = pickle(pos, value);
    }
    return pos;
}


template<typename T, std::size_t max_size>
std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    olm::List<T, max_size> & list
) {
    std::uint32_t size;
    pos = unpickle(pos, end, size);
    while (size-- && pos != end) {
        T * value = list.insert(list.end());
        pos = unpickle(pos, end, *value);
    }
    return pos;
}


std::uint8_t * pickle_bytes(
    std::uint8_t * pos,
    std::uint8_t const * bytes, std::size_t bytes_length
);

std::uint8_t const * unpickle_bytes(
    std::uint8_t const * pos, std::uint8_t const * end,
    std::uint8_t * bytes, std::size_t bytes_length
);


std::size_t pickle_length(
    const _olm_curve25519_public_key & value
);


std::uint8_t * pickle(
    std::uint8_t * pos,
    const _olm_curve25519_public_key & value
);


std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    _olm_curve25519_public_key & value
);


std::size_t pickle_length(
    const _olm_curve25519_key_pair & value
);


std::uint8_t * pickle(
    std::uint8_t * pos,
    const _olm_curve25519_key_pair & value
);


std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    _olm_curve25519_key_pair & value
);

} // namespace olm




#endif /* OLM_PICKLE_HH */
