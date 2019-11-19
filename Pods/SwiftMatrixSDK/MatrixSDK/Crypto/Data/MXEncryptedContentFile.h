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
 `MXEncryptedContentFile` contains the encryption data required to decrypt an encrypted content.
 These data are available in an encrypted event content under the `file` or `thumbnail_file` keys.
 When the client creates an encrypted attachment, these data are returned on success (see MXEncryptedAttachment class).
 
 See below an example of these data:
    {
        "url": "mxc://…",
        "mimetype": "video/mp4",
        "key": {
            "alg": "A256CTR",
            "ext": true,
            "k": "aWF6-32KGYaC3A_FEUCk1Bt0JA37zP0wrStgmdCaW-0",
            "key_ops": ["encrypt","decrypt"],
            "kty": "oct"
        },
        "iv": "+pNiVx4SS9wXOV69UZqutg",
        "hashes": {
            "sha256": "fdSLu/YkRx3Wyh3KQabP3rd6+SFiKg5lsJZQHtkSAYA",
        }
    }
*/

@class MXEncryptedContentKey;

@interface MXEncryptedContentFile : MXJSONModel

/**
 Version of the encrypted attachments protocol.
 */
@property (nonatomic) NSString *v;

/**
 The URL to the encrypted file.
 */
@property (nonatomic) NSString *url;

/**
 The mimetype of the content.
 */
@property (nonatomic) NSString *mimetype;

/**
 The Key object.
 */
@property (nonatomic) MXEncryptedContentKey *key;

/**
 The Initialisation Vector used by AES-CTR, encoded as unpadded base64.
 */
@property (nonatomic) NSString *iv;

/**
 A map from an algorithm name to a hash of the ciphertext, encoded as unpadded base64. Clients should support the SHA-256 hash, which uses the key sha256.
 */
@property (nonatomic) NSDictionary<NSString*, NSString*> *hashes;

@end
