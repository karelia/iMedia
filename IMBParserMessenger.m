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

#import "IMBParserMessenger.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBNodeObject.h"
#import <XPCKit/XPCKit.h>
#import "SBUtilities.h"
#import "NSObject+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSBundle+iMedia.h"
#import "IMBAccessRightsController.h"


//----------------------------------------------------------------------------------------------------------------------


//@interface IMBParserMessenger ()
//- (void) _setParserIdentifier:(IMBParser*)inParser onNodeTree:(IMBNode*)inNode;
//- (void) _setObjectIdentifierWithParser:(IMBParser*)inParser onNodeTree:(IMBNode*)inNode;
//@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBParserMessenger

@synthesize mediaType = _mediaType;
@synthesize mediaSource = _mediaSource;
@synthesize isUserAdded = _isUserAdded;


//----------------------------------------------------------------------------------------------------------------------

// Use this switch in your subclass if you want to turn off XPC service usage for a particular service type
+ (BOOL) useXPCServiceWhenPresent
{
    return YES;
}

//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.mediaType = [[self class] mediaType];
		self.mediaSource = nil;
		self.isUserAdded = NO;	
	}
	
	return self;
}

- (void) dealloc
{
	IMBRelease(_mediaType);
	IMBRelease(_mediaSource);
	IMBRelease(_connection);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super init]))
	{
		self.mediaType = [inCoder decodeObjectForKey:@"mediaType"];
		self.mediaSource = [inCoder decodeObjectForKey:@"mediaSource"];
		self.isUserAdded = [inCoder decodeBoolForKey:@"isUserAdded"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.mediaType forKey:@"mediaType"];
	[inCoder encodeObject:self.mediaSource forKey:@"mediaSource"];
	[inCoder encodeBool:self.isUserAdded forKey:@"isUserAdded"];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBParserMessenger* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.mediaType = self.mediaType;
	copy.mediaSource = self.mediaSource;
	copy.isUserAdded = self.isUserAdded;
	
	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


// To be overridden in subclasses...

+ (NSString*) mediaType
{
	return nil;
}


// For instantiating IMBParsers...

+ (NSString*) parserClassName
{
	return nil;
}

						
// The identifier is used in delegate methods and for choosing the correct XPC service bundle...

+ (NSString*) identifier
{
	return nil;
}


+ (NSString*) xpcServiceIdentifierPrefix
{
	return @"im.edia.";
}


+ (NSString*) xpcServiceIdentifierPostfix
{
	return [[self identifier] pathExtension];
}


+ (NSString*) xpcServiceIdentifier
{
	return [[self xpcServiceIdentifierPrefix] stringByAppendingString:[self xpcServiceIdentifierPostfix]];
}


// Create the connection lazily when needed...

- (id) connection
{
    if (![[self class] useXPCServiceWhenPresent])
    {
        return nil;
    }
    NSString* identifier = [[self class] xpcServiceIdentifier];
    
	if (_connection == nil && [[NSBundle mainBundle] supportsXPCServiceWithIdentifier:identifier])
	{
		_connection = [[NSClassFromString(@"XPCConnection") alloc] initWithServiceName:identifier];
	}
	
	return _connection;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBParserMessenger (XPC)


// Returns the list of parsers this messenger instantiated. Array should be static. Must be subclassed.

+ (NSMutableArray *)parsers
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
    return nil;
}


// Helper method to resolve any attached bookmarks, thus giving the XPC service access to parts of the file system...

//- (void) _resolveAccessRightsBookmarks
//{
//	for (NSData* bookmark in self.accessRightBookmarks)
//	{
//		NSError* error = nil;
//		BOOL stale = NO;
//		
//		NSURL* url = [NSURL URLByResolvingBookmarkData:bookmark
//			options:0
//			relativeToURL:nil
//			bookmarkDataIsStale:&stale
//			error:&error];
//			
//		NSString* path = [url path];
//		
//		BOOL accessible = [[NSFileManager defaultManager]
//			imb_isPath:path
//			accessible:kIMBAccessRead|kIMBAccessWrite];
//	
//		NSLog(@"%s path %@ accessible %d",__FUNCTION__,path,accessible);
//	}
//}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the XPC service side. The default implementation just returns a single parser instance. 
// Subclasses like iPhoto, Aperture, or Lightroom may opt to return multiple instances (preconfigured with correct 
// mediaSource) if multiple libraries are detected...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
	IMBParser* parser = [self newParser];
	parser.identifier = [[self class] identifier];
	parser.mediaType = self.mediaType;
	parser.mediaSource = self.mediaSource;
	
	NSArray* parsers = [NSArray arrayWithObject:parser];
	[parser release];
	
	return parsers;
}


// Returns a particular parser with given identifier...

