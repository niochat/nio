/*
 Copyright 2015 OpenMarket Ltd

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

#import "MXPushRuleEventMatchConditionChecker.h"

@interface MXPushRuleEventMatchConditionChecker ()
{
    NSMutableDictionary* regExByPatternDict;
}
@end

@implementation MXPushRuleEventMatchConditionChecker

- (BOOL)isCondition:(MXPushRuleCondition*)condition satisfiedBy:(MXEvent*)event roomState:(MXRoomState*)roomState withJsonDict:(NSDictionary*)contentAsJsonDict
{
    BOOL isSatisfied = NO;
    
    // Retrieve the value
    NSObject *value = [contentAsJsonDict valueForKeyPath:condition.parameters[@"key"]];
    
    if (value && [value isKindOfClass:[NSString class]])
    {
        // If it exists, compare it to the regular expression in condition.parameter.pattern
        NSString *stringValue = (NSString *)value;
        NSString* pattern = (NSString*)condition.parameters[@"pattern"];
        
        // if there is no pattern
        if (!pattern || !pattern.length)
        {
            // cannot match
            return NO;
        }
        
        // the regexs are cached to avoid creating them at each call
        // and it also should speed up it/
        if (!regExByPatternDict)
        {
            regExByPatternDict = [[NSMutableDictionary alloc] init];
        }
        

        NSRegularExpression *regex = [regExByPatternDict objectForKey:pattern];

        // not yet defined
        if (!regex)
        {
            // defined it.
            regex = [NSRegularExpression regularExpressionWithPattern:[self globToRegex:pattern] options:NSRegularExpressionCaseInsensitive error:nil];
            [regExByPatternDict setObject:regex forKey:pattern];
        }
           

        if ([regex numberOfMatchesInString:stringValue options:0 range:NSMakeRange(0, stringValue.length)])
        {
            isSatisfied = YES;
        }
    }

    return isSatisfied;
}

- (NSString*)globToRegex:(NSString*)glob
{
    NSString *res = [glob stringByReplacingOccurrencesOfString:@"*" withString:@".*"];
    res = [res stringByReplacingOccurrencesOfString:@"?" withString:@"."];
    
    // In all cases, enable world delimiters
    res = [NSString stringWithFormat:@"(^|\\W)%@($|\\W)", res];

    return res;
}

@end
