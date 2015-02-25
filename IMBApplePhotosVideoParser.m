/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2015 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2015 by Karelia Software et al.
 
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


// Author: Jörg Jacobsen, Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBApplePhotosVideoParser.h"

#import "NSDictionary+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSWorkspace+iMedia.h"

#import "IMBParserController.h"
#import "IMBObject.h"
#import "IMBNodeObject.h"


@interface IMBApplePhotosVideoParser ()

@end


@implementation IMBApplePhotosVideoParser


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeMovie];
	[pool drain];
}

/**
 Internal media type is specific to Apple Media Library based parsers and is not to be confused with kIMBMediaTypeImage and its siblings.
 */
+ (MLMediaType)internalMediaType
{
	return MLMediaTypeMovie;
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


// Loaded lazily when actually needed for display. Here we combine the metadata we got from the iPhoto XML file
// (which was available immediately, but not enough information) with more information that we obtain via ImageIO.
// This takes a little longer, but since it only done laziy for those object that are actually visible it's fine.
// Please note that this method may be called on a background thread...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	NSURL* videoURL = [inObject URL];

	if (videoURL == nil) {
		return;
	}

	// Map metadata information from Photos library representation (MLMediaObject.attributes) to iMedia representation
	NSDictionary *preliminaryMetadata = [inObject preliminaryMetadata];
	NSMutableDictionary* metadata = [NSMutableDictionary dictionary];

	for (NSString *key in [preliminaryMetadata allKeys]) {
		id value = [preliminaryMetadata objectForKey:key];

		if ([value isKindOfClass:[NSURL class]]) {
			// Can't have NSURL in plist for drag-and-drop
			NSURL *url = value;

			if ([url isFileURL]) {
				value = [url path];
			}
			else {
				value = [url absoluteString];
			}
		}

		[metadata setObject:value forKey:key];
	}


	[metadata setValue:[metadata objectForKey:@"URL"] forKey:@"ImagePath"];
	[metadata setValue:[metadata objectForKey:@"thumbnailURL"] forKey:@"ThumbPath"];
	[metadata setValue:[metadata objectForKey:@"originalURL"] forKey:@"OriginalPath"];

	[metadata removeObjectForKey:@"URL"];
	[metadata removeObjectForKey:@"thumbnailURL"];
	[metadata removeObjectForKey:@"originalURL"];


	[metadata setValue:[preliminaryMetadata objectForKey:@"Duration"] forKey:@"duration"];
	[metadata setValue:[preliminaryMetadata objectForKey:@"name"] forKey:@"Caption"];
	[metadata setValue:[preliminaryMetadata objectForKey:@"ILMediaObjectKeywordsAttribute"] forKey:@"iMediaKeywords"];

	// Width, height

	NSString *resolutionString = [preliminaryMetadata objectForKey:@"resolutionString"];

	if ([resolutionString isKindOfClass:[NSString class]]) {
		NSSize size = NSSizeFromString(resolutionString);

		[metadata setObject:[NSNumber numberWithInteger:(NSInteger)size.width] forKey:@"width"];
		[metadata setObject:[NSNumber numberWithInteger:(NSInteger)size.height] forKey:@"height"];
	}

	// Creation date and time

	id dateAsTimerInterval = [preliminaryMetadata objectForKey:@"DateAsTimerInterval"];

	if (dateAsTimerInterval != nil) {
		NSTimeInterval timeInterval = [dateAsTimerInterval doubleValue];
		NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval];

//		if (timeInterval > 0) {
//			date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval];
//		}
//		else {
//			date = [preliminaryMetadata objectForKey:@"modificationDate"];
//		}

		if (date != nil) {
			NSDateFormatter *exifDateFormatter = [[NSDateFormatter alloc] init];

			[exifDateFormatter setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];

			NSString *dateTime = [exifDateFormatter stringFromDate:date];

			[metadata setValue:dateTime forKey:@"dateTime"];
		}
	}

	// Do not load (key) image specific metadata for node objects
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



// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return [NSDictionary imb_metadataDescriptionForMovieMetadata:inMetadata];
}


//----------------------------------------------------------------------------------------------------------------------

@end
