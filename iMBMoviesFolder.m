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

#import "iMBMoviesFolder.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import <QTKit/QTKit.h>
#import "iMedia.h"

@implementation iMBMoviesFolder

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"movies"];
	
	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Movies"]])
	{
		
	}
	return self;
}

- (NSMutableDictionary *)recordForMovieWithPath:(NSString *)filePath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *fileAttribs = [fm fileAttributesAtPath:filePath traverseLink:YES];
	NSMutableDictionary *newPicture = [NSMutableDictionary dictionary]; 
	[newPicture setObject:filePath forKey:@"ImagePath"];
	[newPicture setObject:filePath forKey:@"Preview"];
	
	[newPicture setObject:[NSNumber numberWithDouble:[[fileAttribs valueForKey:NSFileModificationDate] timeIntervalSinceReferenceDate]] forKey:@"DateAsTimerInterval"];
	
	NSString *cap = [[filePath lastPathComponent] stringByDeletingPathExtension];
	[newPicture setObject:cap forKey:@"Caption"];
				
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
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		
		@try {
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir && ![fm isPathHidden:cur])
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
	[root setName:LocalizedStringInThisBundle(@"Movies Folder", @"Name of your 'Movies' folder in your home directory")];
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
