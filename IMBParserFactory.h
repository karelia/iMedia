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
@class XPCConnection;


//----------------------------------------------------------------------------------------------------------------------


// Lightweight class that uniquely identifies a parser. Instance of this class can be archived and sent over 
// an XPC connection to create an IMBParser instance on the other side (XPC service)...

@interface IMBParserFactory : NSObject 
{
	NSString* _identifier;
	NSString* _parserClassName;
	NSString* _mediaType;
	NSURL* _mediaSource;
	BOOL _isUserAdded;
	
	XPCConnection* _connection;
}

// Properties that uniquely define each factory...

@property (copy) NSString* identifier;			// Used internally
@property (copy) NSString* parserClassName;		// For instantiating parsers
@property (copy) NSString* mediaType;			// See IMBCommon.h for available types
@property (retain) NSURL* mediaSource;			// Source of given media objects
@property BOOL isUserAdded;						// User added items can also be removed by the user again

// For communicating with the XPC service...

@property (retain,readonly) XPCConnection* connection;	// Used internally...

// The host app side calls this method to get the top level nodes for this IMBParserFactory. Since this requires 
// a round trip to the XPC service, this is a purely asycnronous API with a completion block that receives the
// resulting array...

- (void) topLevelNodesWithCompletionBlock:(IMBCompletionBlock)inCompletionBlock;

// This factory method creates IMBParser instances. Usually just returns a single instance, but subclasses  
// may opt to return more than one instance (e.g. Aperture may create one instance per library). This method
// is only called on the XPC service side...

- (NSArray*) parserInstancesWithError:(NSError**)outError;

// Called when the user right-clicks in the iMedia UI. Here the IMBParserFactory has a chance to add custom   
// menu items of its own, that go beyond the functionality of the standard items added by the controllers.
// These methods are only called on the host app side...

- (void) willShowContextMenu:(NSMenu*)ioMenu forNode:(IMBNode*)inNode;
- (void) willShowContextMenu:(NSMenu*)ioMenu forObject:(IMBObject*)inObject;

// Nodes that do not want the standard object views can use custom user intefaces. The following methods   
// provide the mechanics of creating custom view controllers Subclasses should override them to return an   
// appropriate view controller. These methods are only called on the host app side...

- (NSViewController*) customHeaderViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) customObjectViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) customFooterViewControllerForNode:(IMBNode*)inNode;

//- (BOOL) shouldDisplayObjectViewForNode:(IMBNode*)inNode;	

// Helpers...

//- (IMBNode*) nodeWithIdentifier:(NSString*)inIdentifier;
//- (void) invalidateThumbnails;

@end


//----------------------------------------------------------------------------------------------------------------------

