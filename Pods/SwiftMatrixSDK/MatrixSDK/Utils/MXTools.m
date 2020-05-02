/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

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
#import "MXTools.h"

#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

#pragma mark - Constant definition
NSString *const kMXToolsRegexStringForEmailAddress              = @"[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}";

// The HS domain part in Matrix identifiers
#define MATRIX_HOMESERVER_DOMAIN_REGEX                        @"[A-Z0-9.-]+(\\.[A-Z]{2,})?+(\\:[0-9]{2,})?"

NSString *const kMXToolsRegexStringForMatrixUserIdentifier      = @"@[\\x21-\\x39\\x3B-\\x7F]+:" MATRIX_HOMESERVER_DOMAIN_REGEX;
NSString *const kMXToolsRegexStringForMatrixRoomAlias           = @"#[A-Z0-9._%#@+-]+:" MATRIX_HOMESERVER_DOMAIN_REGEX;
NSString *const kMXToolsRegexStringForMatrixRoomIdentifier      = @"![A-Z0-9]+:" MATRIX_HOMESERVER_DOMAIN_REGEX;
NSString *const kMXToolsRegexStringForMatrixEventIdentifier     = @"\\$[A-Z0-9]+:" MATRIX_HOMESERVER_DOMAIN_REGEX;
NSString *const kMXToolsRegexStringForMatrixEventIdentifierV3   = @"\\$[A-Z0-9\\/+]+";
NSString *const kMXToolsRegexStringForMatrixGroupIdentifier     = @"\\+[A-Z0-9=_\\-./]+:" MATRIX_HOMESERVER_DOMAIN_REGEX;


#pragma mark - MXTools static private members
// Mapping from MXEventTypeString to MXEventType and vice versa
static NSDictionary<MXEventTypeString, NSNumber*> *eventTypeMapStringToEnum;
static NSArray<MXEventTypeString> *eventTypeMapEnumToString;

static NSRegularExpression *isEmailAddressRegex;
static NSRegularExpression *isMatrixUserIdentifierRegex;
static NSRegularExpression *isMatrixRoomAliasRegex;
static NSRegularExpression *isMatrixRoomIdentifierRegex;
static NSRegularExpression *isMatrixEventIdentifierRegex;
static NSRegularExpression *isMatrixEventIdentifierV3Regex;
static NSRegularExpression *isMatrixGroupIdentifierRegex;

// A regex to find new lines
static NSRegularExpression *newlineCharactersRegex;

static NSUInteger transactionIdCount;

// Character set to use to encode/decide URI component
NSString *const uriComponentCharsetExtra = @"-_.!~*'()";
NSCharacterSet *uriComponentCharset;


