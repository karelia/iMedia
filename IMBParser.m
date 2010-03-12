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

#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBMovieObject.h"
#import "IMBObjectPromise.h"
#import "IMBLibraryController.h"
#import "NSString+iMedia.h"
#import "NSData+SKExtensions.h"
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import <QuickLook/QuickLook.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBParser ()

- (CGImageSourceRef) _imageSourceForURL:(NSURL*)inURL;
- (CGImageRef) _imageForURL:(NSURL*)inURL;
- (CGImageRef) _quicklookCGImageForURL:(NSURL*)inURL;
- (NSImage*) _quicklookNSImageForURL:(NSURL*)inURL;
- (void) _loadMovieRepresentation:(NSDictionary*)inInfo;
- (QTMovie*) _movieForURL:(NSURL*)inURL;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBParser

@synthesize mediaSource = _mediaSource;
@synthesize mediaType = _mediaType;
@synthesize custom = _custom;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// The default implementation just returns a single parser instance. Subclasses like iPhoto, Aperture, or Lightroom
// may opt to return multiple instances (preconfigured with correct mediaSource) if multiple libraries are detected...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	IMBParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
	NSArray* parserInstances = [NSArray arrayWithObject:parser];
	[parser release];
	return parserInstances;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super init])
	{
		self.mediaSource = nil;
		self.mediaType = inMediaType;
		self.custom = NO;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_mediaSource);
	IMBRelease(_mediaType);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// The following two methods must be overridden by subclasses...

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	return nil;
}

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	return NO;
}

//----------------------------------------------------------------------------------------------------------------------


// Optional methods that do nothing in the base class and can be overridden in subclasses, e.g. to update  
// or get rid of cached data...

- (void) willUseParser
{

}

- (void) didStopUsingParser
{

}

- (void) watchedPathDidChange:(NSString*)inWatchedPath
{

}


//----------------------------------------------------------------------------------------------------------------------


// This helper method can be used by subclasses to construct identifiers of form "classname://path/to/node"...
 
- (NSString*) identifierForPath:(NSString*)inPath
{
	NSString* parserClassName = NSStringFromClass([self class]);
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,inPath];
}


//----------------------------------------------------------------------------------------------------------------------


// This method can be overridden by subclasses if the default promise is not useful...

- (IMBObjectPromise*) objectPromiseWithObjects:(NSArray*)inObjects
{
	return [[(IMBObjectPromise*)[IMBLocalObjectPromise alloc] initWithObjects:inObjects] autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) loadThumbnailForObject:(IMBObject*)inObject
{
	id imageRepresentation = nil;
	NSString* type = inObject.imageRepresentationType;
	NSString* path = nil;
	NSURL* url = nil;
	
	// Get path/url location of our object...
	
	id location = inObject.imageLocation;
	if (location == nil) location = inObject.location;

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
			imageRepresentation = [self _quicklookNSImageForURL:url];
		}	
	}
	
	// CGImage...
	
	else if ([type isEqualToString:IKImageBrowserCGImageRepresentationType])
	{
		if (UTTypeConformsTo((CFStringRef)uti,kUTTypeImage))
		{
			imageRepresentation = (id)[self _imageForURL:url];
		}
		else
		{
			imageRepresentation = (id)[self _quicklookCGImageForURL:url];
		}
	}
	
	// CGImageSourceRef...
	
	else if ([type isEqualToString:IKImageBrowserCGImageSourceRepresentationType])
	{
		CGImageSourceRef source = [self _imageSourceForURL:url];
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
			CGImageRef image = [self _imageForURL:url];
			imageRepresentation = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
		}
		else
		{
			CGImageRef image = [self _quicklookCGImageForURL:url];
			imageRepresentation = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
		}
	}
	
	// QTMovie...
	
	else if ([type isEqualToString:IKImageBrowserQTMovieRepresentationType])
	{
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:url,@"url",inObject,@"object",nil];

		[self	performSelectorOnMainThread:@selector(_loadMovieRepresentation:) 
				withObject:info 
				waitUntilDone:NO 
				modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}

	// Return the result to the main thread...
	
	if (imageRepresentation)
	{
		[inObject 
			performSelectorOnMainThread:@selector(setImageRepresentation:) 
			withObject:imageRepresentation 
			waitUntilDone:NO 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) loadMetadataForObject:(IMBObject*)inObject
{
	// to be overridden by subclasses. This method may be called on a background thread, so subclasses need to
	// take appropriate safety measures...
}


//----------------------------------------------------------------------------------------------------------------------


// Invalidate the thumbnails for all object in this node tree. That way thumbnails are forced to be re-generated...

- (void) invalidateThumbnailsForNode:(IMBNode*)inNode
{
	for (IMBNode* node in inNode.subNodes)
	{
		[self invalidateThumbnailsForNode:node];
	}
	
	for (IMBObject* object in inNode.objects)
	{
		object.needsImageRepresentation = YES;
		object.imageVersion = object.imageVersion + 1;
	}
}


- (void) invalidateThumbnails
{
	IMBLibraryController* controller = [IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType];
	IMBNode* rootNode = [controller rootNodeForParser:self];
	[self invalidateThumbnailsForNode:rootNode];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers


// Returns an autoreleased source for the given url...

- (CGImageSourceRef) _imageSourceForURL:(NSURL*)inURL
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

- (CGImageRef) _imageForURL:(NSURL*)inURL
{
	CGImageRef image = NULL;
	
	if (inURL)
	{
		CGImageSourceRef source = [self _imageSourceForURL:inURL];

		NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
		   (id)kCFBooleanTrue,(id)kCGImageSourceCreateThumbnailWithTransform,
		   (id)kCFBooleanFalse,(id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
		   (id)kCFBooleanTrue,(id)kCGImageSourceCreateThumbnailFromImageAlways,	// bug in rotation so let's use the full size always
		   [NSNumber numberWithInteger:kIMBMaxThumbnailSize],(id)kCGImageSourceThumbnailMaxPixelSize, 
		   nil];
		
		image = CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
		[NSMakeCollectable(image) autorelease];
	}
	
	return image;
}	


//----------------------------------------------------------------------------------------------------------------------


// Quicklook methods to create images from non-image files...

- (CGImageRef) _quicklookCGImageForURL:(NSURL*)inURL
{
	CGSize size = CGSizeMake(128,128);
	CGImageRef image = QLThumbnailImageCreate(kCFAllocatorDefault,(CFURLRef)inURL,size,NULL);
	return (CGImageRef) [NSMakeCollectable(image) autorelease];
}


- (NSImage*) _quicklookNSImageForURL:(NSURL*)inURL
{
	NSImage* nsimage = nil;
	CGImageRef cgimage = [self _quicklookCGImageForURL:inURL];

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

- (void) _loadMovieRepresentation:(NSDictionary*)inInfo
{
	// Load the QTMovie object...
	
	NSURL* url = (NSURL*)[inInfo objectForKey:@"url"];
	IMBObject* object = (IMBObject*)[inInfo objectForKey:@"object"];

	QTMovie* movie = [self _movieForURL:url];
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


// Returns an autoreleased movie for the given url...

- (QTMovie*) _movieForURL:(NSURL*)inURL
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


@end
