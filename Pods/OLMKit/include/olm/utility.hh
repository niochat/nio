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

#ifndef UTILITY_HH_
#define UTILITY_HH_

#include "olm/error.h"

#include <cstddef>
#include <cstdint>

struct _olm_ed25519_public_key;

namespace olm {

struct Utility {

    Utility();

    OlmErrorCode last_error;

    /** The length of a SHA-256 hash in bytes. */
    std::size_t sha256_length();

    /** Compute a SHA-256 hash. Returns the length of the SHA-256 hash in bytes
     * on success. Returns std::size_t(-1) on failure. On failure last_error
     * will be set with an error code. If the output buffer was too small then
     * last error will be OUTPUT_BUFFER_TOO_SMALL. */
    std::size_t sha256(
        std::uint8_t const * input, std::size_t input_length,
        std::uint8_t * output, std::size_t output_length
    );

    /** Verify a ed25519 signature. Returns std::size_t(0) on success. Returns
     * std::size_t(-1) on failure or if the signature was invalid. On failure
     * last_error will be set with an error code. If the signature was too short
     * or was not a valid signature then last_error will be BAD_MESSAGE_MAC. */
    std::size_t ed25519_verify(
        _olm_ed25519_public_key const & key,
        std::uint8_t const * message, std::size_t message_length,
        std::uint8_t const * signature, std::size_t signature_length
    );

};


} // namespace olm

#endif /* UTILITY_HH_ */