@implementation MXTools

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        eventTypeMapEnumToString = @[
                                kMXEventTypeStringRoomName,
                                kMXEventTypeStringRoomTopic,
                                kMXEventTypeStringRoomAvatar,
                                kMXEventTypeStringRoomBotOptions,
                                kMXEventTypeStringRoomMember,
                                kMXEventTypeStringRoomCreate,
                                kMXEventTypeStringRoomJoinRules,
                                kMXEventTypeStringRoomPowerLevels,
                                kMXEventTypeStringRoomAliases,
                                kMXEventTypeStringRoomCanonicalAlias,
                                kMXEventTypeStringRoomEncrypted,
                                kMXEventTypeStringRoomEncryption,
                                kMXEventTypeStringRoomGuestAccess,
                                kMXEventTypeStringRoomHistoryVisibility,
                                kMXEventTypeStringRoomKey,
                                kMXEventTypeStringRoomForwardedKey,
                                kMXEventTypeStringRoomKeyRequest,
                                kMXEventTypeStringRoomMessage,
                                kMXEventTypeStringRoomMessageFeedback,
                                kMXEventTypeStringRoomPlumbing,
                                kMXEventTypeStringRoomRedaction,
                                kMXEventTypeStringRoomThirdPartyInvite,
                                kMXEventTypeStringRoomRelatedGroups,
                                kMXEventTypeStringRoomPinnedEvents,
                                kMXEventTypeStringRoomTag,
                                kMXEventTypeStringPresence,
                                kMXEventTypeStringTypingNotification,
                                kMXEventTypeStringReaction,
                                kMXEventTypeStringReceipt,
                                kMXEventTypeStringRead,
                                kMXEventTypeStringReadMarker,
                                kMXEventTypeStringCallInvite,
                                kMXEventTypeStringCallCandidates,
                                kMXEventTypeStringCallAnswer,
                                kMXEventTypeStringCallHangup,
                                kMXEventTypeStringSticker,
                                kMXEventTypeStringRoomTombStone,
                                kMXEventTypeStringKeyVerificationRequest,
                                kMXEventTypeStringKeyVerificationReady,
                                kMXEventTypeStringKeyVerificationStart,
                                kMXEventTypeStringKeyVerificationAccept,
                                kMXEventTypeStringKeyVerificationKey,
                                kMXEventTypeStringKeyVerificationMac,
                                kMXEventTypeStringKeyVerificationCancel,
                                kMXEventTypeStringKeyVerificationDone,
                                kMXEventTypeStringSecretRequest,
                                kMXEventTypeStringSecretSend,
                                ];

        NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:eventTypeMapEnumToString.count];
        for (NSUInteger i = 0; i <eventTypeMapEnumToString.count; i++)
        {
            MXEventTypeString type = eventTypeMapEnumToString[i];
            map[type] = @(i);
        }
        eventTypeMapStringToEnum = map;

        isEmailAddressRegex =  [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForEmailAddress]
                                                                         options:NSRegularExpressionCaseInsensitive error:nil];
        isMatrixUserIdentifierRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForMatrixUserIdentifier]
                                                                                options:NSRegularExpressionCaseInsensitive error:nil];
        isMatrixRoomAliasRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForMatrixRoomAlias]
                                                                           options:NSRegularExpressionCaseInsensitive error:nil];
        isMatrixRoomIdentifierRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForMatrixRoomIdentifier]
                                                                                options:NSRegularExpressionCaseInsensitive error:nil];
        isMatrixEventIdentifierRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForMatrixEventIdentifier]
                                                                                 options:NSRegularExpressionCaseInsensitive error:nil];
        isMatrixEventIdentifierV3Regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForMatrixEventIdentifierV3]
                                                                                 options:NSRegularExpressionCaseInsensitive error:nil];

        isMatrixGroupIdentifierRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@$", kMXToolsRegexStringForMatrixGroupIdentifier]
                                                                                options:NSRegularExpressionCaseInsensitive error:nil];

        newlineCharactersRegex = [NSRegularExpression regularExpressionWithPattern:@" *[\n\r]+[\n\r ]*"
                                                                           options:0 error:nil];

        transactionIdCount = 0;

        // Set up charset for URI component coding
        NSMutableCharacterSet *allowedCharacterSet = [NSMutableCharacterSet alphanumericCharacterSet];
        [allowedCharacterSet addCharactersInString:uriComponentCharsetExtra];
        uriComponentCharset = allowedCharacterSet;
    });
}

+ (MXEventTypeString)eventTypeString:(MXEventType)eventType
{
    if (eventType < eventTypeMapEnumToString.count)
    {
        return eventTypeMapEnumToString[eventType];
    }
    return nil;
}

+ (MXEventType)eventType:(MXEventTypeString)eventTypeString
{
    MXEventType eventType = MXEventTypeCustom;

    NSNumber *number = [eventTypeMapStringToEnum objectForKey:eventTypeString];
    if (number)
    {
        eventType = [number unsignedIntegerValue];
    }
    return eventType;
}


