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

#import "IMBParserFactory.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import <XPCKit/XPCKit.h>
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBParserFactory

@synthesize mediaType = _mediaType;
@synthesize mediaSource = _mediaSource;
@synthesize isUserAdded = _isUserAdded;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


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
	IMBParserFactory* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.mediaType = self.mediaType;
	copy.mediaSource = self.mediaSource;
	copy.isUserAdded = self.isUserAdded;
	
	return copy;
}


- (void) dealloc
{
	IMBRelease(_mediaType);
	IMBRelease(_mediaSource);
	IMBRelease(_connection);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// To be overridden in subclasses...

+ (NSString*) mediaType
{
	return nil;
}


// For instantiating IMBParsers...

+ (Class) parserClass
{
	return nil;
}

						
// The identifier is used in delegate methods and for choosing the correct XPC service bundle...

+ (NSString*) identifier
{
	return nil;
}


// Create the connection lazily when needed...

- (XPCConnection*) connection
{
	if (_connection == nil && SBIsSandboxed())
	{
		NSString* identifier = [[self class] identifier];
		_connection = [[XPCConnection alloc] initWithServiceName:identifier];
	}
	
	return _connection;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Parser Work


// This method is called on the XPC service side. The default implementation just returns a single parser instance. 
// Subclasses like iPhoto, Aperture, or Lightroom may opt to return multiple instances (preconfigured with correct 
// mediaSource) if multiple libraries are detected...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
	Class parserClass = [[self class] parserClass];
	
	IMBParser* parser = [[parserClass alloc] init];
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


//----------------------------------------------------------------------------------------------------------------------


- (NSArray*) unpopulatedTopLevelNodesWithError:(NSError**)outError
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
				IMBNode* node = [parser unpopulatedTopLevelNodeWithError:&error];
				[topLevelNodes addObject:node];
			}
		}
	}
	
	if (outError) *outError = error;
	return (NSArray*)topLevelNodes;
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBNode*) reloadNode:(IMBNode*)inNode error:(NSError**)outError
{
	IMBParser* parser = [self parserWithIdentifier:inNode.parserIdentifier];
	IMBNode* newNode = [parser reloadNode:inNode error:outError];
	return newNode;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Custom UI


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

