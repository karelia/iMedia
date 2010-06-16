/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
 Redistributions of source code must retain the original terms stated here,
 including this list of conditions, the disclaimer noted below, and the
 following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
 Redistributions in binary form must include, in an end-user-visible manner,
 e.g., About window, Acknowledgments window, or similar, either a) the original
 terms stated here, including this list of conditions, the disclaimer noted
 below, and the aforementioned copyright notice, or b) the aforementioned
 copyright notice and a link to karelia.com/imedia.
 
 Neither the name of Karelia Software, nor Sandvox, nor the names of
 contributors to iMedia Browser may be used to endorse or promote products
 derived from the Software without prior and express written permission from
 Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */


// Author: Pierre Bernard, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------

#import "IMBOrderedDictionary.h"


@implementation IMBMutableOrderedDictionary

#pragma mark Init & Dealloc

+ (IMBMutableOrderedDictionary*)orderedDictionaryWithCapacity:(NSUInteger)inCapacity
{
	return [[[[self class] alloc] initWithCapacity:inCapacity] autorelease];
}

- (id)initWithCapacity:(NSUInteger)inCapacity
{
	if ((self = [super init]) != nil) {
		_dictionary = [[NSMutableDictionary alloc] initWithCapacity:inCapacity];
		_array = [[NSMutableArray alloc] initWithCapacity:inCapacity];
	}
	
	return self;
}

- (void)dealloc
{
	[_dictionary release], _dictionary = nil;
	[_array release], _array = nil;
	
	[super dealloc];
}

#pragma mark Immutable Primitives

- (NSUInteger)count;
{
    return [_array count];
}

- (id)objectForKey:(id)inKey
{
	return [_dictionary objectForKey:inKey];
}

- (NSEnumerator *)keyEnumerator;
{
	return [_array objectEnumerator];
}

#pragma mark Mutable Primitives

- (void)setObject:(id)inObject forKey:(id)inKey
{
	BOOL isNewKey = ([_dictionary objectForKey:inKey] == nil);
	
	[_dictionary setObject:inObject forKey:inKey];
	
	if (isNewKey) {
		[_array addObject:inKey];
	}
}

- (void)removeObjectForKey:(id)inKey
{
	id object = [_dictionary objectForKey:inKey];
	
	if (object != nil) {
		[_dictionary removeObjectForKey:inKey];
		[_array removeObject:object];
	}
}

@end