+ (MXMembership)membership:(MXMembershipString)membershipString
{
    MXMembership membership = MXMembershipUnknown;
    
    if ([membershipString isEqualToString:kMXMembershipStringInvite])
    {
        membership = MXMembershipInvite;
    }
    else if ([membershipString isEqualToString:kMXMembershipStringJoin])
    {
        membership = MXMembershipJoin;
    }
    else if ([membershipString isEqualToString:kMXMembershipStringLeave])
    {
        membership = MXMembershipLeave;
    }
    else if ([membershipString isEqualToString:kMXMembershipStringBan])
    {
        membership = MXMembershipBan;
    }
    return membership;
}


+ (MXMembershipString)membershipString:(MXMembership)membership
{
    MXMembershipString membershipString;
    
    switch (membership)
    {
        case MXMembershipInvite:
            membershipString = kMXMembershipStringInvite;
            break;
            
        case MXMembershipJoin:
            membershipString = kMXMembershipStringJoin;
            break;
            
        case MXMembershipLeave:
            membershipString = kMXMembershipStringLeave;
            break;
            
        case MXMembershipBan:
            membershipString = kMXMembershipStringBan;
            break;
            
        default:
            break;
    }
    
    return membershipString;
}

+ (MXPresence)presence:(MXPresenceString)presenceString
{
    MXPresence presence = MXPresenceUnknown;
    
    // Convert presence string into enum value
    if ([presenceString isEqualToString:kMXPresenceOnline])
    {
        presence = MXPresenceOnline;
    }
    else if ([presenceString isEqualToString:kMXPresenceUnavailable])
    {
        presence = MXPresenceUnavailable;
    }
    else if ([presenceString isEqualToString:kMXPresenceOffline])
    {
        presence = MXPresenceOffline;
    }
    
    return presence;
}

+ (MXPresenceString)presenceString:(MXPresence)presence
{
    MXPresenceString presenceString;
    
    switch (presence)
    {
        case MXPresenceOnline:
            presenceString = kMXPresenceOnline;
            break;
            
        case MXPresenceUnavailable:
            presenceString = kMXPresenceUnavailable;
            break;
            
        case MXPresenceOffline:
            presenceString = kMXPresenceOffline;
            break;
            
        default:
            break;
    }
    
    return presenceString;
}

+ (NSString *)generateSecret
{
    return [[NSProcessInfo processInfo] globallyUniqueString];
}

+ (NSString *)generateTransactionId
{
    return [NSString stringWithFormat:@"m%u.%tu", arc4random_uniform(INT32_MAX), transactionIdCount++];
}

+ (NSString*)stripNewlineCharacters:(NSString *)inputString
{
    NSString *string;
    if (inputString)
    {
        string = [newlineCharactersRegex stringByReplacingMatchesInString:inputString
                                                                  options:0
                                                                    range:NSMakeRange(0, inputString.length)
                                                             withTemplate:@" "];
    }
    return string;
}

+ (NSString*)addWhiteSpacesToString:(NSString *)inputString every:(NSUInteger)characters
{
    NSMutableString *whiteSpacedString = [NSMutableString new];
    for (int i = 0; i < inputString.length / characters + 1; i++)
    {
        NSUInteger fromIndex = i * characters;
        NSUInteger len = inputString.length - fromIndex;
        if (len > characters)
        {
            len = characters;
        }

        NSString *whiteFormat = @"%@ ";
        if (fromIndex + characters >= inputString.length)
        {
            whiteFormat = @"%@";
        }
        [whiteSpacedString appendFormat:whiteFormat, [inputString substringWithRange:NSMakeRange(fromIndex, len)]];
    }

    return whiteSpacedString;
}


#pragma mark - String kinds check

+ (BOOL)isEmailAddress:(NSString *)inputString
{
    if (inputString)
    {
        return (nil != [isEmailAddressRegex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)]);
    }
    return NO;
}

+ (BOOL)isMatrixUserIdentifier:(NSString *)inputString
{
    if (inputString)
    {
        return (nil != [isMatrixUserIdentifierRegex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)]);
    }
    return NO;
}

+ (BOOL)isMatrixRoomAlias:(NSString *)inputString
{
    if (inputString)
    {
        return (nil != [isMatrixRoomAliasRegex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)]);
    }
    return NO;
}