- (IMBParser*) parserWithIdentifier:(NSString*)inIdentifier
{
	NSError* error = nil;
	NSArray* parsers = [self parserInstancesWithError:&error];
	
	if (error == nil)
	{
		for (IMBParser* parser in parsers)
		{
			if ([parser.identifier isEqualToString:inIdentifier])
			{
				return parser;
			}
		}
	}
	
	return nil;
}


// Factory method for instantiating a parser...

- (IMBParser*) newParser
{
	Class parserClass = NSClassFromString([[self class] parserClassName]);
	return [[parserClass alloc] init];
}


//----------------------------------------------------------------------------------------------------------------------


// The following three methods are simply wrappers that access the appropriate IMBParser instances and then 
// simply call the same method on those instances. Please note that they do some additional work that is really 
// essential for the iMedia framework to work properly (IMBNode.parserIdentifier, IMBObject.parserIdentifier, 
// and IMBObject.identifier need to be set), so we'll do this here and do not rely on the parser developer 
// doing the right thing...

- (NSArray*) unpopulatedTopLevelNodes:(NSError**)outError
{
	NSError* error = nil;
	NSMutableArray* topLevelNodes = nil;
	NSArray* parsers = [self parserInstancesWithError:&error];
	
	if (error == nil)
	{
		topLevelNodes = [NSMutableArray arrayWithCapacity:parsers.count];
	
		for (IMBParser* parser in parsers)
		{
			if (error == nil)
			{
				IMBNode* node = [parser unpopulatedTopLevelNode:&error];
				
				if (node) 
				{
					[self _setParserIdentifierWithParser:parser onNodeTree:node];
					[topLevelNodes addObject:node];
				}
			}
		}
	}
	
	if (outError) *outError = error;
	return (NSArray*)topLevelNodes;
}


- (IMBNode*) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
    // Since inNode was most likely instantiated through -initWithCoder: (coming from the app)
    // its parser messenger is not set. Do it now.
    
    inNode.parserMessenger = self;
    
	NSError* error = nil;
	IMBParser* parser = [self parserWithIdentifier:inNode.parserIdentifier];
	BOOL success = [parser populateNode:inNode error:&error];
	
	IMBNode* node = success ? inNode : nil;
	
	if (node)
	{
		[self _setParserIdentifierWithParser:parser onNodeTree:node];
		[self _setObjectIdentifierWithParser:parser onNodeTree:node];
	}
	
	if ((node.accessibility == kIMBResourceIsAccessible) && success == NO && error == nil)
	{
		NSString* title = @"Programmer Error";
		
		NSString* description = [NSString stringWithFormat:
			@"%@ returned NO while trying to populate the node '%@' But it didn't return an error.\n\nThis is a programmer error that should be corrected.",
			NSStringFromClass([parser class]),
			inNode.name];
			
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
			title,@"title",
			description,NSLocalizedDescriptionKey,
			nil];
			
		error = [NSError errorWithDomain:kIMBErrorDomain code:kIMBErrorInvalidState userInfo:info];
	}
	
	if (outError) *outError = error;
	return node;
}


- (IMBNode*) reloadNodeTree:(IMBNode*)inNode error:(NSError**)outError
{
    // Since inNode was most likely instantiated through initWithCoder (coming from the app)
    // its parser messenger is not set. Do it now.
    
    inNode.parserMessenger = self;
    
	NSError* error = nil;
	IMBParser* parser = [self parserWithIdentifier:inNode.parserIdentifier];
	IMBNode* node = [parser reloadNodeTree:inNode error:&error];
	
	if (node)
	{
		[self _setParserIdentifierWithParser:parser onNodeTree:node];
		[self _setObjectIdentifierWithParser:parser onNodeTree:node];
	}
	
	if (outError) *outError = error;
	return node;
}


// Since it is absolutely essential that all IMBNodes and IMBObjects have their parserIdentifier set correctly,
// we'll use the following helper method to make sure of that and remove the burden from the parser developers.
// Simply call this method on any node that we get from a IMBParser instance...

- (void) _setParserIdentifierWithParser:(IMBParser*)inParser onNodeTree:(IMBNode*)inNode
{
	if (inNode)
	{
		NSString* identifier = inParser.identifier;
		
		inNode.parserIdentifier = identifier;
		
		for (IMBObject* object in inNode.objects)
		{
			object.parserIdentifier = identifier;
		}
		
		for (IMBNode* subnode in inNode.subnodes)
		{
			[self _setParserIdentifierWithParser:inParser onNodeTree:subnode];
		}
	}
}


// Having object.identifier is also essential, so we should rely on the parser developer to do this. We'll
// use the following helper method to make sure of that and remove the burden from the parser developers...

