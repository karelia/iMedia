/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>  

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

