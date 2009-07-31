/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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


#pragma mark ABSTRACT

// There is one instance of this controller per media type. So this is essentially a per-media-type singleton.
// The library controller is responsible for maintaining a list of IMBNode trees. It is the owner of these nodes.
// Other controllers (IMBNodeTreeController and IMBObjectArrayController) can bind to the nodes property of this
// controller. 

// When user events (expanding or selection nodes), file system events (kqueue or FSEvent), or other external event 
// occur, the tree of nodes usually needs to be updated or rebuilt. The only correct way of doing this is using the 
// methods in this controller. Use reloadNode:, expandNode:, or selectNode: to update a node (or node tree) in a 
// background operation...


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

extern NSString* kIMBNodesWillChangeNotification;
extern NSString* kIMBNodesDidChangeNotification;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;
@class IMBNode;
@class IMBKQueue;
@class IMBFSEventsWatcher;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


@interface IMBLibraryController : NSObject
{
	NSString* _mediaType;
	NSMutableArray* _nodes;
	IMBOptions _options;
	id _delegate;

	BOOL _isReplacingNode;
	IMBKQueue* _watcherKQueue;
	IMBFSEventsWatcher* _watcherFSEvents;
}

// Create singleton instance of the controller. Don't forget to set the delegate early in the app lifetime...

+ (IMBLibraryController*) sharedLibraryControllerWithMediaType:(NSString*)inMediaType;
- (id) initWithMediaType:(NSString*)inMediaType;

// Accessors...

@property (retain) NSString* mediaType;
@property (assign) IMBOptions options;
@property (assign) id delegate;
@property (retain) IMBKQueue* watcherKQueue;
@property (retain) IMBFSEventsWatcher* watcherFSEvents;
@property (readonly) BOOL isReplacingNode;

// Node accessors (must only be called on the main thread)...

@property (retain) NSMutableArray* nodes;
- (IMBNode*) nodeForParser:(IMBParser*)inParser;
- (IMBNode*) nodeWithIdentifier:(NSString*)inIdentifier;

// Loading...

- (void) reload;

- (void) reloadNode:(IMBNode*)inNode;
- (void) expandNode:(IMBNode*)inNode;
- (void) selectNode:(IMBNode*)inNode;

// Custom nodes...

- (void) addNodeForFolder:(NSString*)inPath;
- (BOOL) removeNode:(IMBNode*)inNode;

// Popup menu...

- (NSMenu*) menuWithSelector:(SEL)inSelector target:(id)inTarget addSeparators:(BOOL)inAddSeparator;

// Debugging support...

- (void) logNodes;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// The following delegate methods are called multiple times during the app lifetime. Return NO from the  
// should methods to suppress an operation. The delegate methods are called on the main thread... 

@protocol IMBLibraryControllerDelegate

@optional

- (BOOL) controller:(IMBLibraryController*)inController shouldCreateNodeWithParser:(IMBParser*)inParser;
- (void) controller:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser;
- (void) controller:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser;

- (BOOL) controller:(IMBLibraryController*)inController shouldExpandNode:(IMBNode*)inNode;
- (void) controller:(IMBLibraryController*)inController willExpandNode:(IMBNode*)inNode;
- (void) controller:(IMBLibraryController*)inController didExpandNode:(IMBNode*)inNode;

- (BOOL) controller:(IMBLibraryController*)inController shouldSelectNode:(IMBNode*)inNode;
- (void) controller:(IMBLibraryController*)inController willSelectNode:(IMBNode*)inNode;
- (void) controller:(IMBLibraryController*)inController didSelectNode:(IMBNode*)inNode;

@end


//----------------------------------------------------------------------------------------------------------------------

