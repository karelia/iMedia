/*
 This software is Copyright (c) 2007-2008
 Christiaan Hofman. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Christiaan Hofman nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSData+SKExtensions.h"

@implementation NSData (SKExtensions)

- (NSUInteger)lastIndexOfBytes:(const void *)patternBytes length:(NSUInteger)patternLength
{
    return [self indexOfBytes:patternBytes length:patternLength options:NSBackwardsSearch range:NSMakeRange(0, [self length])];
}

- (NSUInteger)indexOfBytes:(const void *)patternBytes length:(NSUInteger)patternLength
{
    return [self indexOfBytes:patternBytes length:patternLength options:0 range:NSMakeRange(0, [self length])];
}

- (NSUInteger)indexOfBytes:(const void *)patternBytes length:(NSUInteger)patternLength options:(NSInteger)mask
{
    return [self indexOfBytes:patternBytes length:patternLength options:mask range:NSMakeRange(0, [self length])];
}

- (NSUInteger)indexOfBytes:(const void *)patternBytes length:(NSUInteger)patternLength options:(NSInteger)mask range:(NSRange)searchRange
{
    NSUInteger selfLength = [self length];
    if (searchRange.location > selfLength || NSMaxRange(searchRange) > selfLength)
        [NSException raise:NSRangeException format:@"Range {%lu,%lu} exceeds length %lu", (unsigned long)searchRange.location, (unsigned long)searchRange.length, (unsigned long)selfLength];
    
    unsigned const char *selfBufferStart, *selfPtr, *selfPtrEnd, *selfPtrMax;
    unsigned const char firstPatternByte = *(const char *)patternBytes;
    BOOL backward = (mask & NSBackwardsSearch) != 0;
    
    if (patternLength == 0)
        return searchRange.location;
    if (patternLength > searchRange.length) {
        // This test is a nice shortcut, but it's also necessary to avoid crashing: zero-length CFDatas will sometimes(?) return NULL for their bytes pointer, and the resulting pointer arithmetic can underflow.
        return NSNotFound;
    }
    
    selfBufferStart = [self bytes];
    selfPtrMax = selfBufferStart + NSMaxRange(searchRange) + 1 - patternLength;
    if (backward) {
        selfPtr = selfPtrMax - 1;
        selfPtrEnd = selfBufferStart + searchRange.location - 1;
    } else {
        selfPtr = selfBufferStart + searchRange.location;
        selfPtrEnd = selfPtrMax;
    }
    
    for (;;) {
        if (memcmp(selfPtr, patternBytes, patternLength) == 0)
            return (selfPtr - selfBufferStart);
        
        if (backward) {
            do {
                selfPtr--;
            } while (*selfPtr != firstPatternByte && selfPtr > selfPtrEnd);
            if (*selfPtr != firstPatternByte)
                break;
        } else {
            selfPtr++;
            if (selfPtr == selfPtrEnd)
                break;
            selfPtr = memchr(selfPtr, firstPatternByte, (selfPtrMax - selfPtr));
            if (selfPtr == NULL)
                break;
        }
    }
	
    return NSNotFound;
}

@end