+ (BOOL)isMatrixRoomIdentifier:(NSString *)inputString
{
    if (inputString)
    {
        return (nil != [isMatrixRoomIdentifierRegex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)]);
    }
    return NO;
}

+ (BOOL)isMatrixEventIdentifier:(NSString *)inputString
{
    if (inputString)
    {
        return (nil != [isMatrixEventIdentifierRegex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)])
        || (nil != [isMatrixEventIdentifierV3Regex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)]);
    }
    return NO;
}

+ (BOOL)isMatrixGroupIdentifier:(NSString *)inputString
{
    if (inputString)
    {
        return (nil != [isMatrixGroupIdentifierRegex firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)]);
    }
    return NO;
}

+ (NSString*)serverNameInMatrixIdentifier:(NSString *)identifier
{
    // This converts something:example.org into a server domain
    //  by splitting on colons and ignoring the first entry ("something").
    return [identifier componentsSeparatedByString:@":"].lastObject;
}


#pragma mark - Strings encoding
+ (NSString *)encodeURIComponent:(NSString *)string
{
    return [string stringByAddingPercentEncodingWithAllowedCharacters:uriComponentCharset];
}


#pragma mark - Permalink
+ (NSString *)permalinkToRoom:(NSString *)roomIdOrAlias
{
    return [NSString stringWithFormat:@"%@/#/%@", kMXMatrixDotToUrl, [MXTools encodeURIComponent:roomIdOrAlias]];
}

+ (NSString *)permalinkToEvent:(NSString *)eventId inRoom:(NSString *)roomIdOrAlias
{
    return [NSString stringWithFormat:@"%@/#/%@/%@", kMXMatrixDotToUrl, [MXTools encodeURIComponent:roomIdOrAlias], [MXTools encodeURIComponent:eventId]];

}

+ (NSString*)permalinkToUserWithUserId:(NSString*)userId
{
    return [NSString stringWithFormat:@"%@/#/%@", kMXMatrixDotToUrl, userId];
}

#pragma mark - File

// return an array of files attributes
+ (NSArray*)listAttributesFiles:(NSString *)folderPath
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:nil];
    NSEnumerator *contentsEnumurator = [contents objectEnumerator];
    
    NSString *file;
    NSMutableArray* res = [[NSMutableArray alloc] init];
    
    while (file = [contentsEnumurator nextObject])
        
    {
        NSString* itemPath = [folderPath stringByAppendingPathComponent:file];
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
        
        // is directory
        if ([[fileAttributes objectForKey:NSFileType] isEqual:NSFileTypeDirectory])
            
        {
            [res addObjectsFromArray:[MXTools listAttributesFiles:itemPath]];
        }
        else
            
        {
            NSMutableDictionary* att = [fileAttributes mutableCopy];
            // add the file path
            [att setObject:itemPath forKey:@"NSFilePath"];
            [res addObject:att];
        }
    }
    
    return res;
}

+ (long long)roundFileSize:(long long)filesize
{
    static long long roundedFactor = (100 * 1024);
    static long long smallRoundedFactor = (10 * 1024);
    long long roundedFileSize = filesize;
    
    if (filesize > roundedFactor)
    {
        roundedFileSize = ((filesize + (roundedFactor /2)) / roundedFactor) * roundedFactor;
    }
    else if (filesize > smallRoundedFactor)
    {
        roundedFileSize = ((filesize + (smallRoundedFactor /2)) / smallRoundedFactor) * smallRoundedFactor;
    }
    
    return roundedFileSize;
}

