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
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 This file was Authored by Dan Wood
 
 */

#import "NSPasteboard+iMedia.h"


@implementation NSPasteboard ( iMedia )

+ (NSArray *)fileAndURLTypes
{
	return [NSArray arrayWithObjects:
		@"WebURLsWithTitlesPboardType",
		NSFilenamesPboardType,
		NSURLPboardType,
		NSStringPboardType,
		nil];
}

+ (NSArray *)URLTypes
{
	return [NSArray arrayWithObjects:
		@"WebURLsWithTitlesPboardType",
		NSURLPboardType,
		NSStringPboardType,
		nil];
}

/*!	Writes the list of files, with the list of names.
	If urls is nil, then file URLs are generated.
	if files is nil, then no files are generated.
	If names is nil, names is determined from file/URL last path component.
	Shouldn't have both files and urls set.
*/
- (void) writeURLs:(NSArray *)urls files:(NSArray *)files names:(NSArray *)names
{
	NSAssert( (nil != urls) ^ (nil != files), @"Only urls or files can be set");
	if (nil == names)
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSMutableArray *generatedNames = [NSMutableArray array];
		NSEnumerator *theEnum = [((nil != urls) ? urls : files)  objectEnumerator];
		id object;

		while (nil != (object = [theEnum nextObject]) )
		{
			NSString *path = (nil != urls) ? [((NSURL *)object) path] : (NSString *)object;
			NSString *betterName = [[fm displayNameAtPath:path] stringByDeletingPathExtension];
			[generatedNames addObject:betterName];
		}
		names = generatedNames;	// Probably better than just the first string
	}
	[self setString:[names componentsJoinedByString:@"\n"] forType:NSStringPboardType];
	
	NSMutableArray *urlStrings = [NSMutableArray array];
	
	if (nil != files)	// files specified, so generate URLs and put on the pasteboard
	{
		NSMutableArray *generatedURLs = [NSMutableArray array];
		NSEnumerator *theEnum = [files objectEnumerator];
		NSString *path;

		while (nil != (path = [theEnum nextObject]) )
		{
			NSURL *fileURL = [NSURL fileURLWithPath:path];
			[generatedURLs addObject:fileURL];
			[urlStrings addObject:[fileURL absoluteString]];
		}
		urls = generatedURLs;		// save for later
		
		[self setPropertyList:files forType:NSFilenamesPboardType];
	}
	else	// we have URLs, need to get an array of their strings
	{
		NSEnumerator *theEnum = [urls objectEnumerator];
		NSURL *theURL;

		while (nil != (theURL = [theEnum nextObject]) )
		{
			[urlStrings addObject:[theURL absoluteString]];
		}
	}
	
	// Now we should have URLs and names
	// Write the *first* URL to the pasteboard
	if ([urls count])
	{
		[[urls objectAtIndex:0] writeToPasteboard:self];
	}
	
	NSArray *URLsWithTitles = [NSArray arrayWithObjects:urlStrings, names, nil];
	BOOL OK = [self setPropertyList:URLsWithTitles forType:@"WebURLsWithTitlesPboardType"];
	if (!OK)
	{
		NSLog(@"Couldn't set WebURLsWithTitlesPboardType");
	}
}

@end
