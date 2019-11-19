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
#include "olm/cipher.h"
#include "olm/crypto.h"
#include "olm/memory.hh"
#include <cstring>

const std::size_t HMAC_KEY_LENGTH = 32;

namespace {

struct DerivedKeys {
    _olm_aes256_key aes_key;
    std::uint8_t mac_key[HMAC_KEY_LENGTH];
    _olm_aes256_iv aes_iv;
};


static void derive_keys(
    std::uint8_t const * kdf_info, std::size_t kdf_info_length,
    std::uint8_t const * key, std::size_t key_length,
    DerivedKeys & keys
) {
    std::uint8_t derived_secrets[
        AES256_KEY_LENGTH + HMAC_KEY_LENGTH + AES256_IV_LENGTH
    ];
    _olm_crypto_hkdf_sha256(
        key, key_length,
        nullptr, 0,
        kdf_info, kdf_info_length,
        derived_secrets, sizeof(derived_secrets)
    );
    std::uint8_t const * pos = derived_secrets;
    pos = olm::load_array(keys.aes_key.key, pos);
    pos = olm::load_array(keys.mac_key, pos);
    pos = olm::load_array(keys.aes_iv.iv, pos);
    olm::unset(derived_secrets);
}

static const std::size_t MAC_LENGTH = 8;

size_t aes_sha_256_cipher_mac_length(const struct _olm_cipher *cipher) {
    return MAC_LENGTH;
}

size_t aes_sha_256_cipher_encrypt_ciphertext_length(
        const struct _olm_cipher *cipher, size_t plaintext_length
) {
    return _olm_crypto_aes_encrypt_cbc_length(plaintext_length);
}

size_t aes_sha_256_cipher_encrypt(
    const struct _olm_cipher *cipher,
    uint8_t const * key, size_t key_length,
    uint8_t const * plaintext, size_t plaintext_length,
    uint8_t * ciphertext, size_t ciphertext_length,
    uint8_t * output, size_t output_length
) {
    auto *c = reinterpret_cast<const _olm_cipher_aes_sha_256 *>(cipher);

    if (ciphertext_length
            < aes_sha_256_cipher_encrypt_ciphertext_length(cipher, plaintext_length)
            || output_length < MAC_LENGTH) {
        return std::size_t(-1);
    }

    struct DerivedKeys keys;
    std::uint8_t mac[SHA256_OUTPUT_LENGTH];

    derive_keys(c->kdf_info, c->kdf_info_length, key, key_length, keys);

    _olm_crypto_aes_encrypt_cbc(
        &keys.aes_key, &keys.aes_iv, plaintext, plaintext_length, ciphertext
    );

    _olm_crypto_hmac_sha256(
        keys.mac_key, HMAC_KEY_LENGTH, output, output_length - MAC_LENGTH, mac
    );

    std::memcpy(output + output_length - MAC_LENGTH, mac, MAC_LENGTH);

    olm::unset(keys);
    return output_length;
}


size_t aes_sha_256_cipher_decrypt_max_plaintext_length(
    const struct _olm_cipher *cipher,
    size_t ciphertext_length
) {
    return ciphertext_length;
}

size_t aes_sha_256_cipher_decrypt(
    const struct _olm_cipher *cipher,
    uint8_t const * key, size_t key_length,
    uint8_t const * input, size_t input_length,
    uint8_t const * ciphertext, size_t ciphertext_length,
    uint8_t * plaintext, size_t max_plaintext_length
) {
    if (max_plaintext_length
            < aes_sha_256_cipher_decrypt_max_plaintext_length(cipher, ciphertext_length)
            || input_length < MAC_LENGTH) {
        return std::size_t(-1);
    }

    auto *c = reinterpret_cast<const _olm_cipher_aes_sha_256 *>(cipher);

    DerivedKeys keys;
    std::uint8_t mac[SHA256_OUTPUT_LENGTH];

    derive_keys(c->kdf_info, c->kdf_info_length, key, key_length, keys);

    _olm_crypto_hmac_sha256(
        keys.mac_key, HMAC_KEY_LENGTH, input, input_length - MAC_LENGTH, mac
    );

    std::uint8_t const * input_mac = input + input_length - MAC_LENGTH;
    if (!olm::is_equal(input_mac, mac, MAC_LENGTH)) {
        olm::unset(keys);
        return std::size_t(-1);
    }

    std::size_t plaintext_length = _olm_crypto_aes_decrypt_cbc(
        &keys.aes_key, &keys.aes_iv, ciphertext, ciphertext_length, plaintext
    );

    olm::unset(keys);
    return plaintext_length;
}

} // namespace

const struct _olm_cipher_ops _olm_cipher_aes_sha_256_ops = {
  aes_sha_256_cipher_mac_length,
  aes_sha_256_cipher_encrypt_ciphertext_length,
  aes_sha_256_cipher_encrypt,
  aes_sha_256_cipher_decrypt_max_plaintext_length,
  aes_sha_256_cipher_decrypt,
};
