/*
 Copyright 2017 Vector Creations Ltd

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

#import <Foundation/Foundation.h>

/**
 The `MXAllowedCertificates` singleton stores certificates allowed by the user.
 We need this static object because of the staticness of `MXMediaManager`.
 */
@interface MXAllowedCertificates : NSObject

/**
 The `MXAllowedCertificates` singleton.
 */
+ (instancetype)sharedInstance;

/**
 Add a certificate in the allowed list.
 
 @param certificate the certificate to add.
 */
- (void)addCertificate:(NSData*)certificate;

/**
 Check if a certificate is allowed.
 
 @param certificate the certificate to check.
 @return YES if allowed.
 */
- (BOOL)isCertificateAllowed:(NSData*)certificate;

/**
 Forget all allowed certificates.
 */
- (void)reset;

/**
 The current list of allowed certificates.
 */
@property (readonly) NSSet<NSData*> *certificates;

@end
