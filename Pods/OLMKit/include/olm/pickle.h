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
#ifndef OLM_PICKLE_H_
#define OLM_PICKLE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct _olm_ed25519_public_key;
struct _olm_ed25519_key_pair;


#define _olm_pickle_uint32_length(value) 4
uint8_t * _olm_pickle_uint32(uint8_t * pos, uint32_t value);
uint8_t const * _olm_unpickle_uint32(
    uint8_t const * pos, uint8_t const * end,
    uint32_t *value
);


#define _olm_pickle_bool_length(value) 1
uint8_t * _olm_pickle_bool(uint8_t * pos, int value);
uint8_t const * _olm_unpickle_bool(
    uint8_t const * pos, uint8_t const * end,
    int *value
);

#define _olm_pickle_bytes_length(bytes, bytes_length) (bytes_length)
uint8_t * _olm_pickle_bytes(uint8_t * pos, uint8_t const * bytes,
                           size_t bytes_length);
uint8_t const * _olm_unpickle_bytes(uint8_t const * pos, uint8_t const * end,
                                   uint8_t * bytes, size_t bytes_length);


/** Get the number of bytes needed to pickle an ed25519 public key */
size_t _olm_pickle_ed25519_public_key_length(
    const struct _olm_ed25519_public_key * value
);

/** Pickle the ed25519 public key. Returns a pointer to the next free space in
 * the buffer. */
uint8_t * _olm_pickle_ed25519_public_key(
    uint8_t *pos, const struct _olm_ed25519_public_key * value
);

/** Unpickle the ed25519 public key. Returns a pointer to the next item in the
 * buffer. */
const uint8_t * _olm_unpickle_ed25519_public_key(
    const uint8_t *pos, const uint8_t *end,
    struct _olm_ed25519_public_key * value
);

/** Get the number of bytes needed to pickle an ed25519 key pair */
size_t _olm_pickle_ed25519_key_pair_length(
    const struct _olm_ed25519_key_pair * value
);

/** Pickle the ed25519 key pair. Returns a pointer to the next free space in
 * the buffer. */
uint8_t * _olm_pickle_ed25519_key_pair(
    uint8_t *pos, const struct _olm_ed25519_key_pair * value
);

/** Unpickle the ed25519 key pair. Returns a pointer to the next item in the
 * buffer. */
const uint8_t * _olm_unpickle_ed25519_key_pair(
    const uint8_t *pos, const uint8_t *end,
    struct _olm_ed25519_key_pair * value
);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* OLM_PICKLE_H */
