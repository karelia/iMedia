/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBObjectFifoCache.h"
#import "IMBObject.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSUInteger sCacheSize = 512;
static IMBObjectFifoCache* sSharedCache = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectFifoCache


//----------------------------------------------------------------------------------------------------------------------


+ (void) setSize:(NSUInteger)inSize
{
	sCacheSize = inSize;
}


+ (NSUInteger) size
{
	return sCacheSize;
}


//----------------------------------------------------------------------------------------------------------------------


+ (IMBObjectFifoCache*) threadSafeSharedCache
{
	if (sSharedCache == nil)
	{
		@synchronized(self)
		{
			if (sSharedCache == nil)
			{
				sSharedCache = [[IMBObjectFifoCache alloc] init];
			}
		}
	}
	
	return sSharedCache;
}


- (id) init
{
	if (self = [super init])
	{
		_objects = [[NSMutableArray alloc] initWithCapacity:sCacheSize];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_objects);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Keep removing the oldest objects (lowest indexes) until the array no longer exceeds the cache size...

- (void) _removeOldestObjects
{
	if (_objects != nil)
	{
		while ([_objects count] > sCacheSize)
		{
			IMBObject* object = [_objects objectAtIndex:0];
			(void) [object unloadThumbnail];
			[_objects removeObjectAtIndex:0];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Add a new object to the end of the array. If we now exceed the cache size, then bump the oldest  
// objects off the cache...


- (void) _addObject:(IMBObject*)inObject
{
	[_objects addObject:inObject];
	[self _removeOldestObjects];
	
//	NSLog(@"%s count = %d",__FUNCTION__,(int)[_objects count]);
}


+ (void) addObject:(IMBObject*)inObject
{
	if ([NSThread isMainThread])
	{							
		[[self threadSafeSharedCache] _addObject:inObject];
	}
	else
	{
		[[self threadSafeSharedCache] 
			performSelectorOnMainThread:@selector(_addObject:) 
			withObject:inObject 
			waitUntilDone:NO 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Remove the given object from the cache. Please note that it may be in the cache multiple times. All 
// occurences are removed...

- (void) _removeObject:(IMBObject*)inObject
{
	if (_objects != nil)
	{
		while ([_objects indexOfObject:inObject])
		{
			(void) [inObject unloadThumbnail];
			[_objects removeObject:inObject];
		}
	}
}


+ (void) removeObject:(IMBObject*)inObject
{
	if ([NSThread isMainThread])
	{							
		[[self threadSafeSharedCache] _removeObject:inObject];
	}
	else
	{
		[[self threadSafeSharedCache] 
			performSelectorOnMainThread:@selector(_removeObject:) 
			withObject:inObject 
			waitUntilDone:NO 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Remove all objects from the cache...

- (void) _removeAllObjects
{
	[_objects makeObjectsPerformSelector:@selector(unloadThumbnail)];
}


+ (void) removeAllObjects
{
	if ([NSThread isMainThread])
	{							
		[[self threadSafeSharedCache] _removeAllObjects];
	}
	else
	{
		[[self threadSafeSharedCache] 
			performSelectorOnMainThread:@selector(_removeAllObjects) 
			withObject:nil 
			waitUntilDone:NO 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Returns the current count of objects in the cache...

- (NSUInteger) _count
{
	return [_objects count];
}


+ (NSUInteger) count
{
	return [[self threadSafeSharedCache] _count];
}


//----------------------------------------------------------------------------------------------------------------------


@end
