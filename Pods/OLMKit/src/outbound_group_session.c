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

#include "olm/outbound_group_session.h"

#include <string.h>

#include "olm/base64.h"
#include "olm/cipher.h"
#include "olm/crypto.h"
#include "olm/error.h"
#include "olm/megolm.h"
#include "olm/memory.h"
#include "olm/message.h"
#include "olm/pickle.h"
#include "olm/pickle_encoding.h"

#define OLM_PROTOCOL_VERSION     3
#define GROUP_SESSION_ID_LENGTH  ED25519_PUBLIC_KEY_LENGTH
#define PICKLE_VERSION           1
#define SESSION_KEY_VERSION      2

struct OlmOutboundGroupSession {
    /** the Megolm ratchet providing the encryption keys */
    Megolm ratchet;

    /** The ed25519 keypair used for signing the messages */
    struct _olm_ed25519_key_pair signing_key;

    enum OlmErrorCode last_error;
};


size_t olm_outbound_group_session_size(void) {
    return sizeof(OlmOutboundGroupSession);
}

OlmOutboundGroupSession * olm_outbound_group_session(
    void *memory
) {
    OlmOutboundGroupSession *session = memory;
    olm_clear_outbound_group_session(session);
    return session;
}

const char *olm_outbound_group_session_last_error(
    const OlmOutboundGroupSession *session
) {
    return _olm_error_to_string(session->last_error);
}

size_t olm_clear_outbound_group_session(
    OlmOutboundGroupSession *session
) {
    _olm_unset(session, sizeof(OlmOutboundGroupSession));
    return sizeof(OlmOutboundGroupSession);
}

static size_t raw_pickle_length(
    const OlmOutboundGroupSession *session
) {
    size_t length = 0;
    length += _olm_pickle_uint32_length(PICKLE_VERSION);
    length += megolm_pickle_length(&(session->ratchet));
    length += _olm_pickle_ed25519_key_pair_length(&(session->signing_key));
    return length;
}

size_t olm_pickle_outbound_group_session_length(
    const OlmOutboundGroupSession *session
) {
    return _olm_enc_output_length(raw_pickle_length(session));
}

size_t olm_pickle_outbound_group_session(
    OlmOutboundGroupSession *session,
    void const * key, size_t key_length,
    void * pickled, size_t pickled_length
) {
    size_t raw_length = raw_pickle_length(session);
    uint8_t *pos;

    if (pickled_length < _olm_enc_output_length(raw_length)) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    pos = _olm_enc_output_pos(pickled, raw_length);
    pos = _olm_pickle_uint32(pos, PICKLE_VERSION);
    pos = megolm_pickle(&(session->ratchet), pos);
    pos = _olm_pickle_ed25519_key_pair(pos, &(session->signing_key));

    return _olm_enc_output(key, key_length, pickled, raw_length);
}

size_t olm_unpickle_outbound_group_session(
    OlmOutboundGroupSession *session,
    void const * key, size_t key_length,
    void * pickled, size_t pickled_length
) {
    const uint8_t *pos;
    const uint8_t *end;
    uint32_t pickle_version;

    size_t raw_length = _olm_enc_input(
        key, key_length, pickled, pickled_length, &(session->last_error)
    );
    if (raw_length == (size_t)-1) {
        return raw_length;
    }

    pos = pickled;
    end = pos + raw_length;
    pos = _olm_unpickle_uint32(pos, end, &pickle_version);
    if (pickle_version != PICKLE_VERSION) {
        session->last_error = OLM_UNKNOWN_PICKLE_VERSION;
        return (size_t)-1;
    }
    pos = megolm_unpickle(&(session->ratchet), pos, end);
    pos = _olm_unpickle_ed25519_key_pair(pos, end, &(session->signing_key));

    if (end != pos) {
        /* We had the wrong number of bytes in the input. */
        session->last_error = OLM_CORRUPTED_PICKLE;
        return (size_t)-1;
    }

    return pickled_length;
}


size_t olm_init_outbound_group_session_random_length(
    const OlmOutboundGroupSession *session
) {
    /* we need data to initialize the megolm ratchet, plus some more for the
     * session id.
     */
    return MEGOLM_RATCHET_LENGTH +
        ED25519_RANDOM_LENGTH;
}

size_t olm_init_outbound_group_session(
    OlmOutboundGroupSession *session,
    uint8_t *random, size_t random_length
) {
    const uint8_t *random_ptr = random;

    if (random_length < olm_init_outbound_group_session_random_length(session)) {
        /* Insufficient random data for new session */
        session->last_error = OLM_NOT_ENOUGH_RANDOM;
        return (size_t)-1;
    }

    megolm_init(&(session->ratchet), random_ptr, 0);
    random_ptr += MEGOLM_RATCHET_LENGTH;

    _olm_crypto_ed25519_generate_key(random_ptr, &(session->signing_key));
    random_ptr += ED25519_RANDOM_LENGTH;

    _olm_unset(random, random_length);
    return 0;
}

static size_t raw_message_length(
    OlmOutboundGroupSession *session,
    size_t plaintext_length)
{
    size_t ciphertext_length, mac_length;

    ciphertext_length = megolm_cipher->ops->encrypt_ciphertext_length(
        megolm_cipher, plaintext_length
    );

    mac_length = megolm_cipher->ops->mac_length(megolm_cipher);

    return _olm_encode_group_message_length(
        session->ratchet.counter,
        ciphertext_length, mac_length, ED25519_SIGNATURE_LENGTH
    );
}

