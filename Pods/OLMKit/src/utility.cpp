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

#include "olm/utility.hh"
#include "olm/crypto.h"


olm::Utility::Utility(
) : last_error(OlmErrorCode::OLM_SUCCESS) {
}


size_t olm::Utility::sha256_length() {
    return SHA256_OUTPUT_LENGTH;
}


size_t olm::Utility::sha256(
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output, std::size_t output_length
) {
    if (output_length < sha256_length()) {
        last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    _olm_crypto_sha256(input, input_length, output);
    return SHA256_OUTPUT_LENGTH;
}


size_t olm::Utility::ed25519_verify(
    _olm_ed25519_public_key const & key,
    std::uint8_t const * message, std::size_t message_length,
    std::uint8_t const * signature, std::size_t signature_length
) {
    if (signature_length < ED25519_SIGNATURE_LENGTH) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_MAC;
        return std::size_t(-1);
    }
    if (!_olm_crypto_ed25519_verify(&key, message, message_length, signature)) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_MAC;
        return std::size_t(-1);
    }
    return std::size_t(0);
}
