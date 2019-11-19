/*
 Copyright 2016 OpenMarket Ltd

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

#import "MXCryptoAlgorithms.h"

@interface MXCryptoAlgorithms ()
{
    NSMutableDictionary<NSString*, Class<MXEncrypting>> *encryptors;
    NSMutableDictionary<NSString*, Class<MXDecrypting>> *decryptors;
}

@end

static MXCryptoAlgorithms *sharedOnceInstance = nil;

@implementation MXCryptoAlgorithms

+ (instancetype)sharedAlgorithms
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedOnceInstance = [[self alloc] init];
    });
    return sharedOnceInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        encryptors = [NSMutableDictionary dictionary];
        decryptors = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)registerEncryptorClass:(Class<MXEncrypting>)encryptorClass forAlgorithm:(NSString *)algorithm
{
    encryptors[algorithm] = encryptorClass;
}

- (void)registerDecryptorClass:(Class<MXDecrypting>)decryptorClass forAlgorithm:(NSString *)algorithm
{
    decryptors[algorithm] = decryptorClass;
}

- (Class<MXEncrypting>)encryptorClassForAlgorithm:(NSString *)algorithm
{
    return encryptors[algorithm];
}

- (Class<MXDecrypting>)decryptorClassForAlgorithm:(NSString *)algorithm
{
    return decryptors[algorithm];
}

- (NSArray<NSString *> *)supportedAlgorithms
{
    return encryptors.allKeys;
}

@end

