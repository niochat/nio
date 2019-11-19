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


/**
 * functions for encoding and decoding messages in the Olm protocol.
 *
 * Some of these functions have plain-C bindings, and are declared in
 * message.h; in time, all of the functions declared here should probably be
 * converted to plain C and moved to message.h.
 */

#include "message.h"

#include <cstddef>
#include <cstdint>


namespace olm {

/**
 * The length of the buffer needed to hold a message.
 */
std::size_t encode_message_length(
    std::uint32_t counter,
    std::size_t ratchet_key_length,
    std::size_t ciphertext_length,
    std::size_t mac_length
);


struct MessageWriter {
    std::uint8_t * ratchet_key;
    std::uint8_t * ciphertext;
};


struct MessageReader {
    std::uint8_t version;
    bool has_counter;
    std::uint32_t counter;
    std::uint8_t const * input; std::size_t input_length;
    std::uint8_t const * ratchet_key; std::size_t ratchet_key_length;
    std::uint8_t const * ciphertext; std::size_t ciphertext_length;
};


/**
 * Writes the message headers into the output buffer.
 * Populates the writer struct with pointers into the output buffer.
 */
void encode_message(
    MessageWriter & writer,
    std::uint8_t version,
    std::uint32_t counter,
    std::size_t ratchet_key_length,
    std::size_t ciphertext_length,
    std::uint8_t * output
);


/**
 * Reads the message headers from the input buffer.
 * Populates the reader struct with pointers into the input buffer.
 */
void decode_message(
    MessageReader & reader,
    std::uint8_t const * input, std::size_t input_length,
    std::size_t mac_length
);


struct PreKeyMessageWriter {
    std::uint8_t * identity_key;
    std::uint8_t * base_key;
    std::uint8_t * one_time_key;
    std::uint8_t * message;
};


struct PreKeyMessageReader {
    std::uint8_t version;
    std::uint8_t const * identity_key; std::size_t identity_key_length;
    std::uint8_t const * base_key; std::size_t base_key_length;
    std::uint8_t const * one_time_key; std::size_t one_time_key_length;
    std::uint8_t const * message; std::size_t message_length;
};


/**
 * The length of the buffer needed to hold a message.
 */
std::size_t encode_one_time_key_message_length(
    std::size_t identity_key_length,
    std::size_t base_key_length,
    std::size_t one_time_key_length,
    std::size_t message_length
);


/**
 * Writes the message headers into the output buffer.
 * Populates the writer struct with pointers into the output buffer.
 */
void encode_one_time_key_message(
    PreKeyMessageWriter & writer,
    std::uint8_t version,
    std::size_t identity_key_length,
    std::size_t base_key_length,
    std::size_t one_time_key_length,
    std::size_t message_length,
    std::uint8_t * output
);


/**
 * Reads the message headers from the input buffer.
 * Populates the reader struct with pointers into the input buffer.
 */
void decode_one_time_key_message(
    PreKeyMessageReader & reader,
    std::uint8_t const * input, std::size_t input_length
);


} // namespace olm
