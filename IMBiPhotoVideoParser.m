/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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

#import "IMBiPhotoVideoParser.h"
#import "IMBParserController.h"
#import "IMBMovieViewController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBObject.h"
#import "NSDictionary+iMedia.h"
#import "NSString+iMedia.h"
#import "NSURL+iMedia.h"
//#import "IMBIconCache.h"
//#import "NSWorkspace+iMedia.h"
//#import "NSFileManager+iMedia.h"
#import <Quartz/Quartz.h>
#import "IMBTimecodeTransformer.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBiPhotoVideoParser ()

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiPhotoVideoParser

@synthesize timecodeTransformer = _timecodeTransformer;

//----------------------------------------------------------------------------------------------------------------------


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeMovie];
	[pool drain];
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) objectCountFormatSingular
{
	return [IMBMovieViewController objectCountFormatSingular];
}


+ (NSString*) objectCountFormatPlural
{
	return [IMBMovieViewController objectCountFormatPlural];
}


//----------------------------------------------------------------------------------------------------------------------


- (void)dealloc
{
	IMBRelease(_timecodeTransformer);
	[super dealloc];
}

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.timecodeTransformer = [[[IMBTimecodeTransformer alloc] init] autorelease];
	}
	
	return self;
}

//----------------------------------------------------------------------------------------------------------------------


// This media type is specific to iPhoto and is not to be confused with kIMBMediaTypeImage...

- (NSString*) iPhotoMediaType
{
	return @"Movie";
}

//----------------------------------------------------------------------------------------------------------------------


- (Class) objectClass
{
	return [IMBObject class];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) requestedImageRepresentationType
{
	return IKImageBrowserQTMoviePathRepresentationType;
}


// Use the path of the hires file to get to the QTMovie...

- (NSString*) imageLocationForObject:(NSDictionary*)inObjectDict
{
	return [inObjectDict objectForKey:@"ImagePath"];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) loadMetadataForObject:(IMBObject*)inObject
{
	NSURL* videoURL = [inObject URL];
	
	if (videoURL == nil) {
		return;
	}
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:inObject.preliminaryMetadata];
	
	// Do not load (key) movie specific metadata for node objects
	// because it doesn't represent the nature of the object well enough.
	
	if (![inObject isKindOfClass:[IMBNodeObject class]])
	{
		[metadata addEntriesFromDictionary:[NSURL imb_metadataFromVideoAtURL:videoURL]];
	}
	
	NSString* description = [self metadataDescriptionForMetadata:metadata];
	
	if ([NSThread isMainThread])
	{
		inObject.metadata = metadata;
		inObject.metadataDescription = description;
	}
	else
	{
		NSArray* modes = [NSArray arrayWithObject:NSRunLoopCommonModes];
		[inObject performSelectorOnMainThread:@selector(setMetadata:) withObject:metadata waitUntilDone:NO modes:modes];
		[inObject performSelectorOnMainThread:@selector(setMetadataDescription:) withObject:description waitUntilDone:NO modes:modes];
	}
}

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	// Events have other metadata than images
	
	if ([inMetadata objectForKey:@"RollID"])		// Event
	{
		return [self eventMetadataDescriptionForMetadata:inMetadata];
	}
	
	// Movie
	return [NSDictionary imb_metadataDescriptionForMovieMetadata:inMetadata];
}

//----------------------------------------------------------------------------------------------------------------------


@end
