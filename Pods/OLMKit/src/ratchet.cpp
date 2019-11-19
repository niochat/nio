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
#include "olm/ratchet.hh"
#include "olm/message.hh"
#include "olm/memory.hh"
#include "olm/cipher.h"
#include "olm/pickle.hh"

#include <cstring>

namespace {

static const std::uint8_t PROTOCOL_VERSION = 3;
static const std::uint8_t MESSAGE_KEY_SEED[1] = {0x01};
static const std::uint8_t CHAIN_KEY_SEED[1] = {0x02};
static const std::size_t MAX_MESSAGE_GAP = 2000;


/**
 * Advance the root key, creating a new message chain.
 *
 * @param root_key            previous root key R(n-1)
 * @param our_key             our new ratchet key T(n)
 * @param their_key           their most recent ratchet key T(n-1)
 * @param info                table of constants for the ratchet function
 * @param new_root_key[out]   returns the new root key R(n)
 * @param new_chain_key[out]  returns the first chain key in the new chain
 *                            C(n,0)
 */
static void create_chain_key(
    olm::SharedKey const & root_key,
    _olm_curve25519_key_pair const & our_key,
    _olm_curve25519_public_key const & their_key,
    olm::KdfInfo const & info,
    olm::SharedKey & new_root_key,
    olm::ChainKey & new_chain_key
) {
    olm::SharedKey secret;
    _olm_crypto_curve25519_shared_secret(&our_key, &their_key, secret);
    std::uint8_t derived_secrets[2 * olm::OLM_SHARED_KEY_LENGTH];
    _olm_crypto_hkdf_sha256(
        secret, sizeof(secret),
        root_key, sizeof(root_key),
        info.ratchet_info, info.ratchet_info_length,
        derived_secrets, sizeof(derived_secrets)
    );
    std::uint8_t const * pos = derived_secrets;
    pos = olm::load_array(new_root_key, pos);
    pos = olm::load_array(new_chain_key.key, pos);
    new_chain_key.index = 0;
    olm::unset(derived_secrets);
    olm::unset(secret);
}


static void advance_chain_key(
    olm::ChainKey const & chain_key,
    olm::ChainKey & new_chain_key
) {
    _olm_crypto_hmac_sha256(
        chain_key.key, sizeof(chain_key.key),
        CHAIN_KEY_SEED, sizeof(CHAIN_KEY_SEED),
        new_chain_key.key
    );
    new_chain_key.index = chain_key.index + 1;
}


static void create_message_keys(
    olm::ChainKey const & chain_key,
    olm::KdfInfo const & info,
    olm::MessageKey & message_key) {
    _olm_crypto_hmac_sha256(
        chain_key.key, sizeof(chain_key.key),
        MESSAGE_KEY_SEED, sizeof(MESSAGE_KEY_SEED),
        message_key.key
    );
    message_key.index = chain_key.index;
}


static std::size_t verify_mac_and_decrypt(
    _olm_cipher const *cipher,
    olm::MessageKey const & message_key,
    olm::MessageReader const & reader,
    std::uint8_t * plaintext, std::size_t max_plaintext_length
) {
    return cipher->ops->decrypt(
        cipher,
        message_key.key, sizeof(message_key.key),
        reader.input, reader.input_length,
        reader.ciphertext, reader.ciphertext_length,
        plaintext, max_plaintext_length
    );
}


static std::size_t verify_mac_and_decrypt_for_existing_chain(
    olm::Ratchet const & session,
    olm::ChainKey const & chain,
    olm::MessageReader const & reader,
    std::uint8_t * plaintext, std::size_t max_plaintext_length
) {
    if (reader.counter < chain.index) {
        return std::size_t(-1);
    }

    /* Limit the number of hashes we're prepared to compute */
    if (reader.counter - chain.index > MAX_MESSAGE_GAP) {
        return std::size_t(-1);
    }

    olm::ChainKey new_chain = chain;

    while (new_chain.index < reader.counter) {
        advance_chain_key(new_chain, new_chain);
    }

    olm::MessageKey message_key;
    create_message_keys(new_chain, session.kdf_info, message_key);

    std::size_t result = verify_mac_and_decrypt(
        session.ratchet_cipher, message_key, reader,
        plaintext, max_plaintext_length
    );

    olm::unset(new_chain);
    return result;
}


static std::size_t verify_mac_and_decrypt_for_new_chain(
    olm::Ratchet const & session,
    olm::MessageReader const & reader,
    std::uint8_t * plaintext, std::size_t max_plaintext_length
) {
    olm::SharedKey new_root_key;
    olm::ReceiverChain new_chain;

    /* They shouldn't move to a new chain until we've sent them a message
     * acknowledging the last one */
    if (session.sender_chain.empty()) {
        return std::size_t(-1);
    }

    /* Limit the number of hashes we're prepared to compute */
    if (reader.counter > MAX_MESSAGE_GAP) {
        return std::size_t(-1);
    }
    olm::load_array(new_chain.ratchet_key.public_key, reader.ratchet_key);

    create_chain_key(
        session.root_key, session.sender_chain[0].ratchet_key,
        new_chain.ratchet_key, session.kdf_info,
        new_root_key, new_chain.chain_key
    );
    std::size_t result = verify_mac_and_decrypt_for_existing_chain(
        session, new_chain.chain_key, reader,
        plaintext, max_plaintext_length
    );
    olm::unset(new_root_key);
    olm::unset(new_chain);
    return result;
}

} // namespace


