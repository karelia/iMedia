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

#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBNode;
@class IMBObject;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBParserProtocol

// Together these parameters uniquely specify a parser instance. The values are taken from IMBParserFacrtory...

@required

@property (copy) NSString* identifier;	
@property (copy) NSString* mediaType;	
@property (retain) NSURL* mediaSource;	

// The following four methods are at the heart of parser classes and must be implemented. They will be called on
// on the XPC service side: Together they create the iMedia data model tree, which gets serialized and sent back
// to the host app, where it is given to and owned by the IMBLibraryController. The first method is only called
// once at startup to create an empty toplevel node, while the remaining 3 methods may be called multiple times...

@required

- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError;
- (void) populateSubnodesOfNode:(IMBNode*)inNode error:(NSError**)outError;
- (void) populateObjectsOfNode:(IMBNode*)inNode error:(NSError**)outError;
- (void) reloadNode:(IMBNode*)inNode error:(NSError**)outError;

// The following three methods are used to load thumbnails or metadata, or create a security-scoped bookmark for  
// full media file access. They are called on the XPC service side...

@required

- (NSData*) thumbnailForObject:(IMBObject*)inObject error:(NSError**)outError;
- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError;
- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError;

// These two optional methods are called on the XPC service side just before a parser starts its work (the four 
// methods above), or after it stops its work (e.g. by the user deselecting a node). The parser can read in or
// discard cached data as appropriate...

@optional

//- (void) willStartUsingParser;
//- (void) didStopUsingParser;


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBParser : NSObject <IMBParserProtocol>
{
	@private
	
	NSString* _identifier;
	NSString* _mediaType;
	NSURL* _mediaSource;
}

// Helpers for subclasses...

- (NSString*) identifierForPath:(NSString*)inPath;

//- (void) populateNewNode:(IMBNode*)inNewNode likeOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions;


@end


//----------------------------------------------------------------------------------------------------------------------


