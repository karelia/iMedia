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

#import "IMBMovieFolderParser.h"
#import "IMBParserController.h"
#import "IMBTimecodeTransformer.h"
#import "IMBMovieObject.h"
#import "IMBCommon.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBMovieFolderParser

@synthesize timecodeTransformer = _timecodeTransformer;


//----------------------------------------------------------------------------------------------------------------------


// Restrict this parser to image files...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.fileUTI = (NSString*)kUTTypeMovie; 
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


- (IMBObject*) objectForPath:(NSString*)inPath name:(NSString*)inName index:(NSUInteger)inIndex
{
	IMBObject* object = [[[IMBMovieObject alloc] init] autorelease];
	object.location = (id)inPath;
	object.name = inName;
	object.parser = self;
	object.index = inIndex;
	
	object.imageRepresentationType = IKImageBrowserQTMovieRepresentationType; 
	object.imageLocation = inPath;
	object.imageRepresentation = nil;		// will be loaded lazily when needed
	object.metadata = nil;					// will be loaded lazily when needed
	
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


// Return metadata specific to movie files...

- (NSDictionary*) metadataForFileAtPath:(NSString*)inPath
{
	NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
	MDItemRef item = MDItemCreate(NULL,(CFStringRef)inPath);
	
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
	else
	{
//		NSLog(@"Nil from MDItemCreate for %@ exists?%d", inPath, [[NSFileManager defaultManager] fileExistsAtPath:inPath]);
	}
	
	return metadata;
}


// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSString* description = @"";
	NSNumber* duration = [inMetadata objectForKey:@"duration"];
	NSNumber* width = [inMetadata objectForKey:@"width"];
	NSNumber* height = [inMetadata objectForKey:@"height"];
	
	if (width != nil && height != nil)
	{
		NSString* size = NSLocalizedStringWithDefaultValue(
				@"Size",
				nil,IMBBundle(),
				@"Size",
				@"Size label in metadata description");
		
		description = [description stringByAppendingFormat:@"%@: %@x%@\n",size,width,height];
	}
	
	if (duration)
	{
		NSString* durationLabel = NSLocalizedStringWithDefaultValue(
			@"Time",
			nil,IMBBundle(),
			@"Time",
			@"Time label in metadataDescription");

		NSString* durationString = [_timecodeTransformer transformedValue:duration];
		description = [description stringByAppendingFormat:@"%@: %@\n",durationLabel,durationString];
	}
	
	return description;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBMoviesFolderParser


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeMovie];
	[pool release];
}


// Set the folder path to the ~/Pictures...

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.mediaSource = [NSHomeDirectory() stringByAppendingPathComponent:@"Movies"];
	}
	
	return self;
}


@end


//----------------------------------------------------------------------------------------------------------------------
