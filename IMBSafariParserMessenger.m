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

#import "IMBSafariParserMessenger.h"
#import "IMBSafariParser.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableArray* sParsers = nil;
static dispatch_once_t sOnceToken = 0;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBSafariParserMessenger


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}


+ (NSString*) mediaType
{
	return kIMBMediaTypeLink;
}


+ (NSString*) parserClassName
{
	return @"IMBSafariParser";
}
	
									
+ (NSString*) identifier
{
	return @"com.karelia.imedia.Safari";
}


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


// Check if Safari is installed...

+ (NSString*) safariPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Safari"];
}


+ (BOOL) isInstalled
{
	return [self safariPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the XPC service side. Discover the path to the Bookmarks.plist file and create  
// an IMBParser instance preconfigured with that path...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
    dispatch_once(&sOnceToken,
    ^{
		NSString* bookmarkFilePath = [SBHomeDirectory() stringByAppendingPathComponent:@"Library/Safari/Bookmarks.plist"];
		BOOL bookmarkFileExists = [[NSFileManager imb_threadSafeManager] fileExistsAtPath:bookmarkFilePath];
		
		if ([[self class] isInstalled] && bookmarkFileExists)
		{
			sParsers = [[NSMutableArray alloc] initWithCapacity:1];

			IMBSafariParser* parser = (IMBSafariParser*)[self newParser];
			parser.identifier = [[self class] identifier];
			parser.mediaType = self.mediaType;
			parser.mediaSource = [NSURL fileURLWithPath:bookmarkFilePath];
			parser.appPath = [[self class] safariPath];
			[sParsers addObject:parser];
			[parser release];
		}
	});

	return (NSArray*)sParsers;
}


//----------------------------------------------------------------------------------------------------------------------


// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* description = [NSMutableString string];
//	NSNumber* duration = [inMetadata objectForKey:@"duration"];
//	NSString* artist = [inMetadata objectForKey:@"artist"];
//	NSString* album = [inMetadata objectForKey:@"album"];
//	
//	if (artist)
//	{
//		NSString* artistLabel = NSLocalizedStringWithDefaultValue(
//			@"Artist",
//			nil,IMBBundle(),
//			@"Artist",
//			@"Artist label in metadataDescription");
//
//		if (description.length > 0) [description imb_appendNewline];
//		[description appendFormat:@"%@: %@",artistLabel,artist];
//	}
//	
//	if (album)
//	{
//		NSString* albumLabel = NSLocalizedStringWithDefaultValue(
//			@"Album",
//			nil,IMBBundle(),
//			@"Album",
//			@"Album label in metadataDescription");
//
//		if (description.length > 0) [description imb_appendNewline];
//		[description appendFormat:@"%@: %@",albumLabel,album];
//	}
//	
//	if (duration)
//	{
//		NSString* durationLabel = NSLocalizedStringWithDefaultValue(
//			@"Time",
//			nil,IMBBundle(),
//			@"Time",
//			@"Time label in metadataDescription");
//
//		NSString* durationString = [_timecodeTransformer transformedValue:duration];
//		if (description.length > 0) [description imb_appendNewline];
//		[description appendFormat:@"%@: %@",durationLabel,durationString];
//	}
	
	return description;
}


//----------------------------------------------------------------------------------------------------------------------


@end
