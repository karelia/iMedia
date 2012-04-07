/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBAudioFolderParserMessenger.h"
#import "IMBParserController.h"
#import "IMBTimecodeTransformer.h"
#import "NSWorkspace+iMedia.h"
#import "NSString+iMedia.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBAudioFolderParserMessenger

+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}


+ (NSString*) parserClassName
{
	return @"IMBAudioFolderParser";
}
					

- (id) init
{
	if ((self = [super init]))
	{
		self.fileUTI = (NSString*)kUTTypeAudio;		// Restrict this parser to audio files...
		self.mediaType = [[self class] mediaType];
		_timecodeTransformer = [[IMBTimecodeTransformer alloc] init];
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]))
	{
		_timecodeTransformer = [[IMBTimecodeTransformer alloc] init];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_timecodeTransformer);
	[super dealloc];
}


- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* description = [NSMutableString string];
	NSNumber* duration = [inMetadata objectForKey:@"duration"];
	NSString* artist = [inMetadata objectForKey:@"artist"];
	NSString* album = [inMetadata objectForKey:@"album"];
	NSString* comment = [inMetadata objectForKey:@"comment"];
	if (comment) comment = [comment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if (artist)
	{
		NSString* artistLabel = NSLocalizedStringWithDefaultValue(
			@"Artist",
			nil,IMBBundle(),
			@"Artist",
			@"Artist label in metadataDescription");

		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",artistLabel,artist];
	}
	
	if (album)
	{
		NSString* albumLabel = NSLocalizedStringWithDefaultValue(
			@"Album",
			nil,IMBBundle(),
			@"Album",
			@"Album label in metadataDescription");

		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",albumLabel,album];
	}
	
	if (duration)
	{
		NSString* durationLabel = NSLocalizedStringWithDefaultValue(
			@"Time",
			nil,IMBBundle(),
			@"Time",
			@"Time label in metadataDescription");

		NSString* durationString = [_timecodeTransformer transformedValue:duration];
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",durationLabel,durationString];
	}

	if (comment && ![comment isEqualToString:@""])
	{
		NSString* commentLabel = NSLocalizedStringWithDefaultValue(
			@"Comment",
			nil,IMBBundle(),
			@"Comment",
			@"Comment label in metadataDescription");
		
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",commentLabel,comment];
	}
	
	return description;
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBMusicFolderParserMessenger

+ (NSString*) identifier
{
	return @"com.karelia.imedia.folder.Music";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

- (id) init
{
	if ((self = [super init]))
	{
		NSString* path = [SBHomeDirectory() stringByAppendingPathComponent:@"Music"];
		self.mediaSource = [NSURL fileURLWithPath:path];
		self.displayPriority = 1;
	}
	return self;
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiLifeSoundEffectsFolderParserMessenger

+ (NSString*) identifier
{
	return @"com.karelia.imedia.folder.iLifeSoundEffects";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = [NSURL fileURLWithPath:@"/Library/Audio/Apple Loops/Apple/iLife Sound Effects"];
	}
	
	return self;
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBAppleLoopsForGarageBandFolderParserMessenger

+ (NSString*) identifier
{
	return @"com.karelia.imedia.folder.AppleLoopsForGarageBand";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = [NSURL fileURLWithPath:@"/Library/Audio/Apple Loops/Apple/Apple Loops for GarageBand"];
	}
	
	return self;
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiMovieSoundEffectsFolderParserMessenger

+ (NSString*) identifier
{
	return @"com.karelia.imedia.folder.iMovieSoundEffects";
}

+ (id) folderPath
{
	NSString* path = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iMovie"];
	return [path stringByAppendingPathComponent:@"/Contents/Resources/Sound Effects"];
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	if ([self folderPath]) [IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = [NSURL fileURLWithPath:[[self class] folderPath]];
	}
	
	return self;
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLibrarySoundsFolderParserMessenger

+ (NSString*) identifier
{
	return @"com.karelia.imedia.folder.LibrarySounds";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

- (id) init
{
	if ((self = [super init]))
	{
		NSString* path = [SBHomeDirectory() stringByAppendingPathComponent:@"Library/Sounds"];
		self.mediaSource = [NSURL fileURLWithPath:path];
	}
	
	return self;
}

@end


//----------------------------------------------------------------------------------------------------------------------
