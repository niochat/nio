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

/* C bindings for memory functions */


#ifndef OLM_MEMORY_H_
#define OLM_MEMORY_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Clear the memory held in the buffer. This is more resilient to being
 * optimised away than memset or bzero.
 */
void _olm_unset(
    void volatile * buffer, size_t buffer_length
);

#ifdef __cplusplus
} // extern "C"
#endif


#endif /* OLM_MEMORY_H_ */
