/* Copyright 2018, 2019 New Vector Ltd
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
#include "olm/pk.h"
#include "olm/cipher.h"
#include "olm/crypto.h"
#include "olm/ratchet.hh"
#include "olm/error.h"
#include "olm/memory.hh"
#include "olm/base64.hh"
#include "olm/pickle_encoding.h"
#include "olm/pickle.hh"

static const std::size_t MAC_LENGTH = 8;

const struct _olm_cipher_aes_sha_256 olm_pk_cipher_aes_sha256 =
    OLM_CIPHER_INIT_AES_SHA_256("");
const struct _olm_cipher *olm_pk_cipher =
    OLM_CIPHER_BASE(&olm_pk_cipher_aes_sha256);

extern "C" {

struct OlmPkEncryption {
    OlmErrorCode last_error;
    _olm_curve25519_public_key recipient_key;
};

const char * olm_pk_encryption_last_error(
    OlmPkEncryption * encryption
) {
    auto error = encryption->last_error;
    return _olm_error_to_string(error);
}

size_t olm_pk_encryption_size(void) {
    return sizeof(OlmPkEncryption);
}

OlmPkEncryption *olm_pk_encryption(
    void * memory
) {
    olm::unset(memory, sizeof(OlmPkEncryption));
    return new(memory) OlmPkEncryption;
}

size_t olm_clear_pk_encryption(
    OlmPkEncryption *encryption
) {
    /* Clear the memory backing the encryption */
    olm::unset(encryption, sizeof(OlmPkEncryption));
    /* Initialise a fresh encryption object in case someone tries to use it */
    new(encryption) OlmPkEncryption();
    return sizeof(OlmPkEncryption);
}

