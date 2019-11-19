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

#ifndef OLM_MEGOLM_H_
#define OLM_MEGOLM_H_

/**
 * implementation of the Megolm multi-part ratchet used in group chats.
 */

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * number of bytes in each part of the ratchet; this should be the same as
 * the length of the hash function used in the HMAC (32 bytes for us, as we
 * use HMAC-SHA-256)
 */
#define MEGOLM_RATCHET_PART_LENGTH 32 /* SHA256_OUTPUT_LENGTH */

/**
 * number of parts in the ratchet; the advance() implementations rely on
 * this being 4.
 */
#define MEGOLM_RATCHET_PARTS 4

#define MEGOLM_RATCHET_LENGTH (MEGOLM_RATCHET_PARTS * MEGOLM_RATCHET_PART_LENGTH)

typedef struct Megolm {
    uint8_t data[MEGOLM_RATCHET_PARTS][MEGOLM_RATCHET_PART_LENGTH];
    uint32_t counter;
} Megolm;


/**
 * The cipher used in megolm-backed conversations
 *
 * (AES256 + SHA256, with keys based on an HKDF with info of MEGOLM_KEYS)
 */
extern const struct _olm_cipher *megolm_cipher;

/**
 * initialize the megolm ratchet. random_data should be at least
 * MEGOLM_RATCHET_LENGTH bytes of randomness.
 */
void megolm_init(Megolm *megolm, uint8_t const *random_data, uint32_t counter);

/** Returns the number of bytes needed to store a megolm */
size_t megolm_pickle_length(const Megolm *megolm);

/**
 * Pickle the megolm. Returns a pointer to the next free space in the buffer.
 */
uint8_t * megolm_pickle(const Megolm *megolm, uint8_t *pos);

/**
 * Unpickle the megolm. Returns a pointer to the next item in the buffer.
 */
const uint8_t * megolm_unpickle(Megolm *megolm, const uint8_t *pos,
                                const uint8_t *end);


/** advance the ratchet by one step */
void megolm_advance(Megolm *megolm);

/**
 * get the key data in the ratchet. The returned data is
 * MEGOLM_RATCHET_LENGTH bytes long.
 */
#define megolm_get_data(megolm) ((const uint8_t *)((megolm)->data))

/** advance the ratchet to a given count */
void megolm_advance_to(Megolm *megolm, uint32_t advance_to);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* OLM_MEGOLM_H_ */
