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
#include "olm/session.hh"
#include "olm/cipher.h"
#include "olm/crypto.h"
#include "olm/account.hh"
#include "olm/memory.hh"
#include "olm/message.hh"
#include "olm/pickle.hh"

#include <cstring>

namespace {

static const std::uint8_t PROTOCOL_VERSION = 0x3;

static const std::uint8_t ROOT_KDF_INFO[] = "OLM_ROOT";
static const std::uint8_t RATCHET_KDF_INFO[] = "OLM_RATCHET";
static const std::uint8_t CIPHER_KDF_INFO[] = "OLM_KEYS";

static const olm::KdfInfo OLM_KDF_INFO = {
    ROOT_KDF_INFO, sizeof(ROOT_KDF_INFO) - 1,
    RATCHET_KDF_INFO, sizeof(RATCHET_KDF_INFO) - 1
};

static const struct _olm_cipher_aes_sha_256 OLM_CIPHER =
    OLM_CIPHER_INIT_AES_SHA_256(CIPHER_KDF_INFO);

} // namespace

olm::Session::Session(
) : ratchet(OLM_KDF_INFO, OLM_CIPHER_BASE(&OLM_CIPHER)),
    last_error(OlmErrorCode::OLM_SUCCESS),
    received_message(false) {

}


std::size_t olm::Session::new_outbound_session_random_length() {
    return CURVE25519_RANDOM_LENGTH * 2;
}


std::size_t olm::Session::new_outbound_session(
    olm::Account const & local_account,
    _olm_curve25519_public_key const & identity_key,
    _olm_curve25519_public_key const & one_time_key,
    std::uint8_t const * random, std::size_t random_length
) {
    if (random_length < new_outbound_session_random_length()) {
        last_error = OlmErrorCode::OLM_NOT_ENOUGH_RANDOM;
        return std::size_t(-1);
    }

    _olm_curve25519_key_pair base_key;
    _olm_crypto_curve25519_generate_key(random, &base_key);

    _olm_curve25519_key_pair ratchet_key;
    _olm_crypto_curve25519_generate_key(random + CURVE25519_RANDOM_LENGTH, &ratchet_key);

    _olm_curve25519_key_pair const & alice_identity_key_pair = (
        local_account.identity_keys.curve25519_key
    );

    received_message = false;
    alice_identity_key = alice_identity_key_pair.public_key;
    alice_base_key = base_key.public_key;
    bob_one_time_key = one_time_key;

    // Calculate the shared secret S via triple DH
    std::uint8_t secret[3 * CURVE25519_SHARED_SECRET_LENGTH];
    std::uint8_t * pos = secret;

    _olm_crypto_curve25519_shared_secret(&alice_identity_key_pair, &one_time_key, pos);
    pos += CURVE25519_SHARED_SECRET_LENGTH;
    _olm_crypto_curve25519_shared_secret(&base_key, &identity_key, pos);
    pos += CURVE25519_SHARED_SECRET_LENGTH;
    _olm_crypto_curve25519_shared_secret(&base_key, &one_time_key, pos);

    ratchet.initialise_as_alice(secret, sizeof(secret), ratchet_key);

    olm::unset(base_key);
    olm::unset(ratchet_key);
    olm::unset(secret);

    return std::size_t(0);
}

namespace {

static bool check_message_fields(
    olm::PreKeyMessageReader & reader, bool have_their_identity_key
) {
    bool ok = true;
    ok = ok && (have_their_identity_key || reader.identity_key);
    if (reader.identity_key) {
        ok = ok && reader.identity_key_length == CURVE25519_KEY_LENGTH;
    }
    ok = ok && reader.message;
    ok = ok && reader.base_key;
    ok = ok && reader.base_key_length == CURVE25519_KEY_LENGTH;
    ok = ok && reader.one_time_key;
    ok = ok && reader.one_time_key_length == CURVE25519_KEY_LENGTH;
    return ok;
}

} // namespace


