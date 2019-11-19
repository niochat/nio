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

/* C-compatible crpyto utility functions. At some point all of crypto.hh will
 * move here.
 */

#ifndef OLM_CRYPTO_H_
#define OLM_CRYPTO_H_

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/** length of a sha256 hash */
#define SHA256_OUTPUT_LENGTH 32

/** length of a public or private Curve25519 key */
#define CURVE25519_KEY_LENGTH 32

/** length of the shared secret created by a Curve25519 ECDH operation */
#define CURVE25519_SHARED_SECRET_LENGTH 32

/** amount of random data required to create a Curve25519 keypair */
#define CURVE25519_RANDOM_LENGTH CURVE25519_KEY_LENGTH

/** length of a public Ed25519 key */
#define ED25519_PUBLIC_KEY_LENGTH 32

/** length of a private Ed25519 key */
#define ED25519_PRIVATE_KEY_LENGTH 64

/** amount of random data required to create a Ed25519 keypair */
#define ED25519_RANDOM_LENGTH 32

/** length of an Ed25519 signature */
#define ED25519_SIGNATURE_LENGTH 64

/** length of an aes256 key */
#define AES256_KEY_LENGTH 32

/** length of an aes256 initialisation vector */
#define AES256_IV_LENGTH 16

struct _olm_aes256_key {
    uint8_t key[AES256_KEY_LENGTH];
};

struct _olm_aes256_iv {
    uint8_t iv[AES256_IV_LENGTH];
};


struct _olm_curve25519_public_key {
    uint8_t public_key[CURVE25519_KEY_LENGTH];
};

struct _olm_curve25519_private_key {
    uint8_t private_key[CURVE25519_KEY_LENGTH];
};

struct _olm_curve25519_key_pair {
    struct _olm_curve25519_public_key public_key;
    struct _olm_curve25519_private_key private_key;
};

struct _olm_ed25519_public_key {
    uint8_t public_key[ED25519_PUBLIC_KEY_LENGTH];
};

struct _olm_ed25519_private_key {
    uint8_t private_key[ED25519_PRIVATE_KEY_LENGTH];
};

struct _olm_ed25519_key_pair {
    struct _olm_ed25519_public_key public_key;
    struct _olm_ed25519_private_key private_key;
};


/** The length of output the aes_encrypt_cbc function will write */
size_t _olm_crypto_aes_encrypt_cbc_length(
    size_t input_length
);

/** Encrypts the input using AES256 in CBC mode with PKCS#7 padding.
 * The output buffer must be big enough to hold the output including padding */
void _olm_crypto_aes_encrypt_cbc(
    const struct _olm_aes256_key *key,
    const struct _olm_aes256_iv *iv,
    const uint8_t *input, size_t input_length,
    uint8_t *output
);

/** Decrypts the input using AES256 in CBC mode. The output buffer must be at
 * least the same size as the input buffer. Returns the length of the plaintext
 * without padding on success or std::size_t(-1) if the padding is invalid.
 */
size_t _olm_crypto_aes_decrypt_cbc(
    const struct _olm_aes256_key *key,
    const struct _olm_aes256_iv *iv,
    uint8_t const * input, size_t input_length,
    uint8_t * output
);


/** Computes SHA-256 of the input. The output buffer must be a least
 * SHA256_OUTPUT_LENGTH (32) bytes long. */
void _olm_crypto_sha256(
    uint8_t const * input, size_t input_length,
    uint8_t * output
);

/** HMAC: Keyed-Hashing for Message Authentication
 * http://tools.ietf.org/html/rfc2104
 * Computes HMAC-SHA-256 of the input for the key. The output buffer must
 * be at least SHA256_OUTPUT_LENGTH (32) bytes long. */
void _olm_crypto_hmac_sha256(
    uint8_t const * key, size_t key_length,
    uint8_t const * input, size_t input_length,
    uint8_t * output
);


/** HMAC-based Key Derivation Function (HKDF)
 * https://tools.ietf.org/html/rfc5869
 * Derives key material from the input bytes. */
void _olm_crypto_hkdf_sha256(
    uint8_t const * input, size_t input_length,
    uint8_t const * info, size_t info_length,
    uint8_t const * salt, size_t salt_length,
    uint8_t * output, size_t output_length
);


/** Generate a curve25519 key pair
 * random_32_bytes should be CURVE25519_RANDOM_LENGTH (32) bytes long.
 */
void _olm_crypto_curve25519_generate_key(
    uint8_t const * random_32_bytes,
    struct _olm_curve25519_key_pair *output
);


/** Create a shared secret using our private key and their public key.
 * The output buffer must be at least CURVE25519_SHARED_SECRET_LENGTH (32) bytes long.
 */
void _olm_crypto_curve25519_shared_secret(
    const struct _olm_curve25519_key_pair *our_key,
    const struct _olm_curve25519_public_key *their_key,
    uint8_t * output
);

/** Generate an ed25519 key pair
 * random_32_bytes should be ED25519_RANDOM_LENGTH (32) bytes long.
 */
void _olm_crypto_ed25519_generate_key(
    uint8_t const * random_bytes,
    struct _olm_ed25519_key_pair *output
);

/** Signs the message using our private key.
 *
 * The output buffer must be at least ED25519_SIGNATURE_LENGTH (64) bytes
 * long. */
void _olm_crypto_ed25519_sign(
    const struct _olm_ed25519_key_pair *our_key,
    const uint8_t * message, size_t message_length,
    uint8_t * output
);

/** Verify an ed25519 signature
 * The signature input buffer must be ED25519_SIGNATURE_LENGTH (64) bytes long.
 * Returns non-zero if the signature is valid. */
int _olm_crypto_ed25519_verify(
    const struct _olm_ed25519_public_key *their_key,
    const uint8_t * message, size_t message_length,
    const uint8_t * signature
);



#ifdef __cplusplus
} // extern "C"
#endif

#endif /* OLM_CRYPTO_H_ */
