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

#include "olm/inbound_group_session.h"

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
#define PICKLE_VERSION           2
#define SESSION_KEY_VERSION      2
#define SESSION_EXPORT_VERSION   1

struct OlmInboundGroupSession {
    /** our earliest known ratchet value */
    Megolm initial_ratchet;

    /** The most recent ratchet value */
    Megolm latest_ratchet;

    /** The ed25519 signing key */
    struct _olm_ed25519_public_key signing_key;

    /**
     * Have we ever seen any evidence that this is a valid session?
     * (either because the original session share was signed, or because we
     * have subsequently successfully decrypted a message)
     *
     * (We don't do anything with this currently, but we may want to bear it in
     * mind when we consider handling key-shares for sessions we already know
     * about.)
     */
    int signing_key_verified;

    enum OlmErrorCode last_error;
};

size_t olm_inbound_group_session_size(void) {
    return sizeof(OlmInboundGroupSession);
}

OlmInboundGroupSession * olm_inbound_group_session(
    void *memory
) {
    OlmInboundGroupSession *session = memory;
    olm_clear_inbound_group_session(session);
    return session;
}

const char *olm_inbound_group_session_last_error(
    const OlmInboundGroupSession *session
) {
    return _olm_error_to_string(session->last_error);
}

size_t olm_clear_inbound_group_session(
    OlmInboundGroupSession *session
) {
    _olm_unset(session, sizeof(OlmInboundGroupSession));
    return sizeof(OlmInboundGroupSession);
}

#define SESSION_EXPORT_RAW_LENGTH \
    (1 + 4 + MEGOLM_RATCHET_LENGTH + ED25519_PUBLIC_KEY_LENGTH)

#define SESSION_KEY_RAW_LENGTH \
    (1 + 4 + MEGOLM_RATCHET_LENGTH + ED25519_PUBLIC_KEY_LENGTH\
        + ED25519_SIGNATURE_LENGTH)

static size_t _init_group_session_keys(
    OlmInboundGroupSession *session,
    const uint8_t *key_buf,
    int export_format
) {
    const uint8_t expected_version =
        (export_format ? SESSION_EXPORT_VERSION : SESSION_KEY_VERSION);
    const uint8_t *ptr = key_buf;
    size_t version = *ptr++;

    if (version != expected_version) {
        session->last_error = OLM_BAD_SESSION_KEY;
        return (size_t)-1;
    }

    uint32_t counter = 0;
    // Decode counter as a big endian 32-bit number.
    for (unsigned i = 0; i < 4; i++) {
        counter <<= 8; counter |= *ptr++;
    }

    megolm_init(&session->initial_ratchet, ptr, counter);
    megolm_init(&session->latest_ratchet, ptr, counter);

    ptr += MEGOLM_RATCHET_LENGTH;
    memcpy(
        session->signing_key.public_key, ptr, ED25519_PUBLIC_KEY_LENGTH
    );
    ptr += ED25519_PUBLIC_KEY_LENGTH;

    if (!export_format) {
        if (!_olm_crypto_ed25519_verify(&session->signing_key, key_buf,
                                        ptr - key_buf, ptr)) {
            session->last_error = OLM_BAD_SIGNATURE;
            return (size_t)-1;
        }

        /* signed keyshare */
        session->signing_key_verified = 1;
    }
    return 0;
}

size_t olm_init_inbound_group_session(
    OlmInboundGroupSession *session,
    const uint8_t * session_key, size_t session_key_length
) {
    uint8_t key_buf[SESSION_KEY_RAW_LENGTH];
    size_t raw_length = _olm_decode_base64_length(session_key_length);
    size_t result;

    if (raw_length == (size_t)-1) {
        session->last_error = OLM_INVALID_BASE64;
        return (size_t)-1;
    }

    if (raw_length != SESSION_KEY_RAW_LENGTH) {
        session->last_error = OLM_BAD_SESSION_KEY;
        return (size_t)-1;
    }

    _olm_decode_base64(session_key, session_key_length, key_buf);
    result = _init_group_session_keys(session, key_buf, 0);
    _olm_unset(key_buf, SESSION_KEY_RAW_LENGTH);
    return result;
}

size_t olm_import_inbound_group_session(
    OlmInboundGroupSession *session,
    const uint8_t * session_key, size_t session_key_length
) {
    uint8_t key_buf[SESSION_EXPORT_RAW_LENGTH];
    size_t raw_length = _olm_decode_base64_length(session_key_length);
    size_t result;

    if (raw_length == (size_t)-1) {
        session->last_error = OLM_INVALID_BASE64;
        return (size_t)-1;
    }

    if (raw_length != SESSION_EXPORT_RAW_LENGTH) {
        session->last_error = OLM_BAD_SESSION_KEY;
        return (size_t)-1;
    }

    _olm_decode_base64(session_key, session_key_length, key_buf);
    result = _init_group_session_keys(session, key_buf, 1);
    _olm_unset(key_buf, SESSION_EXPORT_RAW_LENGTH);
    return result;
}