std::size_t olm::Session::new_inbound_session(
    olm::Account & local_account,
    _olm_curve25519_public_key const * their_identity_key,
    std::uint8_t const * one_time_key_message, std::size_t message_length
) {
    olm::PreKeyMessageReader reader;
    decode_one_time_key_message(reader, one_time_key_message, message_length);

    if (!check_message_fields(reader, their_identity_key)) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
        return std::size_t(-1);
    }

    if (reader.identity_key && their_identity_key) {
        bool same = 0 == std::memcmp(
            their_identity_key->public_key, reader.identity_key, CURVE25519_KEY_LENGTH
        );
        if (!same) {
            last_error = OlmErrorCode::OLM_BAD_MESSAGE_KEY_ID;
            return std::size_t(-1);
        }
    }

    olm::load_array(alice_identity_key.public_key, reader.identity_key);
    olm::load_array(alice_base_key.public_key, reader.base_key);
    olm::load_array(bob_one_time_key.public_key, reader.one_time_key);

    olm::MessageReader message_reader;
    decode_message(
        message_reader, reader.message, reader.message_length,
        ratchet.ratchet_cipher->ops->mac_length(ratchet.ratchet_cipher)
    );

    if (!message_reader.ratchet_key
            || message_reader.ratchet_key_length != CURVE25519_KEY_LENGTH) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
        return std::size_t(-1);
    }

    _olm_curve25519_public_key ratchet_key;
    olm::load_array(ratchet_key.public_key, message_reader.ratchet_key);

    olm::OneTimeKey const * our_one_time_key = local_account.lookup_key(
        bob_one_time_key
    );

    if (!our_one_time_key) {
        last_error = OlmErrorCode::OLM_BAD_MESSAGE_KEY_ID;
        return std::size_t(-1);
    }

    _olm_curve25519_key_pair const & bob_identity_key = (
        local_account.identity_keys.curve25519_key
    );
    _olm_curve25519_key_pair const & bob_one_time_key = our_one_time_key->key;

    // Calculate the shared secret S via triple DH
    std::uint8_t secret[CURVE25519_SHARED_SECRET_LENGTH * 3];
    std::uint8_t * pos = secret;
    _olm_crypto_curve25519_shared_secret(&bob_one_time_key, &alice_identity_key, pos);
    pos += CURVE25519_SHARED_SECRET_LENGTH;
    _olm_crypto_curve25519_shared_secret(&bob_identity_key, &alice_base_key, pos);
    pos += CURVE25519_SHARED_SECRET_LENGTH;
    _olm_crypto_curve25519_shared_secret(&bob_one_time_key, &alice_base_key, pos);

    ratchet.initialise_as_bob(secret, sizeof(secret), ratchet_key);

    olm::unset(secret);

    return std::size_t(0);
}


std::size_t olm::Session::session_id_length() {
    return SHA256_OUTPUT_LENGTH;
}


