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

#import "IMBObjectThumbnailLoadOperation.h"
#import "IMBObject.h"
#import "IMBParser.h"
#import "IMBMovieObject.h"
#import "IMBCommon.h"
#import "IMBOperationQueue.h"
#import "NSString+iMedia.h"

#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import <QuickLook/QuickLook.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

#define MAX_THUMBNAIL_SIZE 128


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectThumbnailLoadOperation

@synthesize object = _object;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithObject:(IMBObject*)inObject
{
	if (self = [super init])
	{
		self.object = inObject;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_object);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Returns an autoreleased source for the given url...

- (CGImageSourceRef) imageSourceForURL:(NSURL*)inURL
{
	CGImageSourceRef source = NULL;
	
	if (inURL)
	{
		NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
		   nil];

		source = CGImageSourceCreateWithURL((CFURLRef)inURL,(CFDictionaryRef)options);
		[NSMakeCollectable(source) autorelease];
	}
	
	return source;
}

	
// Returns an autoreleased image for the given url...

- (CGImageRef) imageForURL:(NSURL*)inURL
{
	CGImageRef image = NULL;
	
	if (inURL)
	{
		CGImageSourceRef source = [self imageSourceForURL:inURL];

		NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
		   (id)kCFBooleanTrue,(id)kCGImageSourceCreateThumbnailWithTransform,
		   (id)kCFBooleanFalse,(id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
		   (id)kCFBooleanTrue,(id)kCGImageSourceCreateThumbnailFromImageAlways,	// bug in rotation so let's use the full size always
		   [NSNumber numberWithInteger:MAX_THUMBNAIL_SIZE],(id)kCGImageSourceThumbnailMaxPixelSize, 
		   nil];
		
		image = CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
		[NSMakeCollectable(image) autorelease];
	}
	
	return image;
}	


// Returns an autoreleased movie for the given url...
// TODO: this will be a bit tricky; we need to use that helper process.

- (QTMovie*) movieForURL:(NSURL*)inURL
{
	QTMovie* movie = NULL;
	
	if (inURL)
	{
		NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		   inURL,QTMovieURLAttribute,
		   [NSNumber numberWithBool:YES],QTMovieOpenAsyncOKAttribute,
//		   [NSNumber numberWithBool:YES],@"QTMovieOpenForPlaybackAttribute", // constant is not available with 10.5.sdk!
		   nil];

		NSError* error = nil;   
		movie = [QTMovie movieWithAttributes:attributes error:&error];
	}

	return movie;
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook methods to create images from non-image files...

- (CGImageRef) quicklookCGImageForURL:(NSURL*)inURL
{
	CGSize size = CGSizeMake(128,128);
	CGImageRef image = QLThumbnailImageCreate(kCFAllocatorDefault,(CFURLRef)inURL,size,NULL);
	return (CGImageRef) [NSMakeCollectable(image) autorelease];
}


- (NSImage*) quicklookNSImageForURL:(NSURL*)inURL
{
	NSImage* nsimage = nil;
	CGImageRef cgimage = [self quicklookCGImageForURL:inURL];

	if (cgimage)
	{
		NSSize size = NSZeroSize;
		size.width = CGImageGetWidth(cgimage);
		size.height = CGImageGetWidth(cgimage);

		nsimage = [[[NSImage alloc] initWithSize:size] autorelease];

		NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:cgimage];
		[nsimage addRepresentation:rep];		
		[rep release];
	}
	
	return nsimage;
}


//----------------------------------------------------------------------------------------------------------------------


// Loading movies must be done on the main thread (as many components are not threadsafe). Alas, this blocks 
// the main runloop, but what are we to do...

