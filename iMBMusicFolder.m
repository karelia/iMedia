/*
 iMedia Browser <http://karelia.com/imedia>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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

#import "iMBMusicFolder.h"
#import "iMedia.h"
#import <QTKit/QTKit.h>

static NSImage *sSongIcon = nil;
static NSImage *sDRMIcon = nil;

@implementation iMBMusicFolder

+ (void)initialize	// preferred over +load in most cases
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSBundle *bndl = [NSBundle bundleForClass:[self class]];
	NSString *iconPath = [bndl pathForResource:@"MBiTunes4Song" ofType:@"png"];
	sSongIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	iconPath = [bndl pathForResource:@"iTunesDRM" ofType:@"png"];
	sDRMIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	[pool release];
}

+ (void)load	// registration of this class
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
	[myUnknownArtist release];
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

- (NSString *)unknownArtist
{
	return myUnknownArtist;
}

#warning Note: We could definitely speed this up, if it's an issue, by delaying the processing of the QTMovie objects.

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
   
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	int poolRelease = 0;
   NSArray * excludedFolders = [[iMediaBrowser sharedBrowserWithoutLoading] excludedFolders];
   
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		if ([[filePath lastPathComponent] isEqualToString:@"iTunes"]) continue;
		if ([[filePath lastPathComponent] isEqualToString:@"GarageBand"]) continue;
      if ([excludedFolders containsObject:filePath]) continue;
      
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && ![fm isPathHidden:filePath] && ![ws isFilePackageAtPath:filePath])
		{
			if (isDir)
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
					OSErr err = EnterMoviesOnThread(0);
					if (err != noErr) NSLog(@"Unable to EnterMoviesOnThread; %d", err);

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
						NSNumber *theTime = [NSNumber numberWithFloat:[movie durationInSeconds] * 1000];
						// Used for binding
						[song setObject:theTime forKey:@"Total Time"];
						if (![movie isDRMProtected])
						{
							[song setObject:sSongIcon forKey:@"Icon"];
						}
						else
						{
							[song setObject:sDRMIcon forKey:@"Icon"];
						}
					}
					else
					{
						[song setObject:[NSNumber numberWithInt:0] forKey:@"Total Time"];
						[song setObject:sSongIcon forKey:@"Icon"];
					}
					
					[song setObject:filePath forKey:@"Location"];
					[song setObject:filePath forKey:@"Preview"];
					
					[movie release];
					[tracks addObject:song];

					err = ExitMoviesOnThread();
					if (err != noErr) NSLog(@"Unable to ExitMoviesOnThread; %d", err);

				}
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
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	[root setName:LocalizedStringInThisBundle(@"Music Folder", @"Name of your 'Music' folder in your home directory")];
	[root setIconName:@"folder"];
	NSString *folder = [self databasePath];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:folder])
	{
		return nil;
	}

	NSMutableArray *movieTypes = [NSMutableArray arrayWithArray: [QTMovie movieFileTypes:QTIncludeAllTypes]];
	[movieTypes removeObject:@"kar"];
	
	[self recursivelyParse:folder withNode:root];
   	
	return root;
}

@end
