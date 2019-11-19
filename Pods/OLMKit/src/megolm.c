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


#include "olm/megolm.h"

#include <string.h>

#include "olm/cipher.h"
#include "olm/crypto.h"
#include "olm/pickle.h"

static const struct _olm_cipher_aes_sha_256 MEGOLM_CIPHER =
    OLM_CIPHER_INIT_AES_SHA_256("MEGOLM_KEYS");
const struct _olm_cipher *megolm_cipher = OLM_CIPHER_BASE(&MEGOLM_CIPHER);

/* the seeds used in the HMAC-SHA-256 functions for each part of the ratchet.
 */
#define HASH_KEY_SEED_LENGTH 1
static uint8_t HASH_KEY_SEEDS[MEGOLM_RATCHET_PARTS][HASH_KEY_SEED_LENGTH] = {
    {0x00},
    {0x01},
    {0x02},
    {0x03}
};

static void rehash_part(
    uint8_t data[MEGOLM_RATCHET_PARTS][MEGOLM_RATCHET_PART_LENGTH],
    int rehash_from_part, int rehash_to_part
) {
    _olm_crypto_hmac_sha256(
        data[rehash_from_part],
        MEGOLM_RATCHET_PART_LENGTH,
        HASH_KEY_SEEDS[rehash_to_part], HASH_KEY_SEED_LENGTH,
        data[rehash_to_part]
    );
}



void megolm_init(Megolm *megolm, uint8_t const *random_data, uint32_t counter) {
    megolm->counter = counter;
    memcpy(megolm->data, random_data, MEGOLM_RATCHET_LENGTH);
}

size_t megolm_pickle_length(const Megolm *megolm) {
    size_t length = 0;
    length += _olm_pickle_bytes_length(megolm_get_data(megolm), MEGOLM_RATCHET_LENGTH);
    length += _olm_pickle_uint32_length(megolm->counter);
    return length;

}

uint8_t * megolm_pickle(const Megolm *megolm,  uint8_t *pos) {
    pos = _olm_pickle_bytes(pos, megolm_get_data(megolm), MEGOLM_RATCHET_LENGTH);
    pos = _olm_pickle_uint32(pos, megolm->counter);
    return pos;
}

const uint8_t * megolm_unpickle(Megolm *megolm, const uint8_t *pos,
                                const uint8_t *end) {
    pos = _olm_unpickle_bytes(pos, end, (uint8_t *)(megolm->data),
                             MEGOLM_RATCHET_LENGTH);
    pos = _olm_unpickle_uint32(pos, end, &megolm->counter);
    return pos;
}

/* simplistic implementation for a single step */
void megolm_advance(Megolm *megolm) {
    uint32_t mask = 0x00FFFFFF;
    int h = 0;
    int i;

    megolm->counter++;

    /* figure out how much we need to rekey */
    while (h < (int)MEGOLM_RATCHET_PARTS) {
        if (!(megolm->counter & mask))
            break;
        h++;
        mask >>= 8;
    }

    /* now update R(h)...R(3) based on R(h) */
    for (i = MEGOLM_RATCHET_PARTS-1; i >= h; i--) {
        rehash_part(megolm->data, h, i);
    }
}

void megolm_advance_to(Megolm *megolm, uint32_t advance_to) {
    int j;

    /* starting with R0, see if we need to update each part of the hash */
    for (j = 0; j < (int)MEGOLM_RATCHET_PARTS; j++) {
        int shift = (MEGOLM_RATCHET_PARTS-j-1) * 8;
        uint32_t mask = (~(uint32_t)0) << shift;
        int k;

        /* how many times do we need to rehash this part?
         *
         * '& 0xff' ensures we handle integer wraparound correctly
         */
        unsigned int steps =
            ((advance_to >> shift) - (megolm->counter >> shift)) & 0xff;

        if (steps == 0) {
            /* deal with the edge case where megolm->counter is slightly larger
             * than advance_to. This should only happen for R(0), and implies
             * that advance_to has wrapped around and we need to advance R(0)
             * 256 times.
             */
            if (advance_to < megolm->counter) {
                steps = 0x100;
            } else {
                continue;
            }
        }

        /* for all but the last step, we can just bump R(j) without regard
         * to R(j+1)...R(3).
         */
        while (steps > 1) {
            rehash_part(megolm->data, j, j);
            steps --;
        }

        /* on the last step we also need to bump R(j+1)...R(3).
         *
         * (Theoretically, we could skip bumping R(j+2) if we're going to bump
         * R(j+1) again, but the code to figure that out is a bit baroque and
         * doesn't save us much).
         */
        for (k = 3; k >= j; k--) {
            rehash_part(megolm->data, j, k);
        }
        megolm->counter = advance_to & mask;
    }
}
