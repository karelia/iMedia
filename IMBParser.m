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

#import "IMBParser.h"
#import "NSWorkspace+iMedia.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSObject+iMedia.h"
#import "NSURL+iMedia.h"
#import "IMBParserMessenger.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBParser ()

- (NSArray*) _identifiersOfPopulatedSubnodesOfNode:(IMBNode*)inNode;
- (void) _identifiersOfPopulatedSubnodesOfNode:(IMBNode*)inNode identifiers:(NSMutableArray*)inIdentifiers;
- (BOOL) _populateNodeTree:(IMBNode*)inNode populatedNodeIdentifiers:(NSArray*)inPopulatedNodeIdentifiers error:(NSError**)outError;

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
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	if (outError) *outError = nil;
	return nil;
}


// To be overridden by subclasses...

- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	if (outError) *outError = nil; // never reached due to the exception, mind!
	return YES;
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
- (BOOL) _populateNodeTree:(IMBNode*)inNode populatedNodeIdentifiers:(NSArray*)inPopulatedNodeIdentifiers error:(NSError**)outError
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
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Object Access


// To be overridden by subclasses...

- (id) thumbnailForObject:(IMBObject*)inObject error:(NSError**)outError
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	if (outError) *outError = nil;
	return nil;
}


// To be overridden by subclasses...

- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	if (outError) *outError = nil;
	return nil;
}


// To be overridden by subclasses...

- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	if (outError) *outError = nil;
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Identifiers


// This helper method can be used by subclasses to construct identifiers of form "classname://path/to/node"...
 
- (NSString*) identifierForPath:(NSString*)inPath
{
	NSString* prefix = [self iMedia2PersistentResourceIdentifierPrefix];
	return [NSString stringWithFormat:@"%@:/%@",prefix,inPath];
}


//----------------------------------------------------------------------------------------------------------------------


// This identifier string for IMBObject (just like IMBNode.identifier) can be used to uniquely identify an IMBObject
// throughout a session. If you need a persistent identifier that identifies the resource associated with an IMBObject
// use persistentResourceIdentifierForObject: instead.

- (NSString*) identifierForObject:(IMBObject*)inObject
{
	NSString* parserClassName = NSStringFromClass([self class]);
    NSUInteger libraryHash = [[[self mediaSource] path] hash];
	NSString* path = [inObject.location path];
	NSString* identifier = [NSString stringWithFormat:@"%@:%d/%@",parserClassName,libraryHash,path];
	return identifier;
}


// Returns an identifier for the resource that self denotes and that is meant to be persistent across launches of the app
// (e.g. when host app developers need to persist usage info of media files when implementing the badging delegate API).
// This standard implementation is based on file reference URLs - so it will only work for file based URLs that denote
// existing files.
// Subclass to adjust to the needs of your parser.

- (NSString*) persistentResourceIdentifierForObject:(IMBObject*)inObject
{
    NSURL *fileReferenceURL = [[inObject URL] fileReferenceURL];
    if (fileReferenceURL)
    {
        return [fileReferenceURL absoluteString];
    } else {
        NSLog(@"Could not create persistent resource identifier for %@: resource %@ is not a file or does not exist",
              inObject, [inObject URL]);
        return nil;
    }
}


// Returns the form of the persistent resource identifier for inObject that was used in iMedia2 (which has some
// shortcomings). You can use this string to compare against your app's stored identifiers and convert them to
// their new identifiers (persistentResourceIdentifierForObject:).
// NOTE: This method should only be invoked for such purpose. It might be removed from the framework
//       in future versions.

- (NSString*) iMedia2PersistentResourceIdentifierForObject:(IMBObject*)inObject
{
	NSString* prefix = [self iMedia2PersistentResourceIdentifierPrefix];
	NSString* path = [inObject.location path];
	NSString* identifier = [NSString stringWithFormat:@"%@/%@",prefix,path];
	return identifier;
}


// This method should be overridden by subclasses to return an appropriate prefix for IMBObject identifiers. Refer
// to the method iMedia2PersistentResourceIdentifierForObject: to see how it is used. Historically we used class names
// as the prefix. However, during the evolution of iMedia class names can change and identifier string would thus
// also change. Being non-persistent this is undesirable, as thing that depend of the immutability of identifier strings
// would break. One such example is object badges, which use such identifiers. To gain backward compatibilty, a parser 
// class can override this method to return a prefix that matches the historic class name used in iMedia2

