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
#ifndef OLM_ERROR_H_
#define OLM_ERROR_H_

#ifdef __cplusplus
extern "C" {
#endif

enum OlmErrorCode {
    OLM_SUCCESS = 0, /*!< There wasn't an error */
    OLM_NOT_ENOUGH_RANDOM = 1,  /*!< Not enough entropy was supplied */
    OLM_OUTPUT_BUFFER_TOO_SMALL = 2, /*!< Supplied output buffer is too small */
    OLM_BAD_MESSAGE_VERSION = 3,  /*!< The message version is unsupported */
    OLM_BAD_MESSAGE_FORMAT = 4, /*!< The message couldn't be decoded */
    OLM_BAD_MESSAGE_MAC = 5, /*!< The message couldn't be decrypted */
    OLM_BAD_MESSAGE_KEY_ID = 6, /*!< The message references an unknown key id */
    OLM_INVALID_BASE64 = 7, /*!< The input base64 was invalid */
    OLM_BAD_ACCOUNT_KEY = 8, /*!< The supplied account key is invalid */
    OLM_UNKNOWN_PICKLE_VERSION = 9, /*!< The pickled object is too new */
    OLM_CORRUPTED_PICKLE = 10, /*!< The pickled object couldn't be decoded */

    OLM_BAD_SESSION_KEY = 11,  /*!< Attempt to initialise an inbound group
                                 session from an invalid session key */
    OLM_UNKNOWN_MESSAGE_INDEX = 12,  /*!< Attempt to decode a message whose
                                      * index is earlier than our earliest
                                      * known session key.
                                      */

    /**
     * Attempt to unpickle an account which uses pickle version 1 (which did
     * not save enough space for the Ed25519 key; the key should be considered
     * compromised. We don't let the user reload the account.
     */
    OLM_BAD_LEGACY_ACCOUNT_PICKLE = 13,

    /**
     * Received message had a bad signature
     */
    OLM_BAD_SIGNATURE = 14,

    OLM_INPUT_BUFFER_TOO_SMALL = 15,

    // Not an error code, just here to pad out the enum past 16 because
    // otherwise the compiler warns about a redunant check. If you're
    // adding an error code, replace this one!
    OLM_ERROR_NOT_INVENTED_YET = 16,

    /* remember to update the list of string constants in error.c when updating
     * this list. */
};

/** get a string representation of the given error code. */
const char * _olm_error_to_string(enum OlmErrorCode error);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* OLM_ERROR_H_ */