olm::Ratchet::Ratchet(
    olm::KdfInfo const & kdf_info,
    _olm_cipher const * ratchet_cipher
) : kdf_info(kdf_info),
    ratchet_cipher(ratchet_cipher),
    last_error(OlmErrorCode::OLM_SUCCESS) {
}


void olm::Ratchet::initialise_as_bob(
    std::uint8_t const * shared_secret, std::size_t shared_secret_length,
    _olm_curve25519_public_key const & their_ratchet_key
) {
    std::uint8_t derived_secrets[2 * olm::OLM_SHARED_KEY_LENGTH];
    _olm_crypto_hkdf_sha256(
        shared_secret, shared_secret_length,
        nullptr, 0,
        kdf_info.root_info, kdf_info.root_info_length,
        derived_secrets, sizeof(derived_secrets)
    );
    receiver_chains.insert();
    receiver_chains[0].chain_key.index = 0;
    std::uint8_t const * pos = derived_secrets;
    pos = olm::load_array(root_key, pos);
    pos = olm::load_array(receiver_chains[0].chain_key.key, pos);
    receiver_chains[0].ratchet_key = their_ratchet_key;
    olm::unset(derived_secrets);
}


void olm::Ratchet::initialise_as_alice(
    std::uint8_t const * shared_secret, std::size_t shared_secret_length,
    _olm_curve25519_key_pair const & our_ratchet_key
) {
    std::uint8_t derived_secrets[2 * olm::OLM_SHARED_KEY_LENGTH];
    _olm_crypto_hkdf_sha256(
        shared_secret, shared_secret_length,
        nullptr, 0,
        kdf_info.root_info, kdf_info.root_info_length,
        derived_secrets, sizeof(derived_secrets)
    );
    sender_chain.insert();
    sender_chain[0].chain_key.index = 0;
    std::uint8_t const * pos = derived_secrets;
    pos = olm::load_array(root_key, pos);
    pos = olm::load_array(sender_chain[0].chain_key.key, pos);
    sender_chain[0].ratchet_key = our_ratchet_key;
    olm::unset(derived_secrets);
}

namespace olm {


static std::size_t pickle_length(
    const olm::SharedKey & value
) {
    return olm::OLM_SHARED_KEY_LENGTH;
}


static std::uint8_t * pickle(
    std::uint8_t * pos,
    const olm::SharedKey & value
) {
    return olm::pickle_bytes(pos, value, olm::OLM_SHARED_KEY_LENGTH);
}


static std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    olm::SharedKey & value
) {
    return olm::unpickle_bytes(pos, end, value, olm::OLM_SHARED_KEY_LENGTH);
}


static std::size_t pickle_length(
    const olm::SenderChain & value
) {
    std::size_t length = 0;
    length += olm::pickle_length(value.ratchet_key);
    length += olm::pickle_length(value.chain_key.key);
    length += olm::pickle_length(value.chain_key.index);
    return length;
}


static std::uint8_t * pickle(
    std::uint8_t * pos,
    const olm::SenderChain & value
) {
    pos = olm::pickle(pos, value.ratchet_key);
    pos = olm::pickle(pos, value.chain_key.key);
    pos = olm::pickle(pos, value.chain_key.index);
    return pos;
}


static std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    olm::SenderChain & value
) {
    pos = olm::unpickle(pos, end, value.ratchet_key);
    pos = olm::unpickle(pos, end, value.chain_key.key);
    pos = olm::unpickle(pos, end, value.chain_key.index);
    return pos;
}

static std::size_t pickle_length(
    const olm::ReceiverChain & value
) {
    std::size_t length = 0;
    length += olm::pickle_length(value.ratchet_key);
    length += olm::pickle_length(value.chain_key.key);
    length += olm::pickle_length(value.chain_key.index);
    return length;
}


static std::uint8_t * pickle(
    std::uint8_t * pos,
    const olm::ReceiverChain & value
) {
    pos = olm::pickle(pos, value.ratchet_key);
    pos = olm::pickle(pos, value.chain_key.key);
    pos = olm::pickle(pos, value.chain_key.index);
    return pos;
}