std::size_t olm::Session::session_id(
    std::uint8_t * id, std::size_t id_length
) {
    if (id_length < session_id_length()) {
        last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    std::uint8_t tmp[CURVE25519_KEY_LENGTH * 3];
    std::uint8_t * pos = tmp;
    pos = olm::store_array(pos, alice_identity_key.public_key);
    pos = olm::store_array(pos, alice_base_key.public_key);
    pos = olm::store_array(pos, bob_one_time_key.public_key);
    _olm_crypto_sha256(tmp, sizeof(tmp), id);
    return session_id_length();
}


bool olm::Session::matches_inbound_session(
    _olm_curve25519_public_key const * their_identity_key,
    std::uint8_t const * one_time_key_message, std::size_t message_length
) {
    olm::PreKeyMessageReader reader;
    decode_one_time_key_message(reader, one_time_key_message, message_length);

    if (!check_message_fields(reader, their_identity_key)) {
        return false;
    }

    bool same = true;
    if (reader.identity_key) {
        same = same && 0 == std::memcmp(
            reader.identity_key, alice_identity_key.public_key, CURVE25519_KEY_LENGTH
        );
    }
    if (their_identity_key) {
        same = same && 0 == std::memcmp(
            their_identity_key->public_key, alice_identity_key.public_key,
            CURVE25519_KEY_LENGTH
        );
    }
    same = same && 0 == std::memcmp(
        reader.base_key, alice_base_key.public_key, CURVE25519_KEY_LENGTH
    );
    same = same && 0 == std::memcmp(
        reader.one_time_key, bob_one_time_key.public_key, CURVE25519_KEY_LENGTH
    );
    return same;
}


olm::MessageType olm::Session::encrypt_message_type() {
    if (received_message) {
        return olm::MessageType::MESSAGE;
    } else {
        return olm::MessageType::PRE_KEY;
    }
}


std::size_t olm::Session::encrypt_message_length(
    std::size_t plaintext_length
) {
    std::size_t message_length = ratchet.encrypt_output_length(
        plaintext_length
    );

    if (received_message) {
        return message_length;
    }

    return encode_one_time_key_message_length(
        CURVE25519_KEY_LENGTH,
        CURVE25519_KEY_LENGTH,
        CURVE25519_KEY_LENGTH,
        message_length
    );
}


std::size_t olm::Session::encrypt_random_length() {
    return ratchet.encrypt_random_length();
}


std::size_t olm::Session::encrypt(
    std::uint8_t const * plaintext, std::size_t plaintext_length,
    std::uint8_t const * random, std::size_t random_length,
    std::uint8_t * message, std::size_t message_length
) {
    if (message_length < encrypt_message_length(plaintext_length)) {
        last_error = OlmErrorCode::OLM_OUTPUT_BUFFER_TOO_SMALL;
        return std::size_t(-1);
    }
    std::uint8_t * message_body;
    std::size_t message_body_length = ratchet.encrypt_output_length(
        plaintext_length
    );

    if (received_message) {
        message_body = message;
    } else {
        olm::PreKeyMessageWriter writer;
        encode_one_time_key_message(
            writer,
            PROTOCOL_VERSION,
            CURVE25519_KEY_LENGTH,
            CURVE25519_KEY_LENGTH,
            CURVE25519_KEY_LENGTH,
            message_body_length,
            message
        );
        olm::store_array(writer.one_time_key, bob_one_time_key.public_key);
        olm::store_array(writer.identity_key, alice_identity_key.public_key);
        olm::store_array(writer.base_key, alice_base_key.public_key);
        message_body = writer.message;
    }

    std::size_t result = ratchet.encrypt(
        plaintext, plaintext_length,
        random, random_length,
        message_body, message_body_length
    );

    if (result == std::size_t(-1)) {
        last_error = ratchet.last_error;
        ratchet.last_error = OlmErrorCode::OLM_SUCCESS;
        return result;
    }

    return result;
}


std::size_t olm::Session::decrypt_max_plaintext_length(
    MessageType message_type,
    std::uint8_t const * message, std::size_t message_length
) {
    std::uint8_t const * message_body;
    std::size_t message_body_length;
    if (message_type == olm::MessageType::MESSAGE) {
        message_body = message;
        message_body_length = message_length;
    } else {
        olm::PreKeyMessageReader reader;
        decode_one_time_key_message(reader, message, message_length);
        if (!reader.message) {
            last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
            return std::size_t(-1);
        }
        message_body = reader.message;
        message_body_length = reader.message_length;
    }

    std::size_t result = ratchet.decrypt_max_plaintext_length(
        message_body, message_body_length
    );

    if (result == std::size_t(-1)) {
        last_error = ratchet.last_error;
        ratchet.last_error = OlmErrorCode::OLM_SUCCESS;
    }
    return result;
}


std::size_t olm::Session::decrypt(
    olm::MessageType message_type,
    std::uint8_t const * message, std::size_t message_length,
    std::uint8_t * plaintext, std::size_t max_plaintext_length
) {
    std::uint8_t const * message_body;
    std::size_t message_body_length;
    if (message_type == olm::MessageType::MESSAGE) {
        message_body = message;
        message_body_length = message_length;
    } else {
        olm::PreKeyMessageReader reader;
        decode_one_time_key_message(reader, message, message_length);
        if (!reader.message) {
            last_error = OlmErrorCode::OLM_BAD_MESSAGE_FORMAT;
            return std::size_t(-1);
        }
        message_body = reader.message;
        message_body_length = reader.message_length;
    }

    std::size_t result = ratchet.decrypt(
        message_body, message_body_length, plaintext, max_plaintext_length
    );

    if (result == std::size_t(-1)) {
        last_error = ratchet.last_error;
        ratchet.last_error = OlmErrorCode::OLM_SUCCESS;
        return result;
    }

    received_message = true;
    return result;
}

namespace {
// the master branch writes pickle version 1; the logging_enabled branch writes
// 0x80000001.
static const std::uint32_t SESSION_PICKLE_VERSION = 1;
}

std::size_t olm::pickle_length(
    Session const & value
) {
    std::size_t length = 0;
    length += olm::pickle_length(SESSION_PICKLE_VERSION);
    length += olm::pickle_length(value.received_message);
    length += olm::pickle_length(value.alice_identity_key);
    length += olm::pickle_length(value.alice_base_key);
    length += olm::pickle_length(value.bob_one_time_key);
    length += olm::pickle_length(value.ratchet);
    return length;
}


std::uint8_t * olm::pickle(
    std::uint8_t * pos,
    Session const & value
) {
    pos = olm::pickle(pos, SESSION_PICKLE_VERSION);
    pos = olm::pickle(pos, value.received_message);
    pos = olm::pickle(pos, value.alice_identity_key);
    pos = olm::pickle(pos, value.alice_base_key);
    pos = olm::pickle(pos, value.bob_one_time_key);
    pos = olm::pickle(pos, value.ratchet);
    return pos;
}


std::uint8_t const * olm::unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    Session & value
) {
    uint32_t pickle_version;
    pos = olm::unpickle(pos, end, pickle_version);

    bool includes_chain_index;
    switch (pickle_version) {
        case 1:
            includes_chain_index = false;
            break;

        case 0x80000001UL:
            includes_chain_index = true;
            break;

        default:
            value.last_error = OlmErrorCode::OLM_UNKNOWN_PICKLE_VERSION;
            return end;
    }

    pos = olm::unpickle(pos, end, value.received_message);
    pos = olm::unpickle(pos, end, value.alice_identity_key);
    pos = olm::unpickle(pos, end, value.alice_base_key);
    pos = olm::unpickle(pos, end, value.bob_one_time_key);
    pos = olm::unpickle(pos, end, value.ratchet, includes_chain_index);
    return pos;
}
