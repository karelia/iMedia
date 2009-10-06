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
#import "IMBCommon.h"
#import "IMBOperationQueue.h"

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


// Loading movies must be done on the main thread (as many components are not threadsafe). Alas, this blocks 
// the main runloop, but what are we to do...

- (void) loadMovieRepresentation:(NSDictionary*)inInfo
{
	NSURL* url = (NSURL*)[inInfo objectForKey:@"url"];
	IMBObject* object = (IMBObject*)[inInfo objectForKey:@"object"];

	QTMovie* movie = [self movieForURL:url];
	[object setImageRepresentation:movie];
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
//		// QuickLook file path or URL
//		NSURL *url = [imageRepresentation isKindOfClass:[NSURL class]]
//			? imageRepresentation
//			: [NSURL fileURLWithPath:imageRepresentation];
//		retainedCGImage = QLThumbnailImageCreate(kCFAllocatorDefault, (CFURLRef)url, 
//				CGSizeMake(MAX_THUMBNAIL_SIZE, MAX_THUMBNAIL_SIZE), NULL);
	}
	
	// URL...
	
	else if ([type isEqualToString:IKImageBrowserNSURLRepresentationType])
	{
		imageRepresentation = url;	
	}
	
	// NSImage...
	
	else if ([type isEqualToString:IKImageBrowserNSImageRepresentationType])
	{
		imageRepresentation = [[[NSImage alloc] initByReferencingURL:url] autorelease];
	}
	
	// CGImage...
	
	else if ([type isEqualToString:IKImageBrowserCGImageRepresentationType])
	{
		CGImageRef image = [self imageForURL:url];
		imageRepresentation = (id)image;
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
		CGImageRef image = [self imageForURL:url];
		NSBitmapImageRep* bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
		imageRepresentation = bitmap;
	}
	
	// QTMovie...
	
	else if ([type isEqualToString:IKImageBrowserQTMovieRepresentationType])
	{
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:url,@"url",object,@"object",nil];

		[self	performSelectorOnMainThread:@selector(loadMovieRepresentation:) 
				withObject:info 
				waitUntilDone:NO 
				modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

//		QTMovie* movie = [self movieForURL:url];
//		imageRepresentation = movie;
	}
//	else if ([type isEqualToString:IKImageBrowserIconRefRepresentationType])
//	{
//		IconRef icon 
//		// IconRef
//		image = [[[NSImage alloc] initWithIconRef:(IconRef)imageRepresentation] autorelease];
//	}
//	else if ([type isEqualToString:IKImageBrowserQuickLookPathRepresentationType])
//	{
//		// QuickLook file path or URL
//		NSURL *url = [imageRepresentation isKindOfClass:[NSURL class]]
//			? imageRepresentation
//			: [NSURL fileURLWithPath:imageRepresentation];
//		retainedCGImage = QLThumbnailImageCreate(kCFAllocatorDefault, (CFURLRef)url, 
//				CGSizeMake(MAX_THUMBNAIL_SIZE, MAX_THUMBNAIL_SIZE), NULL);
//	}
	/* These are the types that we DON'T SUPPORT at this time:
	 IKImageBrowserQCCompositionRepresentationType
	 IKImageBrowserQCCompositionPathRepresentationType
	 */
	
//	if (retainedSource)		// did the above get us a CGImageSource? If so we'll create the NSImage now.
//	{
//		NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
//								   (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
//								   (id)kCFBooleanFalse, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
//								   (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageAlways,	// bug in rotation so let's use the full size always
//								   [NSNumber numberWithInteger:MAX_THUMBNAIL_SIZE], (id)kCGImageSourceThumbnailMaxPixelSize, 
//								   nil];
//		
//		retainedCGImage = CGImageSourceCreateThumbnailAtIndex(retainedSource, 0, (CFDictionaryRef)thumbOpts);
//		CFRelease(retainedSource);
//	}
	
//	// Now if we have a CGImageRef, make the NSImage from that.
//	
//	if (retainedCGImage)
//	{
//		NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:retainedCGImage] autorelease];
//        image = [[[NSImage alloc] initWithSize:[bitmap size]] autorelease];
//        [image addRepresentation:bitmap];
//		
//		CGImageRelease(retainedCGImage);
//	}
//	
//#ifdef DEBUG
////	sleep(3);		// load slowly so we can test properties
//#endif
//	// At this point, we should have an NSImage that we are ready to go set as the thumbnail.
//	// (Do we want to do something about versions the way IKImageBrowser View works?)
//	
//	if (image != nil)
//	{
//		// We synchronize access to the image/imageLoading pair of variables
//		@synchronized (object)
//		{
//			object.isLoading = NO;
//			object.thumbnail = image;	// this will set off KVO on IMBObjectPropertyNamedThumbnailImage
//			//NSLog(@"Finished loading %@", visualObject);
//		}
//	}
	
	// Return the result to the main thread...
	
	if (imageRepresentation)
	{
		[object	performSelectorOnMainThread:@selector(setImageRepresentation:) 
				withObject:imageRepresentation 
				waitUntilDone:NO 
				modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	
	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


@end
