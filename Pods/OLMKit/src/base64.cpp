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
#include "olm/base64.h"
#include "olm/base64.hh"

namespace {

static const std::uint8_t ENCODE_BASE64[64] = {
    0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
    0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50,
    0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
    0x59, 0x5A, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66,
    0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E,
    0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76,
    0x77, 0x78, 0x79, 0x7A, 0x30, 0x31, 0x32, 0x33,
    0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x2B, 0x2F,
};

static const std::uint8_t E = -1;

static const std::uint8_t DECODE_BASE64[128] = {
/*  0x0 0x1 0x2 0x3 0x4 0x5 0x6 0x7 0x8 0x9 0xA 0xB 0xC 0xD 0xE 0xF */
     E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,
     E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E,
     E,  E,  E,  E,  E,  E,  E,  E,  E,  E,  E, 62,  E,  E,  E, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61,  E,  E,  E,  E,  E,  E,
     E,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,  E,  E,  E,  E,  E,
     E, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,  E,  E,  E,  E,  E,
};

} // namespace


std::size_t olm::encode_base64_length(
    std::size_t input_length
) {
    return 4 * ((input_length + 2) / 3) + (input_length + 2) % 3 - 2;
}

std::uint8_t * olm::encode_base64(
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output
) {
    std::uint8_t const * end = input + (input_length / 3) * 3;
    std::uint8_t const * pos = input;
    while (pos != end) {
        unsigned value = pos[0];
        value <<= 8; value |= pos[1];
        value <<= 8; value |= pos[2];
        pos += 3;
        output[3] = ENCODE_BASE64[value & 0x3F];
        value >>= 6; output[2] = ENCODE_BASE64[value & 0x3F];
        value >>= 6; output[1] = ENCODE_BASE64[value & 0x3F];
        value >>= 6; output[0] = ENCODE_BASE64[value];
        output += 4;
    }
    unsigned remainder = input + input_length - pos;
    std::uint8_t * result = output;
    if (remainder) {
        unsigned value = pos[0];
        if (remainder == 2) {
            value <<= 8; value |= pos[1];
            value <<= 2;
            output[2] = ENCODE_BASE64[value & 0x3F];
            value >>= 6;
            result += 3;
        } else {
            value <<= 4;
            result += 2;
        }
        output[1] = ENCODE_BASE64[value & 0x3F];
        value >>= 6;
        output[0] = ENCODE_BASE64[value];
    }
    return result;
}


std::size_t olm::decode_base64_length(
    std::size_t input_length
) {
    if (input_length % 4 == 1) {
        return std::size_t(-1);
    } else {
        return 3 * ((input_length + 2) / 4) + (input_length + 2) % 4 - 2;
    }
}


std::uint8_t const * olm::decode_base64(
    std::uint8_t const * input, std::size_t input_length,
    std::uint8_t * output
) {
    std::uint8_t const * end = input + (input_length / 4) * 4;
    std::uint8_t const * pos = input;
    while (pos != end) {
        unsigned value = DECODE_BASE64[pos[0] & 0x7F];
        value <<= 6; value |= DECODE_BASE64[pos[1] & 0x7F];
        value <<= 6; value |= DECODE_BASE64[pos[2] & 0x7F];
        value <<= 6; value |= DECODE_BASE64[pos[3] & 0x7F];
        pos += 4;
        output[2] = value;
        value >>= 8; output[1] = value;
        value >>= 8; output[0] = value;
        output += 3;
    }
    unsigned remainder = input + input_length - pos;
    if (remainder) {
        unsigned value = DECODE_BASE64[pos[0] & 0x7F];
        value <<= 6; value |= DECODE_BASE64[pos[1] & 0x7F];
        if (remainder == 3) {
            value <<= 6; value |= DECODE_BASE64[pos[2] & 0x7F];
            value >>= 2;
            output[1] = value;
            value >>= 8;
        } else {
            value >>= 4;
        }
        output[0] = value;
    }
    return input + input_length;
}


// implementations of base64.h

size_t _olm_encode_base64_length(
    size_t input_length
) {
    return olm::encode_base64_length(input_length);
}

size_t _olm_encode_base64(
    uint8_t const * input, size_t input_length,
    uint8_t * output
) {
    uint8_t * r = olm::encode_base64(input, input_length, output);
    return r - output;
}

size_t _olm_decode_base64_length(
    size_t input_length
) {
    return olm::decode_base64_length(input_length);
}

size_t _olm_decode_base64(
    uint8_t const * input, size_t input_length,
    uint8_t * output
) {
    olm::decode_base64(input, input_length, output);
    return olm::decode_base64_length(input_length);
}
