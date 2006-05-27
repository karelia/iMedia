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
 */

#import "iMBFavouritePicturesParser.h"
#import "iMBPicturesFolder.h"
#import "iMedia.h"

@implementation iMBFavouritePicturesParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:nil])
	{
		myParsers = [[NSMutableArray array] retain];
	}
	return self;
}

- (void)dealloc
{
	[myParsers release];
	[super dealloc];
}

- (iMBLibraryNode *)parseDatabase
{
	NSArray *paths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"iMBFavouritePictures"];
	if ([paths count] == 0) return nil;
	
	iMBLibraryNode *favs = [[iMBLibraryNode alloc] init];
	[favs setName:LocalizedStringInThisBundle(@"Favourites", @"Favourite Pictures folder name")];
	[favs setIconName:@"heart"];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	iMBPicturesFolder *parser;
	iMBLibraryNode *node;
	BOOL isDir;
	NSEnumerator *e = [paths objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject])
	{
		if ([fm fileExistsAtPath:cur isDirectory:&isDir])
		{
			parser = [[iMBPicturesFolder alloc] initWithContentsOfFile:cur];
			node = [parser parseDatabase];
			if (node)
			{
				[node setName:[cur lastPathComponent]];
				[node setIconName:@"folder"];
				[favs addItem:node];
				[myParsers addObject:parser];
			}
			[parser release];
		}
	}
	return [favs autorelease];
}

@end
