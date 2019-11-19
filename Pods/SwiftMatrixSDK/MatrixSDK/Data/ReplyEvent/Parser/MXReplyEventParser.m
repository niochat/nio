/*
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

#import "MXReplyEventParser.h"

static NSString* const kBodyReplyTextRegexPattern = @"^>.+?(?<!\\u000A)\\n{2}(.*)"; // Capture string after string sequence: start with ">" end with "\n\n" but do not end with "\\n\n"
static NSString* const kFormattedBodyRegexPattern = @"(^<mx-reply>.+</mx-reply>)(.*)";

@implementation MXReplyEventParser

- (MXReplyEventParts*)parse:(MXEvent*)replyEvent
{
    MXReplyEventParts *parts;
    
    if (replyEvent.isReplyEvent)
    {
        NSString *body = replyEvent.content[@"body"];
        NSString *formattedBody = replyEvent.content[@"formatted_body"];
        
        MXReplyEventBodyParts *bodyParts = [self parseBody:body];
        MXReplyEventFormattedBodyParts *formattedBodyParts = [self parseFormattedBody:formattedBody];
        
        if (bodyParts && formattedBodyParts)
        {
            parts = [[MXReplyEventParts alloc] initWithBodyParts:bodyParts andFormattedBodyParts:formattedBodyParts];
        }
    }
    
    return parts;
}

- (MXReplyEventBodyParts*)parseBody:(NSString*)replyEventBody
{
    if (!replyEventBody)
    {
        return nil;
    }
    
    MXReplyEventBodyParts *bodyParts;
    
    NSError *error = nil;
    
    NSRegularExpression *replyRegex = [NSRegularExpression regularExpressionWithPattern:kBodyReplyTextRegexPattern
                                                                                options:NSRegularExpressionDotMatchesLineSeparators
                                                                                  error:&error];
    
    NSTextCheckingResult *match = [replyRegex firstMatchInString:replyEventBody options:0 range:NSMakeRange(0, replyEventBody.length)];
    
    if (error)
    {
        NSLog(@"[MXReplyEventParser] Regex pattern %@ is not valid. Error: %@", kBodyReplyTextRegexPattern, error);
    }
    else if(match && match.numberOfRanges == 2)
    {
        NSRange replyTextRange = [match rangeAtIndex:1];
        
        NSString *replyTextPrefix = [replyEventBody substringToIndex:replyTextRange.location];
        NSString *replyText = [replyEventBody substringWithRange:replyTextRange];
        
        bodyParts = [MXReplyEventBodyParts new];
        bodyParts.replyTextPrefix = replyTextPrefix;
        bodyParts.replyText = replyText;
    }
    
    return bodyParts;
}

- (MXReplyEventFormattedBodyParts*)parseFormattedBody:(NSString*)replyEventFormattedBody
{
    if (!replyEventFormattedBody)
    {
        return nil;
    }
    
    MXReplyEventFormattedBodyParts *bodyParts;
    
    NSError *error = nil;
    
    NSRegularExpression *replyRegex = [NSRegularExpression regularExpressionWithPattern:kFormattedBodyRegexPattern
                                                                                options:NSRegularExpressionDotMatchesLineSeparators | NSRegularExpressionCaseInsensitive
                                                                                  error:&error];
    
    NSTextCheckingResult *match = [replyRegex firstMatchInString:replyEventFormattedBody options:0 range:NSMakeRange(0, replyEventFormattedBody.length)];
    
    if (error)
    {
        NSLog(@"[MXReplyEventParser] Regex pattern %@ is not valid. Error: %@", kFormattedBodyRegexPattern, error);
    }
    else if(match && match.numberOfRanges == 3)
    {        
        NSString *replyTextPrefix = [replyEventFormattedBody substringWithRange:[match rangeAtIndex:1]];
        NSString *replyText = [replyEventFormattedBody substringWithRange:[match rangeAtIndex:2]];
        
        bodyParts = [MXReplyEventFormattedBodyParts new];
        bodyParts.replyTextPrefix = replyTextPrefix;
        bodyParts.replyText = replyText;
    }
    
    return bodyParts;
}

@end