size_t olm_pk_encryption_set_recipient_key (
    OlmPkEncryption *encryption,
    void const * key, size_t key_length
) {
    if (key_length < olm_pk_key_length()) {
        encryption->last_error =
            OlmErrorCode::OLM_INPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    olm::decode_base64(
        (const uint8_t*)key,
        olm_pk_key_length(),
        (uint8_t *)encryption->recipient_key.public_key
    );
    return 0;
}

size_t olm_pk_ciphertext_length(
    OlmPkEncryption *encryption,
    size_t plaintext_length
) {
    return olm::encode_base64_length(
        _olm_cipher_aes_sha_256_ops.encrypt_ciphertext_length(olm_pk_cipher, plaintext_length)
    );
}

size_t olm_pk_mac_length(
    OlmPkEncryption *encryption
) {
    return olm::encode_base64_length(_olm_cipher_aes_sha_256_ops.mac_length(olm_pk_cipher));
}

size_t olm_pk_encrypt_random_length(
    OlmPkEncryption *encryption
) {
    return CURVE25519_KEY_LENGTH;
}

size_t olm_pk_encrypt(
    OlmPkEncryption *encryption,
    void const * plaintext, size_t plaintext_length,
    void * ciphertext, size_t ciphertext_length,
    void * mac, size_t mac_length,
    void * ephemeral_key, size_t ephemeral_key_size,
    void * random, size_t random_length
) {
    if (ciphertext_length
            < olm_pk_ciphertext_length(encryption, plaintext_length)
        || mac_length
            < _olm_cipher_aes_sha_256_ops.mac_length(olm_pk_cipher)
        || ephemeral_key_size
            < olm_pk_key_length()) {
        encryption->last_error =
            OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    if (random_length < olm_pk_encrypt_random_length(encryption)) {
        encryption->last_error =
            OlmErrorCode::OLM_NOT_ENOUGH_RANDOM;
        return std::size_t(-1);
    }

    _olm_curve25519_key_pair ephemeral_keypair;
    _olm_crypto_curve25519_generate_key((uint8_t *) random, &ephemeral_keypair);
    olm::encode_base64(
        (const uint8_t *)ephemeral_keypair.public_key.public_key,
        CURVE25519_KEY_LENGTH,
        (uint8_t *)ephemeral_key
    );

    olm::SharedKey secret;
    _olm_crypto_curve25519_shared_secret(&ephemeral_keypair, &encryption->recipient_key, secret);
    size_t raw_ciphertext_length =
        _olm_cipher_aes_sha_256_ops.encrypt_ciphertext_length(olm_pk_cipher, plaintext_length);
    uint8_t *ciphertext_pos = (uint8_t *) ciphertext + ciphertext_length - raw_ciphertext_length;
    uint8_t raw_mac[MAC_LENGTH];
    size_t result = _olm_cipher_aes_sha_256_ops.encrypt(
        olm_pk_cipher,
        secret, sizeof(secret),
        (const uint8_t *) plaintext, plaintext_length,
        (uint8_t *) ciphertext_pos, raw_ciphertext_length,
        (uint8_t *) raw_mac, MAC_LENGTH
    );
    if (result != std::size_t(-1)) {
        olm::encode_base64(raw_mac, MAC_LENGTH, (uint8_t *)mac);
        olm::encode_base64(ciphertext_pos, raw_ciphertext_length, (uint8_t *)ciphertext);
    }
    return result;
}

struct OlmPkDecryption {
    OlmErrorCode last_error;
    _olm_curve25519_key_pair key_pair;
};

const char * olm_pk_decryption_last_error(
    OlmPkDecryption * decryption
) {
    auto error = decryption->last_error;
    return _olm_error_to_string(error);
}

size_t olm_pk_decryption_size(void) {
    return sizeof(OlmPkDecryption);
}

OlmPkDecryption *olm_pk_decryption(
    void * memory
) {
    olm::unset(memory, sizeof(OlmPkDecryption));
    return new(memory) OlmPkDecryption;
}

size_t olm_clear_pk_decryption(
    OlmPkDecryption *decryption
) {
    /* Clear the memory backing the decryption */
    olm::unset(decryption, sizeof(OlmPkDecryption));
    /* Initialise a fresh decryption object in case someone tries to use it */
    new(decryption) OlmPkDecryption();
    return sizeof(OlmPkDecryption);
}

size_t olm_pk_private_key_length(void) {
    return CURVE25519_KEY_LENGTH;
}

size_t olm_pk_generate_key_random_length(void) {
    return olm_pk_private_key_length();
}

size_t olm_pk_key_length(void) {
    return olm::encode_base64_length(CURVE25519_KEY_LENGTH);
}

size_t olm_pk_key_from_private(
    OlmPkDecryption * decryption,
    void * pubkey, size_t pubkey_length,
    void * privkey, size_t privkey_length
) {
    if (pubkey_length < olm_pk_key_length()) {
        decryption->last_error =
            OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    if (privkey_length < olm_pk_private_key_length()) {
        decryption->last_error =
            OlmErrorCode::OLM_INPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }

    _olm_crypto_curve25519_generate_key((uint8_t *) privkey, &decryption->key_pair);
    olm::encode_base64(
        (const uint8_t *)decryption->key_pair.public_key.public_key,
        CURVE25519_KEY_LENGTH,
        (uint8_t *)pubkey
    );
    return 0;
}

size_t olm_pk_generate_key(
    OlmPkDecryption * decryption,
    void * pubkey, size_t pubkey_length,
    void * privkey, size_t privkey_length
) {
    return olm_pk_key_from_private(decryption, pubkey, pubkey_length, privkey, privkey_length);
}

namespace {
    static const std::uint32_t PK_DECRYPTION_PICKLE_VERSION = 1;

    static std::size_t pickle_length(
        OlmPkDecryption const & value
    ) {
        std::size_t length = 0;
        length += olm::pickle_length(PK_DECRYPTION_PICKLE_VERSION);
        length += olm::pickle_length(value.key_pair);
        return length;
    }


    static std::uint8_t * pickle(
        std::uint8_t * pos,
        OlmPkDecryption const & value
    ) {
        pos = olm::pickle(pos, PK_DECRYPTION_PICKLE_VERSION);
        pos = olm::pickle(pos, value.key_pair);
        return pos;
    }


    static std::uint8_t const * unpickle(
        std::uint8_t const * pos, std::uint8_t const * end,
        OlmPkDecryption & value
    ) {
        uint32_t pickle_version;
        pos = olm::unpickle(pos, end, pickle_version);

        switch (pickle_version) {
        case 1:
            break;

        default:
            value.last_error = OlmErrorCode::OLM_UNKNOWN_PICKLE_VERSION;
            return end;
        }

        pos = olm::unpickle(pos, end, value.key_pair);
        return pos;
    }
}

size_t olm_pickle_pk_decryption_length(
    OlmPkDecryption * decryption
) {
    return _olm_enc_output_length(pickle_length(*decryption));
}

size_t olm_pickle_pk_decryption(
    OlmPkDecryption * decryption,
    void const * key, size_t key_length,
    void *pickled, size_t pickled_length
) {
    OlmPkDecryption & object = *decryption;
    std::size_t raw_length = pickle_length(object);
    if (pickled_length < _olm_enc_output_length(raw_length)) {
        object.last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    pickle(_olm_enc_output_pos(reinterpret_cast<std::uint8_t *>(pickled), raw_length), object);
    return _olm_enc_output(
        reinterpret_cast<std::uint8_t const *>(key), key_length,
        reinterpret_cast<std::uint8_t *>(pickled), raw_length
    );
}

size_t olm_unpickle_pk_decryption(
    OlmPkDecryption * decryption,
    void const * key, size_t key_length,
    void *pickled, size_t pickled_length,
    void *pubkey, size_t pubkey_length
) {
    OlmPkDecryption & object = *decryption;
    if (pubkey != NULL && pubkey_length < olm_pk_key_length()) {
        object.last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    std::uint8_t * const pos = reinterpret_cast<std::uint8_t *>(pickled);
    std::size_t raw_length = _olm_enc_input(
        reinterpret_cast<std::uint8_t const *>(key), key_length,
        pos, pickled_length, &object.last_error
    );
    if (raw_length == std::size_t(-1)) {
        return std::size_t(-1);
    }
    std::uint8_t * const end = pos + raw_length;
    /* On success unpickle will return (pos + raw_length). If unpickling
     * terminates too soon then it will return a pointer before
     * (pos + raw_length). On error unpickle will return (pos + raw_length + 1).
     */
    if (end != unpickle(pos, end + 1, object)) {
        if (object.last_error == OlmErrorCode::OLM_SUCCESS) {
            object.last_error = OlmErrorCode::OLM_CORRUPTED_PICKLE;
        }
        return std::size_t(-1);
    }
    if (pubkey != NULL) {
        olm::encode_base64(
            (const uint8_t *)object.key_pair.public_key.public_key,
            CURVE25519_KEY_LENGTH,
            (uint8_t *)pubkey
        );
    }
    return pickled_length;
}

size_t olm_pk_max_plaintext_length(
    OlmPkDecryption * decryption,
    size_t ciphertext_length
) {
    return _olm_cipher_aes_sha_256_ops.decrypt_max_plaintext_length(
        olm_pk_cipher, olm::decode_base64_length(ciphertext_length)
    );
}

size_t olm_pk_decrypt(
    OlmPkDecryption * decryption,
    void const * ephemeral_key, size_t ephemeral_key_length,
    void const * mac, size_t mac_length,
    void * ciphertext, size_t ciphertext_length,
    void * plaintext, size_t max_plaintext_length
) {
    if (max_plaintext_length
            < olm_pk_max_plaintext_length(decryption, ciphertext_length)) {
        decryption->last_error =
            OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }

    struct _olm_curve25519_public_key ephemeral;
    olm::decode_base64(
        (const uint8_t*)ephemeral_key, ephemeral_key_length,
        (uint8_t *)ephemeral.public_key
    );
    olm::SharedKey secret;
    _olm_crypto_curve25519_shared_secret(&decryption->key_pair, &ephemeral, secret);
    uint8_t raw_mac[MAC_LENGTH];
    olm::decode_base64((const uint8_t*)mac, olm::encode_base64_length(MAC_LENGTH), raw_mac);
    size_t raw_ciphertext_length = olm::decode_base64_length(ciphertext_length);
    olm::decode_base64((const uint8_t *)ciphertext, ciphertext_length, (uint8_t *)ciphertext);
    size_t result = _olm_cipher_aes_sha_256_ops.decrypt(
        olm_pk_cipher,
        secret, sizeof(secret),
        (uint8_t *) raw_mac, MAC_LENGTH,
        (const uint8_t *) ciphertext, raw_ciphertext_length,
        (uint8_t *) plaintext, max_plaintext_length
    );
    if (result == std::size_t(-1)) {
        // we already checked the buffer sizes, so the only error that decrypt
        // will return is if the MAC is incorrect
        decryption->last_error =
            OlmErrorCode::OLM_BAD_MESSAGE_MAC;
        return std::size_t(-1);
    } else {
        return result;
    }
}

size_t olm_pk_get_private_key(
    OlmPkDecryption * decryption,
    void *private_key, size_t private_key_length
) {
    if (private_key_length < olm_pk_private_key_length()) {
        decryption->last_error =
            OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    std::memcpy(
        private_key,
        decryption->key_pair.private_key.private_key,
        olm_pk_private_key_length()
    );
    return olm_pk_private_key_length();
}

struct OlmPkSigning {
    OlmErrorCode last_error;
    _olm_ed25519_key_pair key_pair;
};

size_t olm_pk_signing_size(void) {
    return sizeof(OlmPkSigning);
}

OlmPkSigning *olm_pk_signing(void * memory) {
    olm::unset(memory, sizeof(OlmPkSigning));
    return new(memory) OlmPkSigning;
}

const char * olm_pk_signing_last_error(OlmPkSigning * sign) {
    auto error = sign->last_error;
    return _olm_error_to_string(error);
}

size_t olm_clear_pk_signing(OlmPkSigning *sign) {
    /* Clear the memory backing the signing */
    olm::unset(sign, sizeof(OlmPkSigning));
    /* Initialise a fresh signing object in case someone tries to use it */
    new(sign) OlmPkSigning();
    return sizeof(OlmPkSigning);
}

size_t olm_pk_signing_seed_length(void) {
    return ED25519_RANDOM_LENGTH;
}

size_t olm_pk_signing_public_key_length(void) {
    return olm::encode_base64_length(ED25519_PUBLIC_KEY_LENGTH);
}

size_t olm_pk_signing_key_from_seed(
    OlmPkSigning * signing,
    void * pubkey, size_t pubkey_length,
    void * seed, size_t seed_length
) {
    if (pubkey_length < olm_pk_signing_public_key_length()) {
        signing->last_error =
            OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    if (seed_length < olm_pk_signing_seed_length()) {
        signing->last_error =
            OlmErrorCode::OLM_INPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }

    _olm_crypto_ed25519_generate_key((uint8_t *) seed, &signing->key_pair);
    olm::encode_base64(
        (const uint8_t *)signing->key_pair.public_key.public_key,
        ED25519_PUBLIC_KEY_LENGTH,
        (uint8_t *)pubkey
    );
    return 0;
}

size_t olm_pk_signature_length() {
    return olm::encode_base64_length(ED25519_SIGNATURE_LENGTH);
}

size_t olm_pk_sign(
    OlmPkSigning *signing,
    uint8_t const * message, size_t message_length,
    uint8_t * signature, size_t signature_length
) {
    if (signature_length < olm_pk_signature_length()) {
        signing->last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    uint8_t *raw_sig = signature + olm_pk_signature_length() - ED25519_SIGNATURE_LENGTH;
    _olm_crypto_ed25519_sign(
        &signing->key_pair,
        message, message_length, raw_sig
    );
    olm::encode_base64(raw_sig, ED25519_SIGNATURE_LENGTH, signature);
    return olm_pk_signature_length();
}

}
