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


// Author: Pierre Bernard, Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroomParserMessenger.h"
#import "IMBLightroom1Parser.h"
#import "IMBLightroom2Parser.h"
#import "IMBLightroom3Parser.h"
#import "IMBLightroom4Parser.h"
#import "IMBLightroom3VideoParser.h"
#import "IMBLightroom4VideoParser.h"
#import "IMBParserController.h"
#import "NSFileManager+iMedia.h"
#import "NSDictionary+iMedia.h"
#import "NSImage+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableArray* sParsers = nil;
static dispatch_once_t sOnceToken = 0;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLightroomParserMessenger


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = nil;	// Will be discovered in XPC service
		self.mediaType = [[self class] mediaType];
		self.isUserAdded = NO;
	}
	
	return self;
}


- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Check if Lightroom is installed. Give preference to the newest version...

+ (NSString*) lightroomPath
{
	NSString* path = nil;
	
	if (path == nil) path = [IMBLightroom4Parser lightroomPath];
	if (path == nil) path = [IMBLightroom3Parser lightroomPath];
	if (path == nil) path = [IMBLightroom2Parser lightroomPath];
	if (path == nil) path = [IMBLightroom1Parser lightroomPath];
	
	return path;
}

+ (BOOL) isInstalled
{
	return [self lightroomPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the XPC service side. Create a IMBParser instance for each Lightroom library we discover...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
    dispatch_once(&sOnceToken,
    ^{
		if ([[self class] isInstalled])
		{
			NSString* mediaType = [self mediaType];
			sParsers = [[NSMutableArray alloc] init];
			
			if ([mediaType isEqualTo:kIMBMediaTypeImage])
			{
				[sParsers addObjectsFromArray:[IMBLightroom1Parser concreteParserInstancesForMediaType:mediaType]];
				[sParsers addObjectsFromArray:[IMBLightroom2Parser concreteParserInstancesForMediaType:mediaType]];
				[sParsers addObjectsFromArray:[IMBLightroom3Parser concreteParserInstancesForMediaType:mediaType]];
				[sParsers addObjectsFromArray:[IMBLightroom4Parser concreteParserInstancesForMediaType:mediaType]];
			}
			else if ([mediaType isEqualTo:kIMBMediaTypeMovie])
			{
				[sParsers addObjectsFromArray:[IMBLightroom3VideoParser concreteParserInstancesForMediaType:mediaType]];
				[sParsers addObjectsFromArray:[IMBLightroom4VideoParser concreteParserInstancesForMediaType:mediaType]];
			}
		}
	});

	return (NSArray*)sParsers;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	if ([self.mediaType isEqualToString:kIMBMediaTypeImage])
	{
		return [NSImage imb_imageMetadataDescriptionForMetadata:inMetadata];
	}
	else if ([self.mediaType isEqualToString:kIMBMediaTypeMovie])
	{
		return [NSDictionary imb_metadataDescriptionForMovieMetadata:inMetadata];
	}
	
	return nil;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for image subclass and register it...
 
@implementation IMBLightroomImageParserMessenger

+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}

+ (NSString*) parserClassName
{
	return @"IMBLightroomParser";
}
					
+ (NSString*) identifier
{
	return @"com.karelia.imedia.Lightroom";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for movie subclass and register it...
 
@implementation IMBLightroomsMovieParserMessenger

+ (NSString*) mediaType
{
	return kIMBMediaTypeMovie;
}

+ (NSString*) parserClassName
{
	return @"IMBLightroomVideoParser";
}
						
+ (NSString*) identifier
{
	return @"com.karelia.imedia.Lightroom";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

@end


//----------------------------------------------------------------------------------------------------------------------