+ (NSString*)fileSizeToString:(long)fileSize round:(BOOL)round
{
    if (fileSize < 0)
    {
        return @"";
    }
    else if (fileSize < 1024)
    {
        return [NSString stringWithFormat:@"%ld bytes", fileSize];
    }
    else if (fileSize < (1024 * 1024))
    {
        if (round)
        {
            return [NSString stringWithFormat:@"%.0f KB", ceil(fileSize / 1024.0)];
        }
        else
        {
            return [NSString stringWithFormat:@"%.2f KB", (fileSize / 1024.0)];
        }
    }
    else
    {
        if (round)
        {
            return [NSString stringWithFormat:@"%.0f MB", ceil(fileSize / 1024.0 / 1024.0)];
        }
        else
        {
            return [NSString stringWithFormat:@"%.2f MB", (fileSize / 1024.0 / 1024.0)];
        }
    }
}

// recursive method to compute the folder content size
+ (long long)folderSize:(NSString *)folderPath
{
    long long folderSize = 0;
    NSArray *fileAtts = [MXTools listAttributesFiles:folderPath];
    
    for(NSDictionary *fileAtt in fileAtts)
    {
        folderSize += [[fileAtt objectForKey:NSFileSize] intValue];
    }
    
    return folderSize;
}

// return the list of files by name
// isTimeSorted : the files are sorted by creation date from the oldest to the most recent one
// largeFilesFirst: move the largest file to the list head (large > 100KB). It can be combined isTimeSorted
+ (NSArray*)listFiles:(NSString *)folderPath timeSorted:(BOOL)isTimeSorted largeFilesFirst:(BOOL)largeFilesFirst
{
    NSArray* attFilesList = [MXTools listAttributesFiles:folderPath];
    
    if (attFilesList.count > 0)
    {
        
        // sorted by timestamp (oldest first)
        if (isTimeSorted)
        {
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"NSFileCreationDate" ascending:YES selector:@selector(compare:)];
            attFilesList = [attFilesList sortedArrayUsingDescriptors:@[ sortDescriptor]];
        }
        
        // list the large files first
        if (largeFilesFirst)
        {
            NSMutableArray* largeFilesAttList = [[NSMutableArray alloc] init];
            NSMutableArray* smallFilesAttList = [[NSMutableArray alloc] init];
            
            for (NSDictionary* att in attFilesList)
            {
                if ([[att objectForKey:NSFileSize] intValue] > 100 * 1024)
                {
                    [largeFilesAttList addObject:att];
                }
                else
                {
                    [smallFilesAttList addObject:att];
                }
            }
            
            NSMutableArray* mergedList = [[NSMutableArray alloc] init];
            [mergedList addObjectsFromArray:largeFilesAttList];
            [mergedList addObjectsFromArray:smallFilesAttList];
            attFilesList = mergedList;
        }
        
        // list filenames
        NSMutableArray* res = [[NSMutableArray alloc] init];
        for (NSDictionary* att in attFilesList)
        {
            [res addObject:[att valueForKey:@"NSFilePath"]];
        }
        
        return res;
    }
    else
    {
        return nil;
    }
}


// cache the value to improve the UX.
static NSMutableDictionary *fileExtensionByContentType = nil;

// return the file extension from a contentType
+ (NSString*)fileExtensionFromContentType:(NSString*)contentType
{
    // sanity checks
    if (!contentType || (0 == contentType.length))
    {
        return @"";
    }
    
    NSString* fileExt = nil;
    
    if (!fileExtensionByContentType)
    {
        fileExtensionByContentType  = [[NSMutableDictionary alloc] init];
    }
    
    fileExt = fileExtensionByContentType[contentType];
    
    if (!fileExt)
    {
        fileExt = @"";
        
        // else undefined type
        if ([contentType isEqualToString:@"application/jpeg"])
        {
            fileExt = @".jpg";
        }
        else if ([contentType isEqualToString:@"audio/x-alaw-basic"])
        {
            fileExt = @".alaw";
        }
        else if ([contentType isEqualToString:@"audio/x-caf"])
        {
            fileExt = @".caf";
        }
        else if ([contentType isEqualToString:@"audio/aac"])
        {
            fileExt =  @".aac";
        }
        else
        {
            CFStringRef mimeType = (__bridge CFStringRef)contentType;
            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
            
            NSString* extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
            
            CFRelease(uti);
            
            if (extension)
            {
                fileExt = [NSString stringWithFormat:@".%@", extension];
            }
        }
        
        [fileExtensionByContentType setObject:fileExt forKey:contentType];
    }
    
    return fileExt;
}

