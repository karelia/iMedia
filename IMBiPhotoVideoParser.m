/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBMovieObject.h"
#import "NSString+iMedia.h"
//#import "IMBIconCache.h"
//#import "NSWorkspace+iMedia.h"
//#import "NSFileManager+iMedia.h"
#import <Quartz/Quartz.h>
#import "IMBTimecodeTransformer.h"


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
	[pool release];
}

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
	return [IMBMovieObject class];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) requestedImageRepresentationType
{
	return IKImageBrowserQTMoviePathRepresentationType; //IKImageBrowserQTMovieRepresentationType;
}


// Use the path of the hires file to get to the QTMovie...

- (NSString*) imageLocationForObject:(NSDictionary*)inObjectDict
{
	return [inObjectDict objectForKey:@"ImagePath"];
}

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSString *comment = [inMetadata objectForKey:@"Comment"];
	if (comment) comment = [comment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *type = [inMetadata objectForKey:@"ImageType"];		// like MooV
	NSString *UTI = [NSString imb_UTIForFileType:type];
	NSString *kind = [NSString imb_descriptionForUTI:UTI];
	// NSString *dateTimeInterval = [inMetadata objectForKey:@"DateAsTimerInterval"];

	NSMutableString* description = [NSMutableString string];
	
	if (description.length > 0) [description imb_appendNewline];
	[description appendString:kind];
	
	NSString *width = [inMetadata objectForKey:@"width"];
	NSString *height = [inMetadata objectForKey:@"height"];
	NSString *duration = [inMetadata objectForKey:@"duration"];

	if (width != nil && height != nil)
	{		
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@×%@",width,height];
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

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	IMBEnhancedObject* object = (IMBEnhancedObject*)inObject;
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:object.preliminaryMetadata];
	[metadata setObject:inObject.location forKey:@"path"];

	MDItemRef item = MDItemCreate(NULL,(CFStringRef)inObject.location);
	
	if (item)
	{
		CFNumberRef seconds = MDItemCopyAttribute(item,kMDItemDurationSeconds);
		CFNumberRef width = MDItemCopyAttribute(item,kMDItemPixelWidth);
		CFNumberRef height = MDItemCopyAttribute(item,kMDItemPixelHeight);
		
		if (seconds)
		{
			[metadata setObject:(NSNumber*)seconds forKey:@"duration"]; 
			CFRelease(seconds);
		}
		
		if (width)
		{
			[metadata setObject:(NSNumber*)width forKey:@"width"]; 
			CFRelease(width);
		}
		
		if (height)
		{
			[metadata setObject:(NSNumber*)height forKey:@"height"]; 
			CFRelease(height);
		}
		
		CFRelease(item);
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



//----------------------------------------------------------------------------------------------------------------------


@end
