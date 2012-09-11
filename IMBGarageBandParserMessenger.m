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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBGarageBandParserMessenger.h"
#import "IMBGarageBandParser.h"
#import "IMBParserController.h"
#import "IMBTimecodeTransformer.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBConfig.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static dispatch_once_t sOnceToken = 0;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBGarageBandParserMessenger

@synthesize timecodeTransformer = _timecodeTransformer;


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}


+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}


+ (NSString*) parserClassName
{
	return @"IMBGarageBandParser";
}
	
									
//----------------------------------------------------------------------------------------------------------------------
// Returns the list of parsers this messenger instantiated

+ (NSMutableArray *)parsers
{
    static NSMutableArray *parsers = nil;
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        parsers = [[NSMutableArray alloc] init];
    });
    return parsers;
}


+ (NSString*) identifier
{
	return @"com.karelia.imedia.GarageBand";
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = nil;	// Will be discovered in XPC service
		self.mediaType = [[self class] mediaType];
		self.isUserAdded = NO;
		self.timecodeTransformer = [[[IMBTimecodeTransformer alloc] init] autorelease];
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]))
	{
		self.timecodeTransformer = [[[IMBTimecodeTransformer alloc] init] autorelease];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_timecodeTransformer);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Check if GarageBand is installed...

+ (NSString*) garageBandPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.GarageBand"];
}


+ (BOOL) isInstalled
{
	return [self garageBandPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the XPC service side. Discover the path to the AlbumData.xml file and create  
// an IMBParser instance preconfigured with that path...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
    Class messengerClass = [self class];
    NSMutableArray *parsers = [messengerClass parsers];

    dispatch_once(&sOnceToken,
    ^{
		if ([[self class] isInstalled])
		{
			IMBGarageBandParser* parser = (IMBGarageBandParser*)[self newParser];
			parser.identifier = [[self class] identifier];
			parser.mediaType = self.mediaType;
			parser.mediaSource = nil;
			parser.appPath = [[self class] garageBandPath];
			[parsers addObject:parser];
			[parser release];
		}
	});

    // Every parser must have its current parser messenger set
    
    [self setParserMessengerForParsers];
    
	return (NSArray*)parsers;
}


//----------------------------------------------------------------------------------------------------------------------


// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* description = [NSMutableString string];
	NSNumber* duration = [inMetadata objectForKey:@"duration"];
	NSString* artist = [inMetadata objectForKey:@"artist"];
	NSString* album = [inMetadata objectForKey:@"album"];
	
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
	
	return description;
}


//----------------------------------------------------------------------------------------------------------------------


@end
