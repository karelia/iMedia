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

#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


@class IMBNode;
@class IMBObject;
@class IMBObjectPromise;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBParserProtocol

@required

// This factory method creates parser instances. Usually just return a single instance, but subclasses may 
// opt to return more than one instance (e.g. Aperture may create one parser instance per library)...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType;

// The media source is usually a path pointing to the folder or database, but it could be an NSURL as well. 
// However, it is always stored as a string, so that putting it into property lists (prefs) is easier...

@property (retain) NSString* mediaSource;

// The mediaType can be @"image",@"audio",@"movie",etc. IMBCommon.h contains constants for the type...

@property (retain) NSString* mediaType;
@property (getter=isCustom) BOOL custom;

// ATTENTION: inOldNode is readonly and is only passed in for reference, but must not be modified by the parser in 
// a background operation. It is passed as an argument to the parser so that existing old nodes can be recreated
// as faithfully as possible. Must return an autoreleased object...

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError;
- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError;

// Returns a promise object that is appropriate for a given parser type. The default implemenation simply returns
// an IMBLocalObjectPromise. Parsers that require something else must override this method...

- (IMBObjectPromise*) objectPromiseWithObjects:(NSArray*)inObjects;

@optional

// Called in various situations just before a parser is going to be used. Can be used to prepare the instance 
// or update cached data...

- (void) willUseParser;

// Called after a node was deselected. The parser can release its cached data (if present)...

- (void) didStopUsingParser;

// Called when a file watcher fires and it concerns a parser. Also gives a parser a chance to update any cached data...

- (void) watchedPathDidChange:(NSString*)inWatchedPath;

// Called when the icon size in the object view has changed. Parsers may use this callback to change the thumbnails
// of the IMBObjects they create. At first they may want to supply small thumbnails so it's faster, but as a user
// zooms the icons, the parser may want to supply larger thumbnails...

- (void) objectViewDidChangeIconSize:(NSSize)inSize;

// Called when the user right-clicks on a node in the IMBOutlineView. Here the parser has a chance to add custom
// menu items of its own, that go beyond the functionality of the standard items added by the controllers...

- (void) willShowContextMenu:(NSMenu*)inMenu forNode:(IMBNode*)inNode;
- (void) willShowContextMenu:(NSMenu*)inMenu forObject:(IMBObject*)inObject;

// Called when metadata for an object needs to be loaded lazily. This method may be called on a background thread...

- (void) loadMetadataForObject:(IMBObject*)inObject;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBParser : NSObject <IMBParserProtocol>
{
	NSString* _mediaSource;
	NSString* _mediaType;
	BOOL _custom;

}

// Helper methods...

- (id) initWithMediaType:(NSString*)inMediaType;
- (NSString*) identifierForPath:(NSString*)inPath;
	
@end


//----------------------------------------------------------------------------------------------------------------------


