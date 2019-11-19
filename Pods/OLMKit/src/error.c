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

#include "olm/error.h"

static const char * ERRORS[] = {
    "SUCCESS",
    "NOT_ENOUGH_RANDOM",
    "OUTPUT_BUFFER_TOO_SMALL",
    "BAD_MESSAGE_VERSION",
    "BAD_MESSAGE_FORMAT",
    "BAD_MESSAGE_MAC",
    "BAD_MESSAGE_KEY_ID",
    "INVALID_BASE64",
    "BAD_ACCOUNT_KEY",
    "UNKNOWN_PICKLE_VERSION",
    "CORRUPTED_PICKLE",
    "BAD_SESSION_KEY",
    "UNKNOWN_MESSAGE_INDEX",
    "BAD_LEGACY_ACCOUNT_PICKLE",
    "BAD_SIGNATURE",
    "OLM_INPUT_BUFFER_TOO_SMALL",
};

const char * _olm_error_to_string(enum OlmErrorCode error)
{
    if (error < (sizeof(ERRORS)/sizeof(ERRORS[0]))) {
        return ERRORS[error];
    } else {
        return "UNKNOWN_ERROR";
    }
}
