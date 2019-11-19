/* Copyright 2015-2016 OpenMarket Ltd
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
#include "olm/message.hh"

#include "olm/memory.hh"

namespace {

template<typename T>
static std::size_t varint_length(
    T value
) {
    std::size_t result = 1;
    while (value >= 128U) {
        ++result;
        value >>= 7;
    }
    return result;
}


template<typename T>
static std::uint8_t * varint_encode(
    std::uint8_t * output,
    T value
) {
    while (value >= 128U) {
        *(output++) = (0x7F & value) | 0x80;
        value >>= 7;
    }
    (*output++) = value;
    return output;
}


template<typename T>
static T varint_decode(
    std::uint8_t const * varint_start,
    std::uint8_t const * varint_end
) {
    T value = 0;
    if (varint_end == varint_start) {
        return 0;
    }
    do {
        value <<= 7;
        value |= 0x7F & *(--varint_end);
    } while (varint_end != varint_start);
    return value;
}


static std::uint8_t const * varint_skip(
    std::uint8_t const * input,
    std::uint8_t const * input_end
) {
    while (input != input_end) {
        std::uint8_t tmp = *(input++);
        if ((tmp & 0x80) == 0) {
            return input;
        }
    }
    return input;
}


static std::size_t varstring_length(
    std::size_t string_length
) {
    return varint_length(string_length) + string_length;
}

static std::size_t const VERSION_LENGTH = 1;
static std::uint8_t const RATCHET_KEY_TAG = 012;
static std::uint8_t const COUNTER_TAG = 020;
static std::uint8_t const CIPHERTEXT_TAG = 042;

static std::uint8_t * encode(
    std::uint8_t * pos,
    std::uint8_t tag,
    std::uint32_t value
) {
    *(pos++) = tag;
    return varint_encode(pos, value);
}

static std::uint8_t * encode(
    std::uint8_t * pos,
    std::uint8_t tag,
    std::uint8_t * & value, std::size_t value_length
) {
    *(pos++) = tag;
    pos = varint_encode(pos, value_length);
    value = pos;
    return pos + value_length;
}

static std::uint8_t const * decode(
    std::uint8_t const * pos, std::uint8_t const * end,
    std::uint8_t tag,
    std::uint32_t & value, bool & has_value
) {
    if (pos != end && *pos == tag) {
        ++pos;
        std::uint8_t const * value_start = pos;
        pos = varint_skip(pos, end);
        value = varint_decode<std::uint32_t>(value_start, pos);
        has_value = true;
    }
    return pos;
}


static std::uint8_t const * decode(
    std::uint8_t const * pos, std::uint8_t const * end,
    std::uint8_t tag,
    std::uint8_t const * & value, std::size_t & value_length
) {
    if (pos != end && *pos == tag) {
        ++pos;
        std::uint8_t const * len_start = pos;
        pos = varint_skip(pos, end);
        std::size_t len = varint_decode<std::size_t>(len_start, pos);
        if (len > std::size_t(end - pos)) return end;
        value = pos;
        value_length = len;
        pos += len;
    }
    return pos;
}

static std::uint8_t const * skip_unknown(
    std::uint8_t const * pos, std::uint8_t const * end
) {
    if (pos != end) {
        uint8_t tag = *pos;
        if ((tag & 0x7) == 0) {
            pos = varint_skip(pos, end);
            pos = varint_skip(pos, end);
        } else if ((tag & 0x7) == 2) {
            pos = varint_skip(pos, end);
            std::uint8_t const * len_start = pos;
            pos = varint_skip(pos, end);
            std::size_t len = varint_decode<std::size_t>(len_start, pos);
            if (len > std::size_t(end - pos)) return end;
            pos += len;
        } else {
            return end;
        }
    }
    return pos;
}

} // namespace


std::size_t olm::encode_message_length(
    std::uint32_t counter,
    std::size_t ratchet_key_length,
    std::size_t ciphertext_length,
    std::size_t mac_length
) {
    std::size_t length = VERSION_LENGTH;
    length += 1 + varstring_length(ratchet_key_length);
    length += 1 + varint_length(counter);
    length += 1 + varstring_length(ciphertext_length);
    length += mac_length;
    return length;
}


void olm::encode_message(
    olm::MessageWriter & writer,
    std::uint8_t version,
    std::uint32_t counter,
    std::size_t ratchet_key_length,
    std::size_t ciphertext_length,
    std::uint8_t * output
) {
    std::uint8_t * pos = output;
    *(pos++) = version;
    pos = encode(pos, RATCHET_KEY_TAG, writer.ratchet_key, ratchet_key_length);
    pos = encode(pos, COUNTER_TAG, counter);
    pos = encode(pos, CIPHERTEXT_TAG, writer.ciphertext, ciphertext_length);
}


void olm::decode_message(
    olm::MessageReader & reader,
    std::uint8_t const * input, std::size_t input_length,
    std::size_t mac_length
) {
    std::uint8_t const * pos = input;
    std::uint8_t const * end = input + input_length - mac_length;
    std::uint8_t const * unknown = nullptr;

    reader.input = input;
    reader.input_length = input_length;
    reader.has_counter = false;
    reader.ratchet_key = nullptr;
    reader.ratchet_key_length = 0;
    reader.ciphertext = nullptr;
    reader.ciphertext_length = 0;

    if (input_length < mac_length) return;

    if (pos == end) return;
    reader.version = *(pos++);

    while (pos != end) {
        unknown = pos;
        pos = decode(
            pos, end, RATCHET_KEY_TAG,
            reader.ratchet_key, reader.ratchet_key_length
        );
        pos = decode(
            pos, end, COUNTER_TAG,
            reader.counter, reader.has_counter
        );
        pos = decode(
            pos, end, CIPHERTEXT_TAG,
            reader.ciphertext, reader.ciphertext_length
        );
        if (unknown == pos) {
            pos = skip_unknown(pos, end);
        }
    }
}


namespace {

static std::uint8_t const ONE_TIME_KEY_ID_TAG = 012;
static std::uint8_t const BASE_KEY_TAG = 022;
static std::uint8_t const IDENTITY_KEY_TAG = 032;
static std::uint8_t const MESSAGE_TAG = 042;

} // namespace


std::size_t olm::encode_one_time_key_message_length(
    std::size_t one_time_key_length,
    std::size_t identity_key_length,
    std::size_t base_key_length,
    std::size_t message_length
) {
    std::size_t length = VERSION_LENGTH;
    length += 1 + varstring_length(one_time_key_length);
    length += 1 + varstring_length(identity_key_length);
    length += 1 + varstring_length(base_key_length);
    length += 1 + varstring_length(message_length);
    return length;
}


void olm::encode_one_time_key_message(
    olm::PreKeyMessageWriter & writer,
    std::uint8_t version,
    std::size_t identity_key_length,
    std::size_t base_key_length,
    std::size_t one_time_key_length,
    std::size_t message_length,
    std::uint8_t * output
) {
    std::uint8_t * pos = output;
    *(pos++) = version;
    pos = encode(pos, ONE_TIME_KEY_ID_TAG, writer.one_time_key, one_time_key_length);
    pos = encode(pos, BASE_KEY_TAG, writer.base_key, base_key_length);
    pos = encode(pos, IDENTITY_KEY_TAG, writer.identity_key, identity_key_length);
    pos = encode(pos, MESSAGE_TAG, writer.message, message_length);
}


void olm::decode_one_time_key_message(
    PreKeyMessageReader & reader,
    std::uint8_t const * input, std::size_t input_length
) {
    std::uint8_t const * pos = input;
    std::uint8_t const * end = input + input_length;
    std::uint8_t const * unknown = nullptr;

    reader.one_time_key = nullptr;
    reader.one_time_key_length = 0;
    reader.identity_key = nullptr;
    reader.identity_key_length = 0;
    reader.base_key = nullptr;
    reader.base_key_length = 0;
    reader.message = nullptr;
    reader.message_length = 0;

    if (pos == end) return;
    reader.version = *(pos++);

    while (pos != end) {
        unknown = pos;
        pos = decode(
            pos, end, ONE_TIME_KEY_ID_TAG,
            reader.one_time_key, reader.one_time_key_length
        );
        pos = decode(
            pos, end, BASE_KEY_TAG,
            reader.base_key, reader.base_key_length
        );
        pos = decode(
            pos, end, IDENTITY_KEY_TAG,
            reader.identity_key, reader.identity_key_length
        );
        pos = decode(
            pos, end, MESSAGE_TAG,
            reader.message, reader.message_length
        );
        if (unknown == pos) {
            pos = skip_unknown(pos, end);
        }
    }
}



static const std::uint8_t GROUP_MESSAGE_INDEX_TAG = 010;
static const std::uint8_t GROUP_CIPHERTEXT_TAG = 022;

size_t _olm_encode_group_message_length(
    uint32_t message_index,
    size_t ciphertext_length,
    size_t mac_length,
    size_t signature_length
) {
    size_t length = VERSION_LENGTH;
    length += 1 + varint_length(message_index);
    length += 1 + varstring_length(ciphertext_length);
    length += mac_length;
    length += signature_length;
    return length;
}


size_t _olm_encode_group_message(
    uint8_t version,
    uint32_t message_index,
    size_t ciphertext_length,
    uint8_t *output,
    uint8_t **ciphertext_ptr
) {
    std::uint8_t * pos = output;

    *(pos++) = version;
    pos = encode(pos, GROUP_MESSAGE_INDEX_TAG, message_index);
    pos = encode(pos, GROUP_CIPHERTEXT_TAG, *ciphertext_ptr, ciphertext_length);
    return pos-output;
}

void _olm_decode_group_message(
    const uint8_t *input, size_t input_length,
    size_t mac_length, size_t signature_length,
    struct _OlmDecodeGroupMessageResults *results
) {
    std::uint8_t const * pos = input;
    std::size_t trailer_length = mac_length + signature_length;
    std::uint8_t const * end = input + input_length - trailer_length;
    std::uint8_t const * unknown = nullptr;

    bool has_message_index = false;
    results->message_index = 0;
    results->ciphertext = nullptr;
    results->ciphertext_length = 0;

    if (input_length < trailer_length) return;

    if (pos == end) return;
    results->version = *(pos++);

    while (pos != end) {
        unknown = pos;
        pos = decode(
            pos, end, GROUP_MESSAGE_INDEX_TAG,
            results->message_index, has_message_index
        );
        pos = decode(
            pos, end, GROUP_CIPHERTEXT_TAG,
            results->ciphertext, results->ciphertext_length
        );
        if (unknown == pos) {
            pos = skip_unknown(pos, end);
        }
    }

    results->has_message_index = (int)has_message_index;
}