- (NSString*) iMedia2PersistentResourceIdentifierPrefix
{
	return NSStringFromClass([self class]);
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers


// This method makes sure that we have an image with a bitmap representation that can be archived...

- (NSImage*) iconForItemAtURL:(NSURL*)url error:(NSError **)error;
{
    NSImage *result;
    if (![url getResourceValue:&result forKey:NSURLEffectiveIconKey error:error]) return nil;
    NSAssert(url != nil, @"Getting NSURLEffectiveIconKey suceeded, but with a nil image, which isn't documented");
    
    result = [result copy]; // since we're about to mutate
	[result setSize:NSMakeSize(16,16)];
	return [result autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


// Creates a thumbnail for local image files. Either location or imageLocation of inObject must contain a fileURL. 
// If imageLocation is set then the corresponding image is returned. Otherwise a downscaled image based on location 
// is returned...

- (CGImageRef) thumbnailFromLocalImageFileForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
	NSURL* url = nil;
	CGImageSourceRef source = NULL;
	CGImageRef thumbnail = NULL;
	BOOL shouldScaleDown = NO;
	
	// Choose the most appropriate file url and whether we should scale down to generate a thumbnail...
	
	if (error == nil)
	{
		if (inObject.imageLocation)
		{
			url = inObject.imageLocation;
			shouldScaleDown = NO;
		}
		else
		{
			url = inObject.URL;
			shouldScaleDown = YES;
		}
	}
	
	// Create an image source...
	
	if (error == nil)
	{
		source = CGImageSourceCreateWithURL((CFURLRef)url,NULL);
		
		if (source == nil)
		{
			NSString* description = [NSString stringWithFormat:@"Could find image file at %@",url];
			NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
			error = [NSError errorWithDomain:kIMBErrorDomain code:fnfErr userInfo:info];
		}
	}

	// Render the thumbnail...
	
	if (error == nil)
	{
		if (shouldScaleDown)
		{
            NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
				(id)kCFBooleanTrue,kCGImageSourceCreateThumbnailFromImageIfAbsent,
				(id)[NSNumber numberWithInteger:256],kCGImageSourceThumbnailMaxPixelSize,
				(id)kCFBooleanTrue,kCGImageSourceCreateThumbnailWithTransform,
				nil];
            
            thumbnail = CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)options);
		}
		else
		{
            thumbnail = CGImageSourceCreateImageAtIndex(source,0,NULL);
		}
		
		if (thumbnail == nil)
		{
			NSString* description = [NSString stringWithFormat:@"Could not create image from URL: %@",url];
			NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
			error = [NSError errorWithDomain:kIMBErrorDomain code:0 userInfo:info];
		}
	}
	
	// Cleanup...
	
	if (source) CFRelease(source);

	[NSMakeCollectable(thumbnail) autorelease];
	if (outError) *outError = error;
	return thumbnail;
}


//----------------------------------------------------------------------------------------------------------------------


// This generic method uses Quicklook to generate a thumbnail image. If can be used for any file...

- (CGImageRef) thumbnailFromQuicklookForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
	NSURL* url = inObject.URL;
	CGImageRef thumbnail = [url imb_quicklookCGImage];
	if (outError) *outError = error;
	return thumbnail;
}


//----------------------------------------------------------------------------------------------------------------------


// This is a generic implementation for creating a security scoped bookmark of local media files. It assumes  
// that the url to the local file is stored in inObject.location. May be overridden by subclasses...

- (NSData*) bookmarkForLocalFileObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
//	NSURL* baseURL = nil; //inObject.bookmarkBaseURL;
	NSURL* fileURL = inObject.URL;
	NSData* bookmark = nil;
	
	if ([fileURL isFileURL])
	{
	/*
		NSURLBookmarkCreationOptions options = 
			NSURLBookmarkCreationMinimalBookmark |
//			NSURLBookmarkCreationWithSecurityScope |
//			NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess |
			NSURLBookmarkCreationPreferFileIDResolution;
	*/		
		bookmark = [fileURL 
			bookmarkDataWithOptions:0 //options
			includingResourceValuesForKeys:nil
			relativeToURL:nil
			error:&error];
	}
	else
	{
        NSString* description = [NSString stringWithFormat:@"Could not create bookmark for non file URL: %@",fileURL];
        NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
        error = [NSError errorWithDomain:kIMBErrorDomain code:paramErr userInfo:info];
	}
	
	if (outError) *outError = error;
	return bookmark;
}


//----------------------------------------------------------------------------------------------------------------------


@end


