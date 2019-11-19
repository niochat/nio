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

/* functions for encrypting and decrypting pickled representations of objects */

#ifndef OLM_PICKLE_ENCODING_H_
#define OLM_PICKLE_ENCODING_H_

#include <stddef.h>
#include <stdint.h>

#include "olm/error.h"

#ifdef __cplusplus
extern "C" {
#endif


/**
 * Get the number of bytes needed to encode a pickle of the length given
 */
size_t _olm_enc_output_length(size_t raw_length);

/**
 * Get the point in the output buffer that the raw pickle should be written to.
 *
 * In order that we can use the same buffer for the raw pickle, and the encoded
 * pickle, the raw pickle needs to be written at the end of the buffer. (The
 * base-64 encoding would otherwise overwrite the end of the input before it
 * was encoded.)
 */
 uint8_t *_olm_enc_output_pos(uint8_t * output, size_t raw_length);

/**
 * Encrypt and encode the given pickle in-situ.
 *
 * The raw pickle should have been written to enc_output_pos(pickle,
 * raw_length).
 *
 * Returns the number of bytes in the encoded pickle.
 */
size_t _olm_enc_output(
    uint8_t const * key, size_t key_length,
    uint8_t *pickle, size_t raw_length
);

/**
 * Decode and decrypt the given pickle in-situ.
 *
 * Returns the number of bytes in the decoded pickle, or olm_error() on error,
 * in which case *last_error will be updated, if last_error is non-NULL.
 */
size_t _olm_enc_input(
    uint8_t const * key, size_t key_length,
    uint8_t * input, size_t b64_length,
    enum OlmErrorCode * last_error
);


#ifdef __cplusplus
} // extern "C"
#endif

#endif /* OLM_PICKLE_ENCODING_H_ */
