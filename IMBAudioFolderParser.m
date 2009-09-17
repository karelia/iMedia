/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBAudioFolderParser.h"
#import "IMBParserController.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBAudioFolderParser


// Restrict this parser to image files...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.fileUTI = (NSString*)kUTTypeAudio; 
	}
	
	return self;
}


// Return metadata specific to audio files...

- (NSDictionary*) metadataForFileAtPath:(NSString*)inPath
{
	NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
	MDItemRef item = MDItemCreate(NULL,(CFStringRef)inPath); 
	
	if (item)
	{
		CFNumberRef seconds = MDItemCopyAttribute(item,kMDItemDurationSeconds);
		CFArrayRef authors = MDItemCopyAttribute(item,kMDItemAuthors);
		CFStringRef album = MDItemCopyAttribute(item,kMDItemAlbum);

		if (seconds)
		{
			[metadata setObject:(NSNumber*)seconds forKey:@"duration"]; 
			CFRelease(seconds);
		}
		
		if (authors)
		{
			NSArray* artists = (NSArray*)authors;
			if (artists.count > 0)[metadata setObject:[artists objectAtIndex:0] forKey:@"artist"]; 
			CFRelease(authors);
		}
		
		if (album)
		{
			[metadata setObject:(NSString*)album forKey:@"album"]; 
			CFRelease(album);
		}
		
		CFRelease(item);
	}
	else
	{
//		NSLog(@"Nil from MDItemCreate for %@ exists?%d", inPath, [[NSFileManager defaultManager] fileExistsAtPath:inPath]);
	}
	
	return metadata;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBMusicFolderParser


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeAudio];
	[pool release];
}


// Set the folder path to ~/Music...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.mediaSource = [NSHomeDirectory() stringByAppendingPathComponent:@"Music"];
	}
	
	return self;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiLifeSoundEffectsFolderParser


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeAudio];
	[pool release];
}


// Set the folder path to /Library/Audio/Apple Loops/Apple/iLife Sound Effects...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.mediaSource = @"/Library/Audio/Apple Loops/Apple/iLife Sound Effects";
	}
	
	return self;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiMovieSoundEffectsFolderParser


+ (id) folderPath
{
	NSString* path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iMovie"];
	return [path stringByAppendingPathComponent:@"/Contents/Resources/Sound Effects"];
}


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	if ([self folderPath]) [IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeAudio];
	[pool release];
}


// Set the folder path to iMovie.app/Contents/Resources/Sound Effects...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.mediaSource = [[self class] folderPath];
	}
	
	return self;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLibrarySoundsFolderParser


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeAudio];
	[pool release];
}


// Set the folder path to ~/Library/Sounds...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.mediaSource = [@"~/Library/Sounds" stringByStandardizingPath];
	}
	
	return self;
}


@end


//----------------------------------------------------------------------------------------------------------------------
