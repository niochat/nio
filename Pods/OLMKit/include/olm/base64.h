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

/* C bindings for base64 functions */


#ifndef OLM_BASE64_H_
#define OLM_BASE64_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif


/**
 * The number of bytes of unpadded base64 needed to encode a length of input.
 */
size_t _olm_encode_base64_length(
    size_t input_length
);

/**
 * Encode the raw input as unpadded base64.
 * Writes encode_base64_length(input_length) bytes to the output buffer.
 * The input can overlap with the last three quarters of the output buffer.
 * That is, the input pointer may be output + output_length - input_length.
 *
 * Returns number of bytes encoded
 */
size_t _olm_encode_base64(
    uint8_t const * input, size_t input_length,
    uint8_t * output
);

/**
 * The number of bytes of raw data a length of unpadded base64 will encode to.
 * Returns size_t(-1) if the length is not a valid length for base64.
 */
size_t _olm_decode_base64_length(
    size_t input_length
);

/**
 * Decodes the unpadded base64 input to raw bytes.
 * Writes decode_base64_length(input_length) bytes to the output buffer.
 * The output can overlap with the first three quarters of the input buffer.
 * That is, the input pointers and output pointer may be the same.
 *
 * Returns number of bytes decoded
 */
size_t _olm_decode_base64(
    uint8_t const * input, size_t input_length,
    uint8_t * output
);


#ifdef __cplusplus
} // extern "C"
#endif


#endif /* OLM_BASE64_H_ */
