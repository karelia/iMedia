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

#import "iMBMusicFolder.h"
#import "MetadataUtility.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSImage+iMedia.h"

#import <QTKit/QTKit.h>

static NSImage *sSongIcon = nil;
static NSImage *sDRMIcon = nil;

@implementation iMBMusicFolder

+ (void)initialize	// preferred over +load in most cases
{
	if ( self == [iMBMusicFolder class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		sSongIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:@"mp3"] retain];
		sDRMIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:@"m4p"] retain];
		
		[pool release];
	}
}

+ (void)load	// registration of this class
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	[iMediaConfiguration registerParser:[self class] forMediaType:@"music"];

	[pool release];
}

- (id)initWithContentsOfFile:(NSString *)file musicFolderName:(NSString *)musicFolderName unknownArtistName:(NSString *)unknownArtistName iconName:(NSString *)iconName parseMetadata:(BOOL)parseMetadata
{
    self = [super initWithContentsOfFile:file];
    if (self)
    {
        myMusicFolderName = [musicFolderName copy];
        myUnknownArtistName = [unknownArtistName copy];
        myIconName = [iconName copy];
        myParseMetadata = parseMetadata;
    }
    return self;
}

- (id)initWithContentsOfFile:(NSString *)file
{
    NSString *musicFolderName = LocalizedStringInIMedia(@"Music Folder", @"Name of your 'Music' folder in your home directory");
    NSString *unknownArtistName = LocalizedStringInIMedia(@"Unknown", @"Unknown music/sound artist");
    NSString *iconName = @"folder";

	return [self initWithContentsOfFile:file musicFolderName:musicFolderName unknownArtistName:unknownArtistName iconName:iconName parseMetadata:YES];
}