static std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    olm::ReceiverChain & value
) {
    pos = olm::unpickle(pos, end, value.ratchet_key);
    pos = olm::unpickle(pos, end, value.chain_key.key);
    pos = olm::unpickle(pos, end, value.chain_key.index);
    return pos;
}


static std::size_t pickle_length(
    const olm::SkippedMessageKey & value
) {
    std::size_t length = 0;
    length += olm::pickle_length(value.ratchet_key);
    length += olm::pickle_length(value.message_key.key);
    length += olm::pickle_length(value.message_key.index);
    return length;
}


static std::uint8_t * pickle(
    std::uint8_t * pos,
    const olm::SkippedMessageKey & value
) {
    pos = olm::pickle(pos, value.ratchet_key);
    pos = olm::pickle(pos, value.message_key.key);
    pos = olm::pickle(pos, value.message_key.index);
    return pos;
}


static std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    olm::SkippedMessageKey & value
) {
    pos = olm::unpickle(pos, end, value.ratchet_key);
    pos = olm::unpickle(pos, end, value.message_key.key);
    pos = olm::unpickle(pos, end, value.message_key.index);
    return pos;
}


} // namespace olm


std::size_t olm::pickle_length(
    olm::Ratchet const & value
) {
    std::size_t length = 0;
    length += olm::OLM_SHARED_KEY_LENGTH;
    length += olm::pickle_length(value.sender_chain);
    length += olm::pickle_length(value.receiver_chains);
    length += olm::pickle_length(value.skipped_message_keys);
    return length;
}

std::uint8_t * olm::pickle(
    std::uint8_t * pos,
    olm::Ratchet const & value
) {
    pos = pickle(pos, value.root_key);
    pos = pickle(pos, value.sender_chain);
    pos = pickle(pos, value.receiver_chains);
    pos = pickle(pos, value.skipped_message_keys);
    return pos;
}


std::uint8_t const * olm::unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    olm::Ratchet & value,
    bool includes_chain_index
) {
    pos = unpickle(pos, end, value.root_key);
    pos = unpickle(pos, end, value.sender_chain);
    pos = unpickle(pos, end, value.receiver_chains);
    pos = unpickle(pos, end, value.skipped_message_keys);

    // pickle v 0x80000001 includes a chain index; pickle v1 does not.
    if (includes_chain_index) {
        std::uint32_t dummy;
        pos = unpickle(pos, end, dummy);
    }
    return pos;
}


std::size_t olm::Ratchet::encrypt_output_length(
    std::size_t plaintext_length
) {
    std::size_t counter = 0;
    if (!sender_chain.empty()) {
        counter = sender_chain[0].chain_key.index;
    }
    std::size_t padded = ratchet_cipher->ops->encrypt_ciphertext_length(
        ratchet_cipher,
        plaintext_length
    );
    return olm::encode_message_length(
        counter, CURVE25519_KEY_LENGTH, padded, ratchet_cipher->ops->mac_length(ratchet_cipher)
    );
}


std::size_t olm::Ratchet::encrypt_random_length() {
    return sender_chain.empty() ? CURVE25519_RANDOM_LENGTH : 0;
}


std::size_t olm::Ratchet::encrypt(
    std::uint8_t const * plaintext, std::size_t plaintext_length,
    std::uint8_t const * random, std::size_t random_length,
    std::uint8_t * output, std::size_t max_output_length
) {
    std::size_t output_length = encrypt_output_length(plaintext_length);

    if (random_length < encrypt_random_length()) {
        last_error = OlmErrorCode::OLM_NOT_ENOUGH_RANDOM;
        return std::size_t(-1);
    }
    if (max_output_length < output_length) {
        last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }

    if (sender_chain.empty()) {
        sender_chain.insert();
        _olm_crypto_curve25519_generate_key(random, &sender_chain[0].ratchet_key);
        create_chain_key(
            root_key,
            sender_chain[0].ratchet_key,
            receiver_chains[0].ratchet_key,
            kdf_info,
            root_key, sender_chain[0].chain_key
        );
    }

    MessageKey keys;
    create_message_keys(sender_chain[0].chain_key, kdf_info, keys);
    advance_chain_key(sender_chain[0].chain_key, sender_chain[0].chain_key);

    std::size_t ciphertext_length = ratchet_cipher->ops->encrypt_ciphertext_length(
        ratchet_cipher,
        plaintext_length
    );
    std::uint32_t counter = keys.index;
    _olm_curve25519_public_key const & ratchet_key =
        sender_chain[0].ratchet_key.public_key;

    olm::MessageWriter writer;

    olm::encode_message(
        writer, PROTOCOL_VERSION, counter, CURVE25519_KEY_LENGTH,
        ciphertext_length,
        output
    );

    olm::store_array(writer.ratchet_key, ratchet_key.public_key);

    ratchet_cipher->ops->encrypt(
        ratchet_cipher,
        keys.key, sizeof(keys.key),
        plaintext, plaintext_length,
        writer.ciphertext, ciphertext_length,
        output, output_length
    );

    olm::unset(keys);
    return output_length;
}


