/*
 Copyright 2019 New Vector Ltd

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

#import "MXReactionCount.h"

@implementation MXReactionCount

- (BOOL)myUserHasReacted
{
    // Take local echoes into consideration first
    if (self.localEchoesOperations.count)
    {
        return self.localEchoesOperations.lastObject.isAddOperation;
    }
    else
    {
        return (_myUserReactionEventId != nil);
    }
}

- (BOOL)containsLocalEcho
{
    return (self.localEchoesOperations.count > 0);
}

- (NSString *)description
{
    NSString *echoes = self.localEchoesOperations.count ? [NSString stringWithFormat:@" - echoes: %@", @(self.localEchoesOperations.count)] : @"";

    if (self.myUserHasReacted)
    {
        return [NSString stringWithFormat:@"(%@: %@%@)", self.reaction, @(self.count), echoes];
    }
    else
    {
        return [NSString stringWithFormat:@"%@: %@%@", self.reaction, @(self.count), echoes];
    }
}

@end