#pragma mark - Video processing

+ (void)convertVideoToMP4:(NSURL*)videoLocalURL
                  success:(void(^)(NSURL *videoLocalURL, NSString *mimetype, CGSize size, double durationInMs))success
                  failure:(void(^)(void))failure
{
    NSParameterAssert(success);
    NSParameterAssert(failure);
    
    NSURL *outputVideoLocalURL;
    NSString *mimetype;
    
    // Define a random output URL in the cache foler
    NSString * outputFileName = [NSString stringWithFormat:@"%.0f.mp4",[[NSDate date] timeIntervalSince1970]];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheRoot = [paths objectAtIndex:0];
    outputVideoLocalURL = [NSURL fileURLWithPath:[cacheRoot stringByAppendingPathComponent:outputFileName]];
    
    // Convert video container to mp4
    // Use medium quality to save bandwidth
    AVURLAsset* videoAsset = [AVURLAsset URLAssetWithURL:videoLocalURL options:nil];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:videoAsset presetName:AVAssetExportPresetMediumQuality];
    exportSession.outputURL = outputVideoLocalURL;
    
    // Check output file types supported by the device
    NSArray *supportedFileTypes = exportSession.supportedFileTypes;
    if ([supportedFileTypes containsObject:AVFileTypeMPEG4])
    {
        exportSession.outputFileType = AVFileTypeMPEG4;
        mimetype = @"video/mp4";
    }
    else
    {
        NSLog(@"[MXTools] convertVideoToMP4: Warning: MPEG-4 file format is not supported. Use QuickTime format.");
        
        // Fallback to QuickTime format
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        mimetype = @"video/quicktime";
    }
    
    // Export video file
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        
        AVAssetExportSessionStatus status = exportSession.status;
        
        // Come back to the UI thread to avoid race conditions
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Check status
            if (status == AVAssetExportSessionStatusCompleted)
            {
                
                AVURLAsset* asset = [AVURLAsset URLAssetWithURL:outputVideoLocalURL
                                                        options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [NSNumber numberWithBool:YES],
                                                                 AVURLAssetPreferPreciseDurationAndTimingKey,
                                                                 nil]
                                     ];
                
                double durationInMs = (1000 * CMTimeGetSeconds(asset.duration));
                
                // Extract the video size
                CGSize videoSize;
                NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                if (videoTracks.count > 0)
                {
                    
                    AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
                    videoSize = videoTrack.naturalSize;
                    
                    // The operation is complete
                    success(outputVideoLocalURL, mimetype, videoSize, durationInMs);
                }
                else
                {
                    
                    NSLog(@"[MXTools] convertVideoToMP4: Video export failed. Cannot extract video size.");
                    
                    // Remove output file (if any)
                    [[NSFileManager defaultManager] removeItemAtPath:[outputVideoLocalURL path] error:nil];
                    failure();
                }
            }
            else
            {
                
                NSLog(@"[MXTools] convertVideoToMP4: Video export failed. exportSession.status: %tu", status);
                
                // Remove output file (if any)
                [[NSFileManager defaultManager] removeItemAtPath:[outputVideoLocalURL path] error:nil];
                failure();
            }
        });
        
    }];
}

#pragma mark - JSON Serialisation

+ (NSString*)serialiseJSONObject:(id)jsonObject
{
    NSString *jsonString;

    if ([NSJSONSerialization isValidJSONObject:jsonObject])
    {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:nil];
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

+ (id)deserialiseJSONString:(NSString*)jsonString
{
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

+ (BOOL)isRunningUnitTests
{
#if DEBUG
    NSDictionary* environment = [[NSProcessInfo processInfo] environment];
    return (environment[@"XCTestConfigurationFilePath"] != nil);
#else
    return NO;
#endif
}

@end