- (void) loadMovieRepresentation:(NSDictionary*)inInfo
{
	// Load the QTMovie object...
	
	NSURL* url = (NSURL*)[inInfo objectForKey:@"url"];
	IMBObject* object = (IMBObject*)[inInfo objectForKey:@"object"];

	QTMovie* movie = [self movieForURL:url];
	[object setImageRepresentation:movie];
	
	// Set a better poster time...
	
	QTTime d = movie.duration;
	double duration = (double)d.timeValue / (double)d.timeScale;
	double posterTime = 0.5 * duration;
	[movie setAttribute:[NSNumber numberWithDouble:posterTime] forKey:QTMoviePosterTimeAttribute];
	
	// Load and cache the poster frame...
	
	if ([object isKindOfClass:[IMBMovieObject class]])
	{
		NSError* error = nil;
		NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:QTMovieFrameImageTypeCGImageRef,QTMovieFrameImageType,nil];
		QTTime t = QTMakeTimeWithTimeInterval(posterTime);
		CGImageRef image = (CGImageRef) [movie frameImageAtTime:t withAttributes:attributes error:&error];
		[(IMBMovieObject*)object setPosterFrame:image];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) main
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	IMBObject* object = self.object;
	id imageRepresentation = nil;
	NSString* type = object.imageRepresentationType;
	NSString* path = nil;
	NSURL* url = nil;
	
	// Get path/url location of our object...
	
	id location = object.imageLocation;
	if (location == nil) location = object.location;

	if ([location isKindOfClass:[NSString class]])
	{
		path = (NSString*)location;
		url = [NSURL fileURLWithPath:path];
	}	
	else if ([location isKindOfClass:[NSURL class]])
	{
		url = (NSURL*)location;
		path = [url path];
	}
	
	// Get the uti for out object...
	
	NSString* uti = [NSString UTIForFileAtPath:path];
	
	// Path...
	
	if ([type isEqualToString:IKImageBrowserPathRepresentationType])
	{
		imageRepresentation = path;	
	}
	else if ([type isEqualToString:IKImageBrowserQTMoviePathRepresentationType])
	{
		imageRepresentation = path;	
	}
	else if ([type isEqualToString:IKImageBrowserIconRefPathRepresentationType])
	{
		imageRepresentation = path;	
	}
	else if ([type isEqualToString:IKImageBrowserQuickLookPathRepresentationType])
	{
		imageRepresentation = path;	
	}
	
	// URL...
	
	else if ([type isEqualToString:IKImageBrowserNSURLRepresentationType])
	{
		imageRepresentation = url;	
	}
	
	// NSImage...
	
	else if ([type isEqualToString:IKImageBrowserNSImageRepresentationType])
	{
		if (UTTypeConformsTo((CFStringRef)uti,kUTTypeImage))
		{
			imageRepresentation = [[[NSImage alloc] initByReferencingURL:url] autorelease];
		}
		else
		{
			imageRepresentation = [self quicklookNSImageForURL:url];
		}	
	}
	
	// CGImage...
	
	else if ([type isEqualToString:IKImageBrowserCGImageRepresentationType])
	{
		if (UTTypeConformsTo((CFStringRef)uti,kUTTypeImage))
		{
			imageRepresentation = (id)[self imageForURL:url];
		}
		else
		{
			imageRepresentation = (id)[self quicklookCGImageForURL:url];
		}
	}
	
	// CGImageSourceRef...
	
	else if ([type isEqualToString:IKImageBrowserCGImageSourceRepresentationType])
	{
		CGImageSourceRef source = [self imageSourceForURL:url];
		imageRepresentation = (id)source;
	}
	
	// NSData...
	
	else if ([type isEqualToString:IKImageBrowserNSDataRepresentationType])
	{
		NSData* data = [NSData dataWithContentsOfURL:url];
		imageRepresentation = data;
	}
	
	// NSBitmapImageRep...
	
	else if ([type isEqualToString:IKImageBrowserNSBitmapImageRepresentationType])
	{
		if (UTTypeConformsTo((CFStringRef)uti,kUTTypeImage))
		{
			CGImageRef image = [self imageForURL:url];
			imageRepresentation = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
		}
		else
		{
			CGImageRef image = [self quicklookCGImageForURL:url];
			imageRepresentation = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
		}
	}
	
	// QTMovie...
	
	else if ([type isEqualToString:IKImageBrowserQTMovieRepresentationType])
	{
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:url,@"url",object,@"object",nil];

		[self	performSelectorOnMainThread:@selector(loadMovieRepresentation:) 
				withObject:info 
				waitUntilDone:NO 
				modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}

	// Return the result to the main thread...
	
	if (imageRepresentation)
	{
		[object	performSelectorOnMainThread:@selector(setImageRepresentation:) 
				withObject:imageRepresentation 
				waitUntilDone:NO 
				modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	
	// Load metadata if is hasn't been loaded yet...
	
	if (object.metadata == nil)
	{
//		[object.parser	performSelectorOnMainThread:@selector(loadMetadataForObject:) 
//				withObject:object 
//				waitUntilDone:NO 
//				modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

		[object.parser loadMetadataForObject:object];
	}

	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


@end
