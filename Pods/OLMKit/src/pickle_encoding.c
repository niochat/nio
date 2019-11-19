/* Copyright 2016 OpenMarket Ltd
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

#include "olm/pickle_encoding.h"

#include "olm/base64.h"
#include "olm/cipher.h"
#include "olm/olm.h"

static const struct _olm_cipher_aes_sha_256 PICKLE_CIPHER =
    OLM_CIPHER_INIT_AES_SHA_256("Pickle");

size_t _olm_enc_output_length(
    size_t raw_length
) {
    const struct _olm_cipher *cipher = OLM_CIPHER_BASE(&PICKLE_CIPHER);
    size_t length = cipher->ops->encrypt_ciphertext_length(cipher, raw_length);
    length += cipher->ops->mac_length(cipher);
    return _olm_encode_base64_length(length);
}

uint8_t * _olm_enc_output_pos(
    uint8_t * output,
    size_t raw_length
) {
    const struct _olm_cipher *cipher = OLM_CIPHER_BASE(&PICKLE_CIPHER);
    size_t length = cipher->ops->encrypt_ciphertext_length(cipher, raw_length);
    length += cipher->ops->mac_length(cipher);
    return output + _olm_encode_base64_length(length) - length;
}

size_t _olm_enc_output(
    uint8_t const * key, size_t key_length,
    uint8_t * output, size_t raw_length
) {
    const struct _olm_cipher *cipher = OLM_CIPHER_BASE(&PICKLE_CIPHER);
    size_t ciphertext_length = cipher->ops->encrypt_ciphertext_length(
        cipher, raw_length
    );
    size_t length = ciphertext_length + cipher->ops->mac_length(cipher);
    size_t base64_length = _olm_encode_base64_length(length);
    uint8_t * raw_output = output + base64_length - length;
    cipher->ops->encrypt(
        cipher,
        key, key_length,
        raw_output, raw_length,
        raw_output, ciphertext_length,
        raw_output, length
    );
    _olm_encode_base64(raw_output, length, output);
    return base64_length;
}


size_t _olm_enc_input(uint8_t const * key, size_t key_length,
                      uint8_t * input, size_t b64_length,
                      enum OlmErrorCode * last_error
) {
    size_t enc_length = _olm_decode_base64_length(b64_length);
    if (enc_length == (size_t)-1) {
        if (last_error) {
            *last_error = OLM_INVALID_BASE64;
        }
        return (size_t)-1;
    }
    _olm_decode_base64(input, b64_length, input);
    const struct _olm_cipher *cipher = OLM_CIPHER_BASE(&PICKLE_CIPHER);
    size_t raw_length = enc_length - cipher->ops->mac_length(cipher);
    size_t result = cipher->ops->decrypt(
        cipher,
        key, key_length,
        input, enc_length,
        input, raw_length,
        input, raw_length
    );
    if (result == (size_t)-1 && last_error) {
        *last_error = OLM_BAD_ACCOUNT_KEY;
    }
    return result;
}
