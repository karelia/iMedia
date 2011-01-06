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

#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBMovieObject.h"
#import "IMBObjectsPromise.h"
#import "IMBLibraryController.h"
#import "NSString+iMedia.h"
#import "NSData+SKExtensions.h"
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import "NSURL+iMedia.h"

//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBParser ()

- (CGImageSourceRef) _imageSourceForURL:(NSURL*)inURL;
- (CGImageRef) _imageForURL:(NSURL*)inURL;

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

- (BOOL)canBeUsed;
{
	return YES;
}


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


+ (NSString*) identifierForPath:(NSString*)inPath
{
	NSString* parserClassName = NSStringFromClass(self);
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,inPath];

}


//----------------------------------------------------------------------------------------------------------------------


// This method can be overridden by subclasses if the default promise is not useful...

- (IMBObjectsPromise*) objectPromiseWithObjects:(NSArray*)inObjects
{
	return [IMBObjectsPromise promiseWithLocalIMBObjects:inObjects];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (id) loadThumbnailForObject:(IMBObject*)inObject
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
	
	NSString* uti = [NSString imb_UTIForFileAtPath:path];
	
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
		// If this is the type, we should already have an image representation, so let's try NOT 
		// doing this code that was here before.
		// So just leave the imageRepresentation here nil so it doesn't get set.
		if (!inObject.imageRepresentation)
		{
			NSLog(@"##### %p Warning; IKImageBrowserNSImageRepresentationType with a nil imageRepresentation", inObject);
		}
		
//		if (UTTypeConformsTo((CFStringRef)uti,kUTTypeImage))
//		{
//			imageRepresentation = [[[NSImage alloc] initByReferencingURL:url] autorelease];
//		}
//		else
//		{
//			imageRepresentation = [url imb_quicklookNSImage];
//		}	
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
			imageRepresentation = (id)[url imb_quicklookCGImage];
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
			CGImageRef image = [url imb_quicklookCGImage];
			imageRepresentation = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
		}
	}
	
	// QTMovie...
	
	else if ([type isEqualToString:IKImageBrowserQTMovieRepresentationType])
	{
		NSLog(@"loadThumbnailForObject: what do to with IKImageBrowserQTMovieRepresentationType");
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
	
	return imageRepresentation;
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


// This helper method makes sure that the new node tree is pre-populated as deep as the old one was. Obviously
// this is a recursive method that descends into the tree as far as necessary to recreate the state...

- (void) populateNewNode:(IMBNode*)inNewNode likeOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions
{
	NSError* error = nil;
	
	if (inOldNode.isPopulated)
	{
		[self populateNode:inNewNode options:inOptions error:&error];
		
		for (IMBNode* oldSubNode in inOldNode.subNodes)
		{
			NSString* identifier = oldSubNode.identifier;
			IMBNode* newSubNode = [inNewNode subNodeWithIdentifier:identifier];
			[self populateNewNode:newSubNode likeOldNode:oldSubNode options:inOptions];
		}
	}
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

		NSAssert(inURL, @"Nil image source URL");
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

		if (source)
		{
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
			   (id)kCFBooleanTrue,(id)kCGImageSourceCreateThumbnailWithTransform,
			   (id)kCFBooleanFalse,(id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
			   (id)kCFBooleanTrue,(id)kCGImageSourceCreateThumbnailFromImageAlways,	// bug in rotation so let's use the full size always
			   [NSNumber numberWithInteger:kIMBMaxThumbnailSize],(id)kCGImageSourceThumbnailMaxPixelSize, 
			   nil];
			
			NSAssert(source, @"Nil image source in _imageForURL:");
			image = CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
			[NSMakeCollectable(image) autorelease];
		}
	}
	
	return image;
}	


//----------------------------------------------------------------------------------------------------------------------




//----------------------------------------------------------------------------------------------------------------------


@end