- (void) _setObjectIdentifierWithParser:(IMBParser*)inParser onNodeTree:(IMBNode*)inNode 
{
	if (inNode)
	{
		for (IMBObject* object in inNode.objects)
		{
			object.identifier = [inParser identifierForObject:object];
			object.persistentResourceIdentifier = [inParser persistentResourceIdentifierForObject:object];
		}
		
		for (IMBNode* subnode in inNode.subnodes)
		{
			[self _setObjectIdentifierWithParser:inParser onNodeTree:subnode];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This method is used to load thumbnail and metadata for a given IMBObject. No need to override this method,
// as the real work is done by two methods in IMBParser subclasses...


- (IMBObject*) loadThumbnailForObject:(IMBObject*)inObject error:(NSError**)outError
{
    inObject.parserMessenger = self;
    
	NSError* error = nil;
	IMBParser* parser = [self parserWithIdentifier:inObject.parserIdentifier];
	
	if (error == nil)
	{
		inObject.imageRepresentation = [parser thumbnailForObject:inObject error:&error];
	}

	if (outError) *outError = error;
	return (error == nil) ? inObject : nil;
}


- (IMBObject*) loadMetadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
    inObject.parserMessenger = self;
    
	NSError* error = nil;
	IMBParser* parser = [self parserWithIdentifier:inObject.parserIdentifier];
	
	if (error == nil)
	{
		inObject.metadata = [parser metadataForObject:inObject error:&error];
	}

	if (error == nil)
	{
        inObject.metadataDescription = [self metadataDescriptionForMetadata:inObject.metadata];
	}

	if (outError) *outError = error;
	return (error == nil) ? inObject : nil;
}


- (IMBObject*) loadThumbnailAndMetadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
    inObject.parserMessenger = self;
    
	NSError* error = nil;
	
	if (error == nil)
	{
		[self loadThumbnailForObject:inObject error:&error];
	}

	if (error == nil)
	{
		[self loadMetadataForObject:inObject error:&error];
	}

	if (outError) *outError = error;
	return (error == nil) ? inObject : nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
    inObject.parserMessenger = self;
    
	IMBParser* parser = [self parserWithIdentifier:inObject.parserIdentifier];
	return [parser bookmarkForObject:inObject error:outError];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSURL*) addAccessRightsBookmark:(NSData*)inBookmark error:(NSError**)outError
{
	NSURL* url = [[IMBAccessRightsController sharedAccessRightsController] addBookmark:inBookmark];
	if (outError) *outError = nil;
	return url;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBParserMessenger (App)


// These two methods can be overrridden by subclasses to add custom menu items...

- (void) willShowContextMenu:(NSMenu*)ioMenu forNode:(IMBNode*)inNode
{

}


- (void) willShowContextMenu:(NSMenu*)ioMenu forObject:(IMBObject*)inObject
{

}


//----------------------------------------------------------------------------------------------------------------------


// If a subclass wants custom UI for a specific node, then is should override one of the following methods...

- (NSViewController*) customHeaderViewControllerForNode:(IMBNode*)inNode
{
	return nil;
}


- (NSViewController*) customObjectViewControllerForNode:(IMBNode*)inNode
{
	return nil;
}


- (NSViewController*) customFooterViewControllerForNode:(IMBNode*)inNode
{
	return nil;
}


// Controls whether object views should be installed for a given node. Can be overridden by parser subclasses...

//- (BOOL) shouldDisplayObjectViewForNode:(IMBNode*)inNode
//{
//	return YES;
//}


//----------------------------------------------------------------------------------------------------------------------


// Override in subclass...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return @"";
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the URL that represents the root of this parser messenger's library.
// This is not necessarily identical to the mediaSource of a library.
// Its implementation defaults to inMediaSource but may be overriden for a more appropriate URL
// (e.g. parent directory of inMediaSource for Lightroom).
// NOTE: We cannot access the messenger's own mediaSource property here because it's not set in the app.

- (NSURL*) libraryRootURLForMediaSource:(NSURL*)inMediaSource
{
    return inMediaSource;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Pasteboard

- (void)didWriteObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pasteboard; { }


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers


//- (IMBNode*) nodeWithIdentifier:(NSString*)inIdentifier
//{
//	return [[IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType nodeWithIdentifier:inIdentifier];
//}


//----------------------------------------------------------------------------------------------------------------------


// Invalidate the thumbnails for all object in this node tree. That way thumbnails are forced to be re-generated...

//- (void) invalidateThumbnailsForNode:(IMBNode*)inNode
//{
//	for (IMBNode* node in inNode.subnodes)
//	{
//		[self invalidateThumbnailsForNode:node];
//	}
//	
//	for (IMBObject* object in inNode.objects)
//	{
//		object.needsImageRepresentation = YES;
//		object.imageVersion = object.imageVersion + 1;
//	}
//}
//
//
//- (void) invalidateThumbnails
//{
//	IMBLibraryController* controller = [IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType];
//	IMBNode* rootNode = [controller topLevelNodeForParser:self];
//	[self invalidateThumbnailsForNode:rootNode];
//}


//----------------------------------------------------------------------------------------------------------------------


@end

