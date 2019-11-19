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
#include "olm/crypto.h"
#include "olm/memory.hh"

#include <cstring>

extern "C" {

#include "crypto-algorithms/aes.h"
#include "crypto-algorithms/sha256.h"

}

#include "ed25519/src/ed25519.h"
#include "curve25519-donna.h"

namespace {

static const std::uint8_t CURVE25519_BASEPOINT[32] = {9};
static const std::size_t AES_KEY_SCHEDULE_LENGTH = 60;
static const std::size_t AES_KEY_BITS = 8 * AES256_KEY_LENGTH;
static const std::size_t AES_BLOCK_LENGTH = 16;
static const std::size_t SHA256_BLOCK_LENGTH = 64;
static const std::uint8_t HKDF_DEFAULT_SALT[32] = {};


template<std::size_t block_size>
inline static void xor_block(
    std::uint8_t * block,
    std::uint8_t const * input
) {
    for (std::size_t i = 0; i < block_size; ++i) {
        block[i] ^= input[i];
    }
}


inline static void hmac_sha256_key(
    std::uint8_t const * input_key, std::size_t input_key_length,
    std::uint8_t * hmac_key
) {
    std::memset(hmac_key, 0, SHA256_BLOCK_LENGTH);
    if (input_key_length > SHA256_BLOCK_LENGTH) {
        ::SHA256_CTX context;
        ::sha256_init(&context);
        ::sha256_update(&context, input_key, input_key_length);
        ::sha256_final(&context, hmac_key);
    } else {
        std::memcpy(hmac_key, input_key, input_key_length);
    }
}


inline static void hmac_sha256_init(
    ::SHA256_CTX * context,
    std::uint8_t const * hmac_key
) {
    std::uint8_t i_pad[SHA256_BLOCK_LENGTH];
    std::memcpy(i_pad, hmac_key, SHA256_BLOCK_LENGTH);
    for (std::size_t i = 0; i < SHA256_BLOCK_LENGTH; ++i) {
        i_pad[i] ^= 0x36;
    }
    ::sha256_init(context);
    ::sha256_update(context, i_pad, SHA256_BLOCK_LENGTH);
    olm::unset(i_pad);
}


inline static void hmac_sha256_final(
    ::SHA256_CTX * context,
    std::uint8_t const * hmac_key,
    std::uint8_t * output
) {
    std::uint8_t o_pad[SHA256_BLOCK_LENGTH + SHA256_OUTPUT_LENGTH];
    std::memcpy(o_pad, hmac_key, SHA256_BLOCK_LENGTH);
    for (std::size_t i = 0; i < SHA256_BLOCK_LENGTH; ++i) {
        o_pad[i] ^= 0x5C;
    }
    ::sha256_final(context, o_pad + SHA256_BLOCK_LENGTH);
    ::SHA256_CTX final_context;
    ::sha256_init(&final_context);
    ::sha256_update(&final_context, o_pad, sizeof(o_pad));
    ::sha256_final(&final_context, output);
    olm::unset(final_context);
    olm::unset(o_pad);
}

} // namespace

void _olm_crypto_curve25519_generate_key(
    uint8_t const * random_32_bytes,
    struct _olm_curve25519_key_pair *key_pair
) {
    std::memcpy(
        key_pair->private_key.private_key, random_32_bytes,
        CURVE25519_KEY_LENGTH
    );
    ::curve25519_donna(
        key_pair->public_key.public_key,
        key_pair->private_key.private_key,
        CURVE25519_BASEPOINT
    );
}


void _olm_crypto_curve25519_shared_secret(
    const struct _olm_curve25519_key_pair *our_key,
    const struct _olm_curve25519_public_key * their_key,
    std::uint8_t * output
) {
    ::curve25519_donna(output, our_key->private_key.private_key, their_key->public_key);
}


void _olm_crypto_ed25519_generate_key(
    std::uint8_t const * random_32_bytes,
    struct _olm_ed25519_key_pair *key_pair
) {
    ::ed25519_create_keypair(
        key_pair->public_key.public_key, key_pair->private_key.private_key,
        random_32_bytes
    );
}


void _olm_crypto_ed25519_sign(
    const struct _olm_ed25519_key_pair *our_key,
    std::uint8_t const * message, std::size_t message_length,
    std::uint8_t * output
) {
    ::ed25519_sign(
        output,
        message, message_length,
        our_key->public_key.public_key,
        our_key->private_key.private_key
    );
}


int _olm_crypto_ed25519_verify(
    const struct _olm_ed25519_public_key *their_key,
    std::uint8_t const * message, std::size_t message_length,
    std::uint8_t const * signature
) {
    return 0 != ::ed25519_verify(
        signature,
        message, message_length,
        their_key->public_key
    );
}


std::size_t _olm_crypto_aes_encrypt_cbc_length(
    std::size_t input_length
) {
    return input_length + AES_BLOCK_LENGTH - input_length % AES_BLOCK_LENGTH;
}


