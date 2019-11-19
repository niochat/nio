/*
 Copyright 2016 Chris Ballinger
 Copyright 2016 OpenMarket Ltd
 Copyright 2016 Vector Creations Ltd

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

// In this header, you should import all the public headers of your framework using statements like #import <OLMKit/PublicHeader.h>

#import <OLMKit/OLMAccount.h>
#import <OLMKit/OLMSession.h>
#import <OLMKit/OLMMessage.h>
#import <OLMKit/OLMUtility.h>
#import <OLMKit/OLMInboundGroupSession.h>
#import <OLMKit/OLMOutboundGroupSession.h>
#import <OLMKit/OLMPkEncryption.h>
#import <OLMKit/OLMPkDecryption.h>
#import <OLMKit/OLMPkSigning.h>
#import <OLMKit/OLMSAS.h>

@interface OLMKit : NSObject

//! Project version string for OLMKit, the same as libolm.
+ (NSString*)versionString;

@end