static size_t raw_pickle_length(
    const OlmInboundGroupSession *session
) {
    size_t length = 0;
    length += _olm_pickle_uint32_length(PICKLE_VERSION);
    length += megolm_pickle_length(&session->initial_ratchet);
    length += megolm_pickle_length(&session->latest_ratchet);
    length += _olm_pickle_ed25519_public_key_length(&session->signing_key);
    length += _olm_pickle_bool_length(session->signing_key_verified);
    return length;
}

size_t olm_pickle_inbound_group_session_length(
    const OlmInboundGroupSession *session
) {
    return _olm_enc_output_length(raw_pickle_length(session));
}

size_t olm_pickle_inbound_group_session(
    OlmInboundGroupSession *session,
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
    pos = megolm_pickle(&session->initial_ratchet, pos);
    pos = megolm_pickle(&session->latest_ratchet, pos);
    pos = _olm_pickle_ed25519_public_key(pos, &session->signing_key);
    pos = _olm_pickle_bool(pos, session->signing_key_verified);

    return _olm_enc_output(key, key_length, pickled, raw_length);
}

size_t olm_unpickle_inbound_group_session(
    OlmInboundGroupSession *session,
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
    if (pickle_version < 1 || pickle_version > PICKLE_VERSION) {
        session->last_error = OLM_UNKNOWN_PICKLE_VERSION;
        return (size_t)-1;
    }
    pos = megolm_unpickle(&session->initial_ratchet, pos, end);
    pos = megolm_unpickle(&session->latest_ratchet, pos, end);
    pos = _olm_unpickle_ed25519_public_key(pos, end, &session->signing_key);

    if (pickle_version == 1) {
        /* pickle v1 had no signing_key_verified field (all keyshares were
         * verified at import time) */
        session->signing_key_verified = 1;
    } else {
        pos = _olm_unpickle_bool(pos, end, &(session->signing_key_verified));
    }

    if (end != pos) {
        /* We had the wrong number of bytes in the input. */
        session->last_error = OLM_CORRUPTED_PICKLE;
        return (size_t)-1;
    }

    return pickled_length;
}

/**
 * get the max plaintext length in an un-base64-ed message
 */
static size_t _decrypt_max_plaintext_length(
    OlmInboundGroupSession *session,
    uint8_t * message, size_t message_length
) {
    struct _OlmDecodeGroupMessageResults decoded_results;

    _olm_decode_group_message(
        message, message_length,
        megolm_cipher->ops->mac_length(megolm_cipher),
        ED25519_SIGNATURE_LENGTH,
        &decoded_results);

    if (decoded_results.version != OLM_PROTOCOL_VERSION) {
        session->last_error = OLM_BAD_MESSAGE_VERSION;
        return (size_t)-1;
    }

    if (!decoded_results.ciphertext) {
        session->last_error = OLM_BAD_MESSAGE_FORMAT;
        return (size_t)-1;
    }

    return megolm_cipher->ops->decrypt_max_plaintext_length(
        megolm_cipher, decoded_results.ciphertext_length);
}

size_t olm_group_decrypt_max_plaintext_length(
    OlmInboundGroupSession *session,
    uint8_t * message, size_t message_length
) {
    size_t raw_length;

    raw_length = _olm_decode_base64(message, message_length, message);
    if (raw_length == (size_t)-1) {
        session->last_error = OLM_INVALID_BASE64;
        return (size_t)-1;
    }

    return _decrypt_max_plaintext_length(
        session, message, raw_length
    );
}

/**
 * get a copy of the megolm ratchet, advanced
 * to the relevant index. Returns 0 on success, -1 on error
 */
static size_t _get_megolm(
    OlmInboundGroupSession *session, uint32_t message_index, Megolm *result
) {
    /* pick a megolm instance to use. If we're at or beyond the latest ratchet
     * value, use that */
    if ((message_index - session->latest_ratchet.counter) < (1U << 31)) {
        megolm_advance_to(&session->latest_ratchet, message_index);
        *result = session->latest_ratchet;
        return 0;
    } else if ((message_index - session->initial_ratchet.counter) >= (1U << 31)) {
        /* the counter is before our intial ratchet - we can't decode this. */
        session->last_error = OLM_UNKNOWN_MESSAGE_INDEX;
        return (size_t)-1;
    } else {
        /* otherwise, start from the initial megolm. Take a copy so that we
         * don't overwrite the initial megolm */
        *result = session->initial_ratchet;
        megolm_advance_to(result, message_index);
        return 0;
    }
}

/**
 * decrypt an un-base64-ed message
 */