size_t olm_group_encrypt_message_length(
    OlmOutboundGroupSession *session,
    size_t plaintext_length
) {
    size_t message_length = raw_message_length(session, plaintext_length);
    return _olm_encode_base64_length(message_length);
}

/** write an un-base64-ed message to the buffer */
static size_t _encrypt(
    OlmOutboundGroupSession *session, uint8_t const * plaintext, size_t plaintext_length,
    uint8_t * buffer
) {
    size_t ciphertext_length, mac_length, message_length;
    size_t result;
    uint8_t *ciphertext_ptr;

    ciphertext_length = megolm_cipher->ops->encrypt_ciphertext_length(
        megolm_cipher,
        plaintext_length
    );

    mac_length = megolm_cipher->ops->mac_length(megolm_cipher);

    /* first we build the message structure, then we encrypt
     * the plaintext into it.
     */
    message_length = _olm_encode_group_message(
        OLM_PROTOCOL_VERSION,
        session->ratchet.counter,
        ciphertext_length,
        buffer,
        &ciphertext_ptr);

    message_length += mac_length;

    result = megolm_cipher->ops->encrypt(
        megolm_cipher,
        megolm_get_data(&(session->ratchet)), MEGOLM_RATCHET_LENGTH,
        plaintext, plaintext_length,
        ciphertext_ptr, ciphertext_length,
        buffer, message_length
    );

    if (result == (size_t)-1) {
        return result;
    }

    megolm_advance(&(session->ratchet));

    /* sign the whole thing with the ed25519 key. */
    _olm_crypto_ed25519_sign(
        &(session->signing_key),
        buffer, message_length,
        buffer + message_length
    );

    return result;
}

size_t olm_group_encrypt(
    OlmOutboundGroupSession *session,
    uint8_t const * plaintext, size_t plaintext_length,
    uint8_t * message, size_t max_message_length
) {
    size_t rawmsglen;
    size_t result;
    uint8_t *message_pos;

    rawmsglen = raw_message_length(session, plaintext_length);

    if (max_message_length < _olm_encode_base64_length(rawmsglen)) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    /* we construct the message at the end of the buffer, so that
     * we have room to base64-encode it once we're done.
     */
    message_pos = message + _olm_encode_base64_length(rawmsglen) - rawmsglen;

    /* write the message, and encrypt it, at message_pos */
    result = _encrypt(session, plaintext, plaintext_length, message_pos);
    if (result == (size_t)-1) {
        return result;
    }

    /* bas64-encode it */
    return _olm_encode_base64(
        message_pos, rawmsglen, message
    );
}


size_t olm_outbound_group_session_id_length(
    const OlmOutboundGroupSession *session
) {
    return _olm_encode_base64_length(GROUP_SESSION_ID_LENGTH);
}

size_t olm_outbound_group_session_id(
    OlmOutboundGroupSession *session,
    uint8_t * id, size_t id_length
) {
    if (id_length < olm_outbound_group_session_id_length(session)) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    return _olm_encode_base64(
        session->signing_key.public_key.public_key, GROUP_SESSION_ID_LENGTH, id
    );
}

uint32_t olm_outbound_group_session_message_index(
    OlmOutboundGroupSession *session
) {
    return session->ratchet.counter;
}

#define SESSION_KEY_RAW_LENGTH \
    (1 + 4 + MEGOLM_RATCHET_LENGTH + ED25519_PUBLIC_KEY_LENGTH\
        + ED25519_SIGNATURE_LENGTH)

size_t olm_outbound_group_session_key_length(
    const OlmOutboundGroupSession *session
) {
    return _olm_encode_base64_length(SESSION_KEY_RAW_LENGTH);
}

size_t olm_outbound_group_session_key(
    OlmOutboundGroupSession *session,
    uint8_t * key, size_t key_length
) {
    uint8_t *raw;
    uint8_t *ptr;
    size_t encoded_length = olm_outbound_group_session_key_length(session);

    if (key_length < encoded_length) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    /* put the raw data at the end of the output buffer. */
    raw = ptr = key + encoded_length - SESSION_KEY_RAW_LENGTH;
    *ptr++ = SESSION_KEY_VERSION;

    uint32_t counter = session->ratchet.counter;
    // Encode counter as a big endian 32-bit number.
    for (unsigned i = 0; i < 4; i++) {
        *ptr++ = 0xFF & (counter >> 24); counter <<= 8;
    }

    memcpy(ptr, megolm_get_data(&session->ratchet), MEGOLM_RATCHET_LENGTH);
    ptr += MEGOLM_RATCHET_LENGTH;

    memcpy(
        ptr, session->signing_key.public_key.public_key,
        ED25519_PUBLIC_KEY_LENGTH
    );
    ptr += ED25519_PUBLIC_KEY_LENGTH;

    /* sign the whole thing with the ed25519 key. */
    _olm_crypto_ed25519_sign(
        &(session->signing_key),
        raw, ptr - raw, ptr
    );

    return _olm_encode_base64(raw, SESSION_KEY_RAW_LENGTH, key);
}
