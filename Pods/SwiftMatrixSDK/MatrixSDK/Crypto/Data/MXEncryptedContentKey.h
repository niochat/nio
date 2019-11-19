/*
 Copyright 2018 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MXJSONModel.h"

/**
 `MXEncryptedContentKey` stores the key information for an encrypted content.
 It is used in `MXEncryptedContentFile`.
 
    "key": {
        "alg": "A256CTR",
        "ext": true,
        "k": "aWF6-32KGYaC3A_FEUCk1Bt0JA37zP0wrStgmdCaW-0",
        "key_ops": ["encrypt","decrypt"],
        "kty": "oct"
    }
*/

@interface MXEncryptedContentKey : MXJSONModel

/**
 The algorithm.
 */
@property (nonatomic) NSString *alg;

/**
 Tell whether it is extractable.
 */
@property (nonatomic) BOOL ext;

/**
 The key, encoded as urlsafe unpadded base64.
 */
@property (nonatomic) NSString *k;

/**
 The key operations. Must at least contain encrypt and decrypt.
 */
@property (nonatomic) NSArray<NSString *> *keyOps;

/**
 The key type.
 */
@property (nonatomic) NSString *kty;

@end
