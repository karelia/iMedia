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
#import "iMBMusicFolder.h"
#import "iMedia.h"
#import <QTKit/QTKit.h>

@implementation iMBMusicFolder

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"music"];
	
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Music"]])
	{
		myParseMetaData = YES;
	}
	return self;
}

- (void)dealloc
{
	[myUnknownArtist autorelease];
	[super dealloc];
}

- (void)setParseMetaData:(BOOL)flag
{
	myParseMetaData = flag;
}

- (BOOL)parseMetaData
{
	return myParseMetaData;
}

- (void)setUnknownArtist:(NSString *)artist
{
	[myUnknownArtist autorelease];
	myUnknownArtist = [artist copy];
}

- (NSString *)unkownArtist
{
	return myUnknownArtist;
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSMutableArray *movieTypes = [NSMutableArray arrayWithArray: [QTMovie movieFileTypes:QTIncludeAllTypes]];
	[movieTypes removeObject:@"kar"];
	NSMutableArray *tracks = [NSMutableArray array];
	NSBundle *bndl = [NSBundle bundleForClass:[self class]];
	NSString *iconPath = [bndl pathForResource:@"MBiTunes4Song" ofType:@"png"];
	NSImage *songIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	iconPath = [bndl pathForResource:@"iTunesDRM" ofType:@"png"];
	NSImage *drmIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	int poolRelease = 0;
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		if ([[filePath lastPathComponent] isEqualToString:@"iTunes"]) continue;
		if ([[filePath lastPathComponent] isEqualToString:@"GarageBand"]) continue;
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir && ![fm isPathHidden:cur] && ![ws isFilePackageAtPath:filePath])
		{
			iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
			[root addItem:folder];
			[folder release];
			[folder setIconName:@"folder"];
			[folder setName:[fm displayNameAtPath:filePath]];
			[self recursivelyParse:filePath withNode:folder];
		}
		else
		{
			if ([movieTypes indexOfObject:[[filePath lowercaseString] pathExtension]] != NSNotFound)
			{
				NSMutableDictionary *song = [NSMutableDictionary dictionary]; 
				
				//we want to cache the first frame of the movie here as we will be in a background thread
				QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:[[NSURL fileURLWithPath:filePath] path]];
				NSError *error = nil;
				QTMovie *movie = nil;
				
				if (myParseMetaData)
				{
					movie = [[QTMovie alloc] initWithAttributes:
						[NSDictionary dictionaryWithObjectsAndKeys: 
							ref, QTMovieDataReferenceAttribute,
							[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
							nil] error:&error];
				}
				
				// Get the meta data from the QTMovie
				NSString *val = nil;
				if (myParseMetaData)
				{
					val = [movie attributeWithFourCharCode:kUserDataTextFullName];
				}
				if (!val)
				{
					val = [cur stringByDeletingPathExtension];
				}
				[song setObject:val forKey:@"Name"];
				val = nil;
				if (myParseMetaData)
				{
					val = [movie attributeWithFourCharCode:FOUR_CHAR_CODE(0xA9415254)]; //'©ART'
				}
				if (!val)
				{
					if (myUnknownArtist)
					{
						val = myUnknownArtist;
					}
					else
					{
						val = LocalizedStringInThisBundle(@"Unknown", @"Unkown music key");
					}
				}
				[song setObject:val forKey:@"Artist"];
				if (myParseMetaData)
				{
					NSNumber *time = [NSNumber numberWithFloat:[movie durationInSeconds] * 1000];
					// Used for binding
					[song setObject:time forKey:@"Total Time"];
					if (![movie isDRMProtected])
					{
						[song setObject:songIcon forKey:@"Icon"];
					}
					else
					{
						[song setObject:drmIcon forKey:@"Icon"];
					}
				}
				else
				{
					[song setObject:[NSNumber numberWithInt:0] forKey:@"Total Time"];
					[song setObject:songIcon forKey:@"Icon"];
				}
				
				[song setObject:filePath forKey:@"Location"];
				[song setObject:filePath forKey:@"Preview"];
				
				[movie release];
				[tracks addObject:song];
			}
		}
		poolRelease++;
		if (poolRelease == 15)
		{
			poolRelease = 0;
			[innerPool release];	// don't use drain, maybe we retain 10.3 compatibility?
			innerPool = [[NSAutoreleasePool alloc] init];
		}
	}
	[innerPool release];
	[root setAttribute:tracks forKey:@"Tracks"];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"Music Folder", @"Name of your 'Music' folder in your home directory")];
	[root setIconName:@"folder"];
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
