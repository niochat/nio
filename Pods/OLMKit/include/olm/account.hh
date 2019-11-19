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
#ifndef OLM_ACCOUNT_HH_
#define OLM_ACCOUNT_HH_

#include "olm/list.hh"
#include "olm/crypto.h"
#include "olm/error.h"

#include <cstdint>

namespace olm {


struct IdentityKeys {
    _olm_ed25519_key_pair ed25519_key;
    _olm_curve25519_key_pair curve25519_key;
};

struct OneTimeKey {
    std::uint32_t id;
    bool published;
    _olm_curve25519_key_pair key;
};


static std::size_t const MAX_ONE_TIME_KEYS = 100;


struct Account {
    Account();
    IdentityKeys identity_keys;
    List<OneTimeKey, MAX_ONE_TIME_KEYS> one_time_keys;
    std::uint32_t next_one_time_key_id;
    OlmErrorCode last_error;

    /** Number of random bytes needed to create a new account */
    std::size_t new_account_random_length();

    /** Create a new account. Returns std::size_t(-1) on error. If the number of
     * random bytes is too small then last_error will be NOT_ENOUGH_RANDOM */
    std::size_t new_account(
        uint8_t const * random, std::size_t random_length
    );

    /** Number of bytes needed to output the identity keys for this account */
    std::size_t get_identity_json_length();

    /** Output the identity keys for this account as JSON in the following
     * format:
     *
     *    {"curve25519":"<43 base64 characters>"
     *    ,"ed25519":"<43 base64 characters>"
     *    }
     *
     *
     * Returns the size of the JSON written or std::size_t(-1) on error.
     * If the buffer is too small last_error will be OUTPUT_BUFFER_TOO_SMALL. */
    std::size_t get_identity_json(
        std::uint8_t * identity_json, std::size_t identity_json_length
    );

    /**
     * The length of an ed25519 signature in bytes.
     */
    std::size_t signature_length();

    /**
     * Signs a message with the ed25519 key for this account.
     */
    std::size_t sign(
        std::uint8_t const * message, std::size_t message_length,
        std::uint8_t * signature, std::size_t signature_length
    );

    /** Number of bytes needed to output the one time keys for this account */
    std::size_t get_one_time_keys_json_length();

    /** Output the one time keys that haven't been published yet as JSON:
     *
     *  {"curve25519":
     *  ["<6 byte key id>":"<43 base64 characters>"
     *  ,"<6 byte key id>":"<43 base64 characters>"
     *  ...
     *  ]
     *  }
     *
     * Returns the size of the JSON written or std::size_t(-1) on error.
     * If the buffer is too small last_error will be OUTPUT_BUFFER_TOO_SMALL.
     */
    std::size_t get_one_time_keys_json(
        std::uint8_t * one_time_json, std::size_t one_time_json_length
    );

    /** Mark the current list of one_time_keys as being published. They
     * will no longer be returned by get_one_time_keys_json_length(). */
    std::size_t mark_keys_as_published();

    /** The largest number of one time keys this account can store. */
    std::size_t max_number_of_one_time_keys();

    /** The number of random bytes needed to generate a given number of new one
     * time keys. */
    std::size_t generate_one_time_keys_random_length(
        std::size_t number_of_keys
    );

    /** Generates a number of new one time keys. If the total number of keys
     * stored by this account exceeds max_number_of_one_time_keys() then the
     * old keys are discarded. Returns std::size_t(-1) on error. If the number
     * of random bytes is too small then last_error will be NOT_ENOUGH_RANDOM */
    std::size_t generate_one_time_keys(
        std::size_t number_of_keys,
        std::uint8_t const * random, std::size_t random_length
    );

    /** Lookup a one time key with the given public key */
    OneTimeKey const * lookup_key(
        _olm_curve25519_public_key const & public_key
    );

    /** Remove a one time key with the given public key */
    std::size_t remove_key(
        _olm_curve25519_public_key const & public_key
    );
};


std::size_t pickle_length(
    Account const & value
);


std::uint8_t * pickle(
    std::uint8_t * pos,
    Account const & value
);


std::uint8_t const * unpickle(
    std::uint8_t const * pos, std::uint8_t const * end,
    Account & value
);


} // namespace olm

#endif /* OLM_ACCOUNT_HH_ */
