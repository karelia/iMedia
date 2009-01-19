/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#import "LibraryItemsValueTransformer.h"
#import "iMBLibraryNode.h"

@implementation LibraryItemsValueTransformer

int imageDateSort(id i1, id i2, void *context) {
	NSDate *date1;
	NSDate *date2;
	
	if(![[i1 objectForKey:@"DateAsTimerInterval"] isKindOfClass:[NSDate class]])
	{
		NSNumber *d1 = [i1 objectForKey:@"DateAsTimerInterval"];
		NSNumber *d2 = [i2 objectForKey:@"DateAsTimerInterval"];
	
		date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:[d1 doubleValue]];
		date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:[d2 doubleValue]];
	}
	else
	{
		date1 = [i1 objectForKey:@"DateAsTimerInterval"];
		date2 = [i2 objectForKey:@"DateAsTimerInterval"];
	}
	return [date1 compare:date2];
}

+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return NO;
}

- (id)transformedValue:(id)beforeObject
{
	if (nil == beforeObject)
	{
		return nil;
	}
	
	if ([beforeObject isKindOfClass:[NSArray class]])
	{		
		NSMutableArray *newPhotos = [NSMutableArray array];
		NSArray *playlistRecords = (NSArray*)beforeObject;
		NSEnumerator *playlistRecordsEnum = [playlistRecords objectEnumerator];
		iMBLibraryNode *rec = nil;
		
		while(rec = [playlistRecordsEnum nextObject])
		{
			[newPhotos addObject:rec];
		}
		
		[newPhotos sortUsingFunction:imageDateSort context:nil];
		return newPhotos;
	}
	
	return nil;
}

@end

