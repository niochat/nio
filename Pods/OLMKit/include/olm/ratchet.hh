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

#include <cstdint>

#include "olm/crypto.h"
#include "olm/list.hh"
#include "olm/error.h"

struct _olm_cipher;

namespace olm {

/** length of a shared key: the root key R(i), chain key C(i,j), and message key
 * M(i,j)). They are all only used to stuff into HMACs, so could be any length
 * for that. The chain key and message key are both derived from SHA256
 * operations, so their length is determined by that. */
const std::size_t OLM_SHARED_KEY_LENGTH = SHA256_OUTPUT_LENGTH;

typedef std::uint8_t SharedKey[OLM_SHARED_KEY_LENGTH];

struct ChainKey {
    std::uint32_t index;
    SharedKey key;
};

struct MessageKey {
    std::uint32_t index;
    SharedKey key;
};


struct SenderChain {
    _olm_curve25519_key_pair ratchet_key;
    ChainKey chain_key;
};


struct ReceiverChain {
    _olm_curve25519_public_key ratchet_key;
    ChainKey chain_key;
};


struct SkippedMessageKey {
    _olm_curve25519_public_key ratchet_key;
    MessageKey message_key;
};


static std::size_t const MAX_RECEIVER_CHAINS = 5;
static std::size_t const MAX_SKIPPED_MESSAGE_KEYS = 40;


struct KdfInfo {
    std::uint8_t const * root_info;
    std::size_t root_info_length;
    std::uint8_t const * ratchet_info;
    std::size_t ratchet_info_length;
};


struct Ratchet {

    Ratchet(
        KdfInfo const & kdf_info,
        _olm_cipher const *ratchet_cipher
    );

    /** A some strings identifying the application to feed into the KDF. */
    KdfInfo const & kdf_info;

    /** The AEAD cipher to use for encrypting messages. */
    _olm_cipher const *ratchet_cipher;

    /** The last error that happened encrypting or decrypting a message. */
    OlmErrorCode last_error;

    /** The root key is used to generate chain keys from the ephemeral keys.
     * A new root_key derived each time a new chain is started. */
    SharedKey root_key;

    /** The sender chain is used to send messages. Each time a new ephemeral
     * key is received from the remote server we generate a new sender chain
     * with a new empheral key when we next send a message. */
    List<SenderChain, 1> sender_chain;

    /** The receiver chain is used to decrypt received messages. We store the
     * last few chains so we can decrypt any out of order messages we haven't
     * received yet. */
    List<ReceiverChain, MAX_RECEIVER_CHAINS> receiver_chains;

    /** List of message keys we've skipped over when advancing the receiver
     * chain. */
    List<SkippedMessageKey, MAX_SKIPPED_MESSAGE_KEYS> skipped_message_keys;

    /** Initialise the session using a shared secret and the public part of the
     * remote's first ratchet key */
    void initialise_as_bob(
        std::uint8_t const * shared_secret, std::size_t shared_secret_length,
        _olm_curve25519_public_key const & their_ratchet_key
    );

    /** Initialise the session using a shared secret and the public/private key
     * pair for the first ratchet key */
    void initialise_as_alice(
        std::uint8_t const * shared_secret, std::size_t shared_secret_length,
        _olm_curve25519_key_pair const & our_ratchet_key
    );

    /** The number of bytes of output the encrypt method will write for
     * a given message length. */
    std::size_t encrypt_output_length(
        std::size_t plaintext_length
    );

    /** The number of bytes of random data the encrypt method will need to
     * encrypt a message. This will be 32 bytes if the session needs to
     * generate a new ephemeral key, or will be 0 bytes otherwise.*/
    std::size_t encrypt_random_length();

    /** Encrypt some plain-text. Returns the length of the encrypted message
     * or std::size_t(-1) on failure. On failure last_error will be set with
     * an error code. The last_error will be NOT_ENOUGH_RANDOM if the number
     * of random bytes is too small. The last_error will be
     * OUTPUT_BUFFER_TOO_SMALL if the output buffer is too small. */
    std::size_t encrypt(
        std::uint8_t const * plaintext, std::size_t plaintext_length,
        std::uint8_t const * random, std::size_t random_length,
        std::uint8_t * output, std::size_t max_output_length
    );

    /** An upper bound on the number of bytes of plain-text the decrypt method
     * will write for a given input message length. */
    std::size_t decrypt_max_plaintext_length(
        std::uint8_t const * input, std::size_t input_length
    );

    /** Decrypt a message. Returns the length of the decrypted plain-text or
     * std::size_t(-1) on failure. On failure last_error will be set with an
     * error code. The last_error will be OUTPUT_BUFFER_TOO_SMALL if the
     * plain-text buffer is too small. The last_error will be
     * BAD_MESSAGE_VERSION if the message was encrypted with an unsupported
     * version of the protocol. The last_error will be BAD_MESSAGE_FORMAT if
     * the message headers could not be decoded. The last_error will be
     * BAD_MESSAGE_MAC if the message could not be verified */
    std::size_t decrypt(
        std::uint8_t const * input, std::size_t input_length,
        std::uint8_t * plaintext, std::size_t max_plaintext_length
    );
};


std::size_t pickle_length(
    Ratchet const & value
);


std::uint8_t * pickle(
    std::uint8_t * pos,
    Ratchet const & value
);


std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    Ratchet & value,
    bool includes_chain_index
);


} // namespace olm
