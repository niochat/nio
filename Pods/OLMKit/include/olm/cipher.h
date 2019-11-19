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

#ifndef OLM_CIPHER_H_
#define OLM_CIPHER_H_

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

struct _olm_cipher;

struct _olm_cipher_ops {
    /**
     * Returns the length of the message authentication code that will be
     * appended to the output.
     */
    size_t (*mac_length)(const struct _olm_cipher *cipher);

    /**
     * Returns the length of cipher-text for a given length of plain-text.
     */
    size_t (*encrypt_ciphertext_length)(
        const struct _olm_cipher *cipher,
        size_t plaintext_length
    );

    /*
     * Encrypts the plain-text into the output buffer and authenticates the
     * contents of the output buffer covering both cipher-text and any other
     * associated data in the output buffer.
     *
     *  |---------------------------------------output_length-->|
     *  output  |--ciphertext_length-->|       |---mac_length-->|
     *          ciphertext
     *
     * The plain-text pointers and cipher-text pointers may be the same.
     *
     * Returns size_t(-1) if the length of the cipher-text or the output
     * buffer is too small. Otherwise returns the length of the output buffer.
     */
    size_t (*encrypt)(
        const struct _olm_cipher *cipher,
        uint8_t const * key, size_t key_length,
        uint8_t const * plaintext, size_t plaintext_length,
        uint8_t * ciphertext, size_t ciphertext_length,
        uint8_t * output, size_t output_length
    );

    /**
     * Returns the maximum length of plain-text that a given length of
     * cipher-text can contain.
     */
    size_t (*decrypt_max_plaintext_length)(
        const struct _olm_cipher *cipher,
        size_t ciphertext_length
    );

    /**
     * Authenticates the input and decrypts the cipher-text into the plain-text
     * buffer.
     *
     *  |----------------------------------------input_length-->|
     *  input   |--ciphertext_length-->|       |---mac_length-->|
     *          ciphertext
     *
     * The plain-text pointers and cipher-text pointers may be the same.
     *
     *  Returns size_t(-1) if the length of the plain-text buffer is too
     *  small or if the authentication check fails. Otherwise returns the length
     *  of the plain text.
     */
    size_t (*decrypt)(
        const struct _olm_cipher *cipher,
        uint8_t const * key, size_t key_length,
        uint8_t const * input, size_t input_length,
        uint8_t const * ciphertext, size_t ciphertext_length,
        uint8_t * plaintext, size_t max_plaintext_length
    );
};

struct _olm_cipher {
    const struct _olm_cipher_ops *ops;
    /* cipher-specific fields follow */
};

struct _olm_cipher_aes_sha_256 {
    struct _olm_cipher base_cipher;

    /** context string for the HKDF used for deriving the AES256 key, HMAC key,
     * and AES IV, from the key material passed to encrypt/decrypt.
     */
    uint8_t const * kdf_info;

    /** length of context string kdf_info */
    size_t kdf_info_length;
};

extern const struct _olm_cipher_ops _olm_cipher_aes_sha_256_ops;

/**
 * get an initializer for an instance of struct _olm_cipher_aes_sha_256.
 *
 * To use it, declare:
 *
 *   struct _olm_cipher_aes_sha_256 MY_CIPHER =
 *        OLM_CIPHER_INIT_AES_SHA_256("MY_KDF");
 *   struct _olm_cipher *cipher = OLM_CIPHER_BASE(&MY_CIPHER);
 */
#define OLM_CIPHER_INIT_AES_SHA_256(KDF_INFO) {     \
    /*.base_cipher = */{ &_olm_cipher_aes_sha_256_ops },\
    /*.kdf_info = */(uint8_t *)(KDF_INFO),              \
    /*.kdf_info_length = */sizeof(KDF_INFO) - 1         \
}
#define OLM_CIPHER_BASE(CIPHER) \
    (&((CIPHER)->base_cipher))


#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* OLM_CIPHER_H_ */