- (id)init
{
	return [self initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Music"]];
}

- (void)dealloc
{
    [myMusicFolderName release]; myMusicFolderName = nil;
    [myUnknownArtistName release]; myUnknownArtistName = nil;
    [myIconName release]; myIconName = nil;

    [super dealloc];
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root movieTypes:(NSArray *)movieTypes
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *contents = [fileManager directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSMutableArray *tracks = [NSMutableArray array];
   
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	int poolRelease = 0;
	NSArray *excludedFolders = [[iMediaConfiguration sharedConfiguration] excludedFolders];
   
	NSString *currentFile;
	while (currentFile = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent:currentFile];

        // skip files that are likely to be included elsewhere or have been explicitly excluded
		if ([[filePath lastPathComponent] isEqualToString:@"iTunes"]) continue;
		if ([[filePath lastPathComponent] isEqualToString:@"GarageBand"]) continue;
		if ([excludedFolders containsObject:filePath]) continue;
        
        BOOL isDirectory;
		if ( [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] &&
            ![fileManager isPathHidden:filePath] &&
            ![workspace isFilePackageAtPath:filePath])
		{
			if (isDirectory)
			{
				iMBLibraryNode *folder = [[[iMBLibraryNode alloc] init] autorelease];
				[folder setIcon:[NSImage genericFolderIcon]];
				[folder setName:[fileManager displayNameAtPath:filePath]];
				[self recursivelyParse:filePath withNode:folder movieTypes:movieTypes];

                // NOTE: It is not legal to add items on a thread; so we do it on the main thread.
                // [root addItem:folder];
                [root performSelectorOnMainThread:@selector(addItem:) withObject:folder waitUntilDone:YES];
			}
			else
			{
				if ([movieTypes indexOfObject:[[filePath lowercaseString] pathExtension]] != NSNotFound)
				{
					NSMutableDictionary *song = [NSMutableDictionary dictionary]; 
					
                    NSDictionary *arguments = [[MetadataUtility sharedMetadataUtility] getMetadataForFile:filePath];
                    
                    if (arguments)
                    {
                        // handle the song duration
                        NSNumber *duration = [arguments objectForKey:@"kMDItemDurationSeconds"];
                        if ( duration != nil )
                        {
                            [song setObject:[NSNumber numberWithFloat:[duration floatValue]*1000] forKey:@"Total Time"];
                        }
                        else
                        {
                            [song setObject:[NSNumber numberWithInt:0] forKey:@"Total Time"];
                        }
                        
                        // handle the song title
                        NSString *title = [arguments objectForKey:@"kMDItemTitle"];
                        if ( title != nil )
                        {
                            [song setObject:title forKey:@"Name"];
                        }
                        else
                        {
                            [song setObject:[[filePath lastPathComponent] stringByDeletingPathExtension] forKey:@"Name"];
                        }
                        
                        // handle the song artist
                        NSArray *authors = [arguments objectForKey:@"kMDItemAuthors"];
                        if ( authors != nil && [authors count] > 0 )
                        {
                            [song setObject:[authors objectAtIndex:0] forKey:@"Artist"];
                        }
                        else
                        {
                            [song setObject:myUnknownArtistName forKey:@"Artist"];
                        }
                        
                        // handle the song protected vs. unprotected icon
                        NSString *kind = [arguments objectForKey:@"kMDItemKind"];
                        if ( kind != nil && [kind rangeOfString:@"Protected"].location != NSNotFound )
                        {
                            [song setObject:sDRMIcon forKey:@"Icon"];
                        }
                        else
                        {
                            [song setObject:sSongIcon forKey:@"Icon"];
                        }
                        
                        [song setObject:filePath forKey:@"Location"];
                        [song setObject:filePath forKey:@"Preview"];
                        
                        [tracks addObject:song];
                    }
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


- (NSMutableArray*) audioTypes
{
	// Return a (filtered) array of file extensions for audio files that QT can open...
	
	static NSMutableArray* sAudioTypes = nil;
	static NSString* sAudioTypesMutex = @"mutex";
	
	@synchronized(sAudioTypesMutex)
	{
		if (sAudioTypes == nil)
		{
			sAudioTypes = [[NSMutableArray alloc] init];
			NSArray* movieTypes = [QTMovie movieTypesWithOptions:QTIncludeAllTypes];
			NSEnumerator* e = [movieTypes objectEnumerator];
			NSString* uti;
			CFDictionaryRef utiDeclaration;
			CFDictionaryRef utiSpecification;
			CFTypeRef extension;
			
			while (uti = [e nextObject])
			{
				if (UTTypeConformsTo((CFStringRef)uti,kUTTypeAudio))
				{
					if (utiDeclaration = UTTypeCopyDeclaration((CFStringRef)uti))
					{
						if (utiSpecification = CFDictionaryGetValue(utiDeclaration, kUTTypeTagSpecificationKey))
						{
							if (extension = CFDictionaryGetValue(utiSpecification, kUTTagClassFilenameExtension))
							{
								if (CFGetTypeID(extension) == CFStringGetTypeID())
								{
									[sAudioTypes addObject:(NSString*)extension];
								}
								else if (CFGetTypeID(extension) == CFArrayGetTypeID())
								{
									[sAudioTypes addObjectsFromArray:(NSArray*)extension];
								}
							}
						}
						
						CFRelease(utiDeclaration);
					}
				}
			}
			
			// This was put in as part of an "ubercaster fix" in r250. (Not sure exactly what file type this is)
			[sAudioTypes removeObject:@"kar"];
		}
	}
	
    return sAudioTypes;
}

- (void)populateLibraryNode:(iMBLibraryNode *)root name:(NSString *)name databasePath:(NSString *)databasePath
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSFileManager *mgr = [NSFileManager defaultManager];
	NSString *folder = databasePath;
	
	if ( [mgr fileExistsAtPath:folder] )
    {
		NSMutableArray *movieTypes = [self audioTypes];
		
		[self recursivelyParse:folder withNode:root movieTypes:movieTypes];
    }
    
    // the node is populated, so remove the 'loading' moniker. do this on the main thread to be friendly to bindings.
	[root performSelectorOnMainThread:@selector(setName:) withObject:[mgr displayNameAtPath:folder] waitUntilDone:NO];

	[pool release];
}

- (iMBLibraryNode *)parseDatabase
{
	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:[self databasePath] size:NSMakeSize(16,16)];
    return [self parseDatabaseInThread:[self databasePath] name:myMusicFolderName icon:icon];
}

@end
