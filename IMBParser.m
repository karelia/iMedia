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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBParser.h"
#import "NSWorkspace+iMedia.h"
#import "IMBNode.h"
//#import "IMBObject.h"
//#import "IMBObjectsPromise.h"
//#import "IMBLibraryController.h"
//#import "NSString+iMedia.h"
//#import "NSData+SKExtensions.h"
//#import <Quartz/Quartz.h>
//#import <QTKit/QTKit.h>
//#import "NSURL+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBParser ()

//+ (CGImageSourceRef) _imageSourceForURL:(NSURL*)inURL;
//+ (CGImageRef) _imageForURL:(NSURL*)inURL;

- (NSArray*) _identifiersOfPopulatedSubnodesOfNode:(IMBNode*)inNode;
- (void) _identifiersOfPopulatedSubnodesOfNode:(IMBNode*)inNode identifiers:(NSMutableArray*)inIdentifiers;
- (void) _populateNodeTree:(IMBNode*)inNode populatedNodeIdentifiers:(NSArray*)inPopulatedNodeIdentifiers error:(NSError**)outError;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBParser

@synthesize identifier = _identifier;
@synthesize mediaType = _mediaType;
@synthesize mediaSource = _mediaSource;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (id) init
{
	if (self = [super init])
	{
		self.identifier = nil;
		self.mediaType = nil;
		self.mediaSource = nil;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_identifier);
	IMBRelease(_mediaSource);
	IMBRelease(_mediaType);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Node Creation


// To be overridden by subclasses...

- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	return nil;
}


- (void) populateNode:(IMBNode*)inNode error:(NSError**)outError
{

}


//----------------------------------------------------------------------------------------------------------------------


// This generic implementation may be sufficient for most subclasses. First remember how deeply the node  
// tree was populated. Then recreate this node. Finally repopulate the node tree to the same depth...

- (IMBNode*) reloadNodeTree:(IMBNode*)inNode error:(NSError**)outError
{
	NSError* error = nil;
	IMBNode* newNode = nil;
	NSArray* identifiers = [self _identifiersOfPopulatedSubnodesOfNode:inNode];

	if (inNode.isTopLevelNode)
	{
		newNode = [self unpopulatedTopLevelNode:&error];
	}
	else
	{
		newNode = inNode;
	}
	
	if (newNode)
	{
		[self _populateNodeTree:newNode populatedNodeIdentifiers:identifiers error:&error];
	}
	
	if (outError) *outError = error;
	return newNode;
}


// Gather the identifiers of all populated subnodes...

- (NSArray*) _identifiersOfPopulatedSubnodesOfNode:(IMBNode*)inNode
{
	NSMutableArray* identifiers = [NSMutableArray array];
	[self _identifiersOfPopulatedSubnodesOfNode:inNode identifiers:identifiers];
	return (NSArray*)identifiers;
}

- (void) _identifiersOfPopulatedSubnodesOfNode:(IMBNode*)inNode identifiers:(NSMutableArray*)inIdentifiers
{
	if (inNode.isPopulated)
	{
		[inIdentifiers addObject:inNode.identifier];
		
		for (IMBNode* subnode in inNode.subnodes)
		{
			[self _identifiersOfPopulatedSubnodesOfNode:subnode identifiers:inIdentifiers];
		}
	}
}


// 
- (void) _populateNodeTree:(IMBNode*)inNode populatedNodeIdentifiers:(NSArray*)inPopulatedNodeIdentifiers error:(NSError**)outError
{
	NSError* error = nil;

	if ([inPopulatedNodeIdentifiers indexOfObject:inNode.identifier] != NSNotFound)
	{
		[inNode unpopulate];
		[self populateNode:inNode error:&error];
		
		if (error == nil)
		{
			for (IMBNode* subnode in inNode.subnodes)
			{
				[self _populateNodeTree:subnode populatedNodeIdentifiers:inPopulatedNodeIdentifiers error:&error];
				if (error) break;
			}
		}
	}
	
	if (outError) *outError = error;
}


//----------------------------------------------------------------------------------------------------------------------


// Optional methods that do nothing in the base class and can be overridden in subclasses, e.g. to   
// updateor get rid of cached data...

/*
- (void) willStartUsingParser
{

}


- (void) didStopUsingParser
{

}
*/

//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Object Access


// To be overridden by subclasses...

- (id) thumbnailForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// To be overridden by subclasses...

- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// To be overridden by subclasses...

- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------

/*
+ (id) loadThumbnailForObject:(IMBObject*)ioObject
{
	id imageRepresentation = nil;
	NSString* type = ioObject.imageRepresentationType;
	NSString* path = nil;
	NSURL* url = nil;
	
	// Get path/url location of our object...
	
	id location = ioObject.imageLocation;
	if (location == nil) location = ioObject.location;

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
		if (!ioObject.imageRepresentation)
		{
			NSLog(@"##### %p Warning; IKImageBrowserNSImageRepresentationType with a nil imageRepresentation",ioObject);
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
		[ioObject 
			performSelectorOnMainThread:@selector(setImageRepresentation:) 
			withObject:imageRepresentation 
			waitUntilDone:NO 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	
	return imageRepresentation;
}
*/

//----------------------------------------------------------------------------------------------------------------------


// This helper method makes sure that the new node tree is pre-populated as deep as the old one was. Obviously
// this is a recursive method that descends into the tree as far as necessary to recreate the state...

//- (void) populateNewNode:(IMBNode*)inNewNode likeOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions
//{
//	NSError* error = nil;
//	
//	if (inOldNode.isPopulated)
//	{
//		[self populateNode:inNewNode options:inOptions error:&error];
//		
//		for (IMBNode* oldSubnode in inOldNode.subnodes)
//		{
//			NSString* identifier = oldSubnode.identifier;
//			IMBNode* newSubnode = [inNewNode subnodeWithIdentifier:identifier];
//			[self populateNewNode:newSubnode likeOldNode:oldSubnode options:inOptions];
//		}
//	}
//}


//----------------------------------------------------------------------------------------------------------------------


// Returns an autoreleased source for the given url...
/*
+ (CGImageSourceRef) _imageSourceForURL:(NSURL*)inURL
{
	CGImageSourceRef source = NULL;
	
	if (inURL)
	{
		NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:nil];
		source = CGImageSourceCreateWithURL((CFURLRef)inURL,(CFDictionaryRef)options);
		[NSMakeCollectable(source) autorelease];
	}
	
	return source;
}
*/
	
// Returns an autoreleased image for the given url...
/*
+ (CGImageRef) _imageForURL:(NSURL*)inURL
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
			
			image = CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
			[NSMakeCollectable(image) autorelease];
		}
	}
	
	return image;
}	
*/

//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers


// This helper method can be used by subclasses to construct identifiers of form "classname://path/to/node"...
 
- (NSString*) identifierForPath:(NSString*)inPath
{
	NSString* parserClassName = NSStringFromClass([self class]);
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,inPath];
}


//----------------------------------------------------------------------------------------------------------------------


// This method makes sure that we have an image with a bitmap representation that can be archived...

- (NSImage*) iconForPath:(NSString*)inPath
{
	NSWorkspace* workspace = [NSWorkspace imb_threadSafeWorkspace];

	NSImage* image = [workspace iconForFile:inPath];
	[image setSize:NSMakeSize(16,16)];
	NSData* tiff = [image TIFFRepresentation];
//	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:tiff];
	
	NSImage* icon = [[[NSImage alloc] initWithData:tiff] autorelease];
	[icon setSize:NSMakeSize(16,16)];
	return icon;
}


//----------------------------------------------------------------------------------------------------------------------


@end