void _olm_crypto_aes_encrypt_cbc(
    _olm_aes256_key const *key,
    _olm_aes256_iv const *iv,
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output
) {
    std::uint32_t key_schedule[AES_KEY_SCHEDULE_LENGTH];
    ::aes_key_setup(key->key, key_schedule, AES_KEY_BITS);
    std::uint8_t input_block[AES_BLOCK_LENGTH];
    std::memcpy(input_block, iv->iv, AES_BLOCK_LENGTH);
    while (input_length >= AES_BLOCK_LENGTH) {
        xor_block<AES_BLOCK_LENGTH>(input_block, input);
        ::aes_encrypt(input_block, output, key_schedule, AES_KEY_BITS);
        std::memcpy(input_block, output, AES_BLOCK_LENGTH);
        input += AES_BLOCK_LENGTH;
        output += AES_BLOCK_LENGTH;
        input_length -= AES_BLOCK_LENGTH;
    }
    std::size_t i = 0;
    for (; i < input_length; ++i) {
        input_block[i] ^= input[i];
    }
    for (; i < AES_BLOCK_LENGTH; ++i) {
        input_block[i] ^= AES_BLOCK_LENGTH - input_length;
    }
    ::aes_encrypt(input_block, output, key_schedule, AES_KEY_BITS);
    olm::unset(key_schedule);
    olm::unset(input_block);
}


std::size_t _olm_crypto_aes_decrypt_cbc(
    _olm_aes256_key const *key,
    _olm_aes256_iv const *iv,
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output
) {
    std::uint32_t key_schedule[AES_KEY_SCHEDULE_LENGTH];
    ::aes_key_setup(key->key, key_schedule, AES_KEY_BITS);
    std::uint8_t block1[AES_BLOCK_LENGTH];
    std::uint8_t block2[AES_BLOCK_LENGTH];
    std::memcpy(block1, iv->iv, AES_BLOCK_LENGTH);
    for (std::size_t i = 0; i < input_length; i += AES_BLOCK_LENGTH) {
        std::memcpy(block2, &input[i], AES_BLOCK_LENGTH);
        ::aes_decrypt(&input[i], &output[i], key_schedule, AES_KEY_BITS);
        xor_block<AES_BLOCK_LENGTH>(&output[i], block1);
        std::memcpy(block1, block2, AES_BLOCK_LENGTH);
    }
    olm::unset(key_schedule);
    olm::unset(block1);
    olm::unset(block2);
    std::size_t padding = output[input_length - 1];
    return (padding > input_length) ? std::size_t(-1) : (input_length - padding);
}


void _olm_crypto_sha256(
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output
) {
    ::SHA256_CTX context;
    ::sha256_init(&context);
    ::sha256_update(&context, input, input_length);
    ::sha256_final(&context, output);
    olm::unset(context);
}


void _olm_crypto_hmac_sha256(
    std::uint8_t const * key, std::size_t key_length,
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output
) {
    std::uint8_t hmac_key[SHA256_BLOCK_LENGTH];
    ::SHA256_CTX context;
    hmac_sha256_key(key, key_length, hmac_key);
    hmac_sha256_init(&context, hmac_key);
    ::sha256_update(&context, input, input_length);
    hmac_sha256_final(&context, hmac_key, output);
    olm::unset(hmac_key);
    olm::unset(context);
}


void _olm_crypto_hkdf_sha256(
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t const * salt, std::size_t salt_length,
    std::uint8_t const * info, std::size_t info_length,
    std::uint8_t * output, std::size_t output_length
) {
    ::SHA256_CTX context;
    std::uint8_t hmac_key[SHA256_BLOCK_LENGTH];
    std::uint8_t step_result[SHA256_OUTPUT_LENGTH];
    std::size_t bytes_remaining = output_length;
    std::uint8_t iteration = 1;
    if (!salt) {
        salt = HKDF_DEFAULT_SALT;
        salt_length = sizeof(HKDF_DEFAULT_SALT);
    }
    /* Extract */
    hmac_sha256_key(salt, salt_length, hmac_key);
    hmac_sha256_init(&context, hmac_key);
    ::sha256_update(&context, input, input_length);
    hmac_sha256_final(&context, hmac_key, step_result);
    hmac_sha256_key(step_result, SHA256_OUTPUT_LENGTH, hmac_key);

    /* Expand */
    hmac_sha256_init(&context, hmac_key);
    ::sha256_update(&context, info, info_length);
    ::sha256_update(&context, &iteration, 1);
    hmac_sha256_final(&context, hmac_key, step_result);
    while (bytes_remaining > SHA256_OUTPUT_LENGTH) {
        std::memcpy(output, step_result, SHA256_OUTPUT_LENGTH);
        output += SHA256_OUTPUT_LENGTH;
        bytes_remaining -= SHA256_OUTPUT_LENGTH;
        iteration ++;
        hmac_sha256_init(&context, hmac_key);
        ::sha256_update(&context, step_result, SHA256_OUTPUT_LENGTH);
        ::sha256_update(&context, info, info_length);
        ::sha256_update(&context, &iteration, 1);
        hmac_sha256_final(&context, hmac_key, step_result);
    }
    std::memcpy(output, step_result, bytes_remaining);
    olm::unset(context);
    olm::unset(hmac_key);
    olm::unset(step_result);
}