std::size_t olm::Ratchet::decrypt_max_plaintext_length(
    std::uint8_t const * input, std::size_t input_length
) {
    olm::MessageReader reader;
    olm::decode_message(
        reader, input, input_length,
        ratchet_cipher->ops->mac_length(ratchet_cipher)
    );

    if (!reader.ciphertext) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
        return std::size_t(-1);
    }

    return ratchet_cipher->ops->decrypt_max_plaintext_length(
        ratchet_cipher, reader.ciphertext_length);
}


std::size_t olm::Ratchet::decrypt(
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * plaintext, std::size_t max_plaintext_length
) {
    olm::MessageReader reader;
    olm::decode_message(
        reader, input, input_length,
        ratchet_cipher->ops->mac_length(ratchet_cipher)
    );

    if (reader.version != PROTOCOL_VERSION) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_VERSION;
        return std::size_t(-1);
    }

    if (!reader.has_counter || !reader.ratchet_key || !reader.ciphertext) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
        return std::size_t(-1);
    }

    std::size_t max_length = ratchet_cipher->ops->decrypt_max_plaintext_length(
        ratchet_cipher,
        reader.ciphertext_length
    );

    if (max_plaintext_length < max_length) {
        last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }

    if (reader.ratchet_key_length != CURVE25519_KEY_LENGTH) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
        return std::size_t(-1);
    }

    ReceiverChain * chain = nullptr;

    for (olm::ReceiverChain & receiver_chain : receiver_chains) {
        if (0 == std::memcmp(
                receiver_chain.ratchet_key.public_key, reader.ratchet_key,
                CURVE25519_KEY_LENGTH
        )) {
            chain = &receiver_chain;
            break;
        }
    }

    std::size_t result = std::size_t(-1);

    if (!chain) {
        result = verify_mac_and_decrypt_for_new_chain(
            *this, reader, plaintext, max_plaintext_length
        );
    } else if (chain->chain_key.index > reader.counter) {
        /* Chain already advanced beyond the key for this message
         * Check if the message keys are in the skipped key list. */
        for (olm::SkippedMessageKey & skipped : skipped_message_keys) {
            if (reader.counter == skipped.message_key.index
                    && 0 == std::memcmp(
                        skipped.ratchet_key.public_key, reader.ratchet_key,
                        CURVE25519_KEY_LENGTH
                    )
            ) {
                /* Found the key for this message. Check the MAC. */

                result = verify_mac_and_decrypt(
                    ratchet_cipher, skipped.message_key, reader,
                    plaintext, max_plaintext_length
                );

                if (result != std::size_t(-1)) {
                    /* Remove the key from the skipped keys now that we've
                     * decoded the message it corresponds to. */
                    olm::unset(skipped);
                    skipped_message_keys.erase(&skipped);
                    return result;
                }
            }
        }
    } else {
        result = verify_mac_and_decrypt_for_existing_chain(
            *this, chain->chain_key,
            reader, plaintext, max_plaintext_length
        );
    }

    if (result == std::size_t(-1)) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_MAC;
        return std::size_t(-1);
    }

    if (!chain) {
        /* They have started using a new ephemeral ratchet key.
         * We need to derive a new set of chain keys.
         * We can discard our previous empheral ratchet key.
         * We will generate a new key when we send the next message. */

        chain = receiver_chains.insert();
        olm::load_array(chain->ratchet_key.public_key, reader.ratchet_key);

        // TODO: we've already done this once, in
        // verify_mac_and_decrypt_for_new_chain(). we could reuse the result.
        create_chain_key(
            root_key, sender_chain[0].ratchet_key, chain->ratchet_key,
            kdf_info, root_key, chain->chain_key
        );

        olm::unset(sender_chain[0]);
        sender_chain.erase(sender_chain.begin());
    }

    while (chain->chain_key.index < reader.counter) {
        olm::SkippedMessageKey & key = *skipped_message_keys.insert();
        create_message_keys(chain->chain_key, kdf_info, key.message_key);
        key.ratchet_key = chain->ratchet_key;
        advance_chain_key(chain->chain_key, chain->chain_key);
    }

    advance_chain_key(chain->chain_key, chain->chain_key);

    return result;
}