static size_t _decrypt(
    OlmInboundGroupSession *session,
    uint8_t * message, size_t message_length,
    uint8_t * plaintext, size_t max_plaintext_length,
    uint32_t * message_index
) {
    struct _OlmDecodeGroupMessageResults decoded_results;
    size_t max_length, r;
    Megolm megolm;

    _olm_decode_group_message(
        message, message_length,
        megolm_cipher->ops->mac_length(megolm_cipher),
        ED25519_SIGNATURE_LENGTH,
        &decoded_results);

    if (decoded_results.version != OLM_PROTOCOL_VERSION) {
        session->last_error = OLM_BAD_MESSAGE_VERSION;
        return (size_t)-1;
    }

    if (!decoded_results.has_message_index || !decoded_results.ciphertext) {
        session->last_error = OLM_BAD_MESSAGE_FORMAT;
        return (size_t)-1;
    }

    if (message_index != NULL) {
        *message_index = decoded_results.message_index;
    }

    /* verify the signature. We could do this before decoding the message, but
     * we allow for the possibility of future protocol versions which use a
     * different signing mechanism; we would rather throw "BAD_MESSAGE_VERSION"
     * than "BAD_SIGNATURE" in this case.
     */
    message_length -= ED25519_SIGNATURE_LENGTH;
    r = _olm_crypto_ed25519_verify(
        &session->signing_key,
        message, message_length,
        message + message_length
    );
    if (!r) {
        session->last_error = OLM_BAD_SIGNATURE;
        return (size_t)-1;
    }

    max_length = megolm_cipher->ops->decrypt_max_plaintext_length(
        megolm_cipher,
        decoded_results.ciphertext_length
    );
    if (max_plaintext_length < max_length) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    r = _get_megolm(session, decoded_results.message_index, &megolm);
    if (r == (size_t)-1) {
        return r;
    }

    /* now try checking the mac, and decrypting */
    r = megolm_cipher->ops->decrypt(
        megolm_cipher,
        megolm_get_data(&megolm), MEGOLM_RATCHET_LENGTH,
        message, message_length,
        decoded_results.ciphertext, decoded_results.ciphertext_length,
        plaintext, max_plaintext_length
    );

    _olm_unset(&megolm, sizeof(megolm));
    if (r == (size_t)-1) {
        session->last_error = OLM_BAD_MESSAGE_MAC;
        return r;
    }

    /* once we have successfully decrypted a message, set a flag to say the
     * session appears valid. */
    session->signing_key_verified = 1;

    return r;
}

size_t olm_group_decrypt(
    OlmInboundGroupSession *session,
    uint8_t * message, size_t message_length,
    uint8_t * plaintext, size_t max_plaintext_length,
    uint32_t * message_index
) {
    size_t raw_message_length;

    raw_message_length = _olm_decode_base64(message, message_length, message);
    if (raw_message_length == (size_t)-1) {
        session->last_error = OLM_INVALID_BASE64;
        return (size_t)-1;
    }

    return _decrypt(
        session, message, raw_message_length,
        plaintext, max_plaintext_length,
        message_index
    );
}

size_t olm_inbound_group_session_id_length(
    const OlmInboundGroupSession *session
) {
    return _olm_encode_base64_length(GROUP_SESSION_ID_LENGTH);
}

size_t olm_inbound_group_session_id(
    OlmInboundGroupSession *session,
    uint8_t * id, size_t id_length
) {
    if (id_length < olm_inbound_group_session_id_length(session)) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    return _olm_encode_base64(
        session->signing_key.public_key, GROUP_SESSION_ID_LENGTH, id
    );
}

uint32_t olm_inbound_group_session_first_known_index(
    const OlmInboundGroupSession *session
) {
    return session->initial_ratchet.counter;
}

int olm_inbound_group_session_is_verified(
    const OlmInboundGroupSession *session
) {
    return session->signing_key_verified;
}

size_t olm_export_inbound_group_session_length(
    const OlmInboundGroupSession *session
) {
    return _olm_encode_base64_length(SESSION_EXPORT_RAW_LENGTH);
}

size_t olm_export_inbound_group_session(
    OlmInboundGroupSession *session,
    uint8_t * key, size_t key_length, uint32_t message_index
) {
    uint8_t *raw;
    uint8_t *ptr;
    Megolm megolm;
    size_t r;
    size_t encoded_length = olm_export_inbound_group_session_length(session);

    if (key_length < encoded_length) {
        session->last_error = OLM_OUTPUT_BUFFER_TOO_SMALL;
        return (size_t)-1;
    }

    r = _get_megolm(session, message_index, &megolm);
    if (r == (size_t)-1) {
        return r;
    }

    /* put the raw data at the end of the output buffer. */
    raw = ptr = key + encoded_length - SESSION_EXPORT_RAW_LENGTH;
    *ptr++ = SESSION_EXPORT_VERSION;

    // Encode message index as a big endian 32-bit number.
    for (unsigned i = 0; i < 4; i++) {
        *ptr++ = 0xFF & (message_index >> 24); message_index <<= 8;
    }

    memcpy(ptr, megolm_get_data(&megolm), MEGOLM_RATCHET_LENGTH);
    ptr += MEGOLM_RATCHET_LENGTH;

    memcpy(
        ptr, session->signing_key.public_key,
        ED25519_PUBLIC_KEY_LENGTH
    );
    ptr += ED25519_PUBLIC_KEY_LENGTH;

    return _olm_encode_base64(raw, SESSION_EXPORT_RAW_LENGTH, key);
}
