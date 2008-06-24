/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2008 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2008 by Karelia Software et al.
 
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


#import "iMBMoviesFolder.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import <QTKit/QTKit.h>
#import "iMedia.h"

@implementation iMBMoviesFolder

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaConfiguration registerParser:[self class] forMediaType:@"movies"];

	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Movies"]])
	{
		
	}
	return self;
}

- (void) dealloc {
	[myFileExtensionHints release];
	[super dealloc];
}

- (NSMutableDictionary *)recordForMovieWithPath:(NSString *)filePath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *fileAttribs = [fm fileAttributesAtPath:filePath traverseLink:YES];
	NSMutableDictionary *newPicture = [NSMutableDictionary dictionary]; 
	[newPicture setObject:filePath forKey:@"ImagePath"];
	[newPicture setObject:filePath forKey:@"Preview"];
	
	[newPicture setObject:[NSNumber numberWithDouble:[[fileAttribs valueForKey:NSFileModificationDate] timeIntervalSinceReferenceDate]] forKey:@"DateAsTimerInterval"];
    [newPicture setObject:[fm displayNameAtPath:filePath] forKey:@"Caption"];
				
	return newPicture;
}

- (void)setFileExtensionHints:(NSArray *)extensions
{
	[myFileExtensionHints autorelease];
	myFileExtensionHints = [extensions retain];
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSArray *movieTypes = myFileExtensionHints;
	if (!movieTypes) movieTypes = [QTMovie movieFileTypes:QTIncludeAllTypes];
	NSMutableArray *movies = [NSMutableArray array];
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	int poolRelease = 0;
	NSArray * excludedFolders = [[iMediaConfiguration sharedConfiguration] excludedFolders];
   
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
      if ([excludedFolders containsObject:filePath]) continue;

		@try {
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && ![fm isPathHidden:filePath])
			{
				if (isDir)
				{
					if ([cur pathExtension] && [[cur pathExtension] length] > 0)
					{
						if ([[cur pathExtension] isEqualToString:@"iMovieProject"]) // handle the iMovie Project folder wrapper.
						{
							NSString *cache = [filePath stringByAppendingPathComponent:@"Cache/Timeline Movie.mov"];
							if ([fm fileExistsAtPath:cache])
							{
								NSMutableDictionary *rec = [self recordForMovieWithPath:cache];
								[rec setObject:filePath forKey:@"ImagePath"];
								[rec setObject:[filePath lastPathComponent] forKey:@"Caption"];
								[rec setObject:cache forKey:@"Preview"];
								[movies addObject:rec];
							}
						}
					}
					else
					{
						iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
						[root addItem:folder];
						[folder release];
						[folder setIconName:@"folder"];
						[folder setName:[fm displayNameAtPath:filePath]];
						[self recursivelyParse:filePath withNode:folder];
					}
				}
				else
				{
					if ([movieTypes indexOfObject:[[filePath lowercaseString] pathExtension]] != NSNotFound)
					{
						[movies addObject:[self recordForMovieWithPath:filePath]];
					}
				}
			}
		}
		@catch (NSException *ex) {
			// do nothing and don't insert it as a record.
		}
		poolRelease++;
		if (poolRelease == 5)
		{
			poolRelease = 0;
			[innerPool release];
			innerPool = [[NSAutoreleasePool alloc] init];
		}
	}
	[innerPool release];
	[root setAttribute:movies forKey:@"Movies"];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInIMedia(@"Movies Folder", @"Name of your 'Movies' folder in your home directory")];
	[root setIconName:@"picturesFolder"];
	NSString *folder = [self databasePath];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:folder])
	{
		[root release];
		return nil;
	}
	
	[self recursivelyParse:folder withNode:root];
	
	return [root autorelease];
}

@end
