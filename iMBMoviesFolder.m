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
#import "NSWorkspace+Extensions.h"
#import <QTKit/QTKit.h>
#import "QTMovie+iMedia.h"
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
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingString:@"/Movies/"]])
	{
		
	}
	return self;
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSArray *movieTypes = [QTMovie movieFileTypes:QTIncludeAllTypes];
	NSMutableArray *movies = [NSMutableArray array];
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	int poolRelease = 0;
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingFormat:@"/%@", cur];
		
	//	if ([filePath rangeOfString:@"iPhoto Library"].location != NSNotFound) continue;
	//	if ([filePath rangeOfString:@"Aperture Library"].location != NSNotFound) continue;
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir)
		{
			iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
			[root addItem:folder];
			[folder release];
			[folder setIconName:@"folder"];
			[folder setName:[fm displayNameAtPath:[fm displayNameAtPath:[cur lastPathComponent]]]];
			[self recursivelyParse:filePath withNode:folder];
		}
		else
		{
			if ([movieTypes indexOfObject:[[filePath lowercaseString] pathExtension]] != NSNotFound)
			{
				NSDictionary *fileAttribs = [fm fileAttributesAtPath:filePath traverseLink:YES];
				
				NSMutableDictionary *newPicture = [NSMutableDictionary dictionary]; 
				[newPicture setObject:filePath forKey:@"ImagePath"];
				[newPicture setObject:[fm displayNameAtPath:[filePath lastPathComponent]] forKey:@"Caption"];
#warning TODO: you could get a richer caption out of the metadata from the movie, though it might be slow unless lazily instantiated.
				[newPicture setObject:filePath forKey:@"ThumbPath"];
				[newPicture setObject:[NSNumber numberWithDouble:[[fileAttribs valueForKey:NSFileModificationDate] timeIntervalSinceReferenceDate]] forKey:@"DateAsTimeInterval"];
				//we want to cache the first frame of the movie here as we will be in a background thread
				QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:[[NSURL fileURLWithPath:filePath] path]];
				QTMovie *movie = [[QTMovie alloc] initWithDataReference:ref error:nil];
				NSImage *thumb = [movie betterPosterImage];
				[movie release];
				if (thumb)
				{
#warning TODO: it will probably be much faster NOT to load any thumbnails until they are actually needed, THEN cache them.
					[newPicture setObject:thumb forKey:@"CachedThumb"];
				}
				else
				{
          [newPicture setObject:[[NSWorkspace sharedWorkspace]
            iconForAppWithBundleIdentifier:@"com.apple.quicktimeplayer"]
								   forKey:@"CachedThumb"];
				}
				[movies addObject:newPicture];
			}
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
	
	[self recursivelyParse:[NSHomeDirectory() stringByAppendingString:@"/Movies/"] 
				  withNode:root];
	
	return [root autorelease];
}

@end
