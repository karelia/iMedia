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

extern NSString* kIMBNodesWillReloadNotification;
extern NSString* kIMBNodesWillChangeNotification;
extern NSString* kIMBNodesDidChangeNotification;
extern NSString* kIMBDidCreateTopLevelNodeNotification;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBNode;
@class IMBObject;
@class IMBParserMessenger;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLibraryController : NSObject
{
	NSMutableArray* _subnodes;
	BOOL _isReplacingNode;
	NSString* _mediaType;
	id _delegate;
}

// Create singleton instance of the controller. Don't forget to set the delegate early in the app lifetime...

+ (IMBLibraryController*) sharedLibraryControllerWithMediaType:(NSString*)inMediaType;
- (id) initWithMediaType:(NSString*)inMediaType;

// Accessors...

@property (assign) id delegate;
@property (retain) NSString* mediaType;
@property (readonly) BOOL isReplacingNode;

// Loading...

- (void) reload;

- (void) createTopLevelNodesWithParserMessenger:(IMBParserMessenger*)inParserMessenger;
- (void) populateNode:(IMBNode*)inNode errorCompletion:(void(^)(NSError* error))errorCompletion;
- (void) populateNode:(IMBNode*)inNode;
- (void) reloadNodeTree:(IMBNode*)inOldNode errorCompletion:(void(^)(NSError* error))inErrorCompletion;
- (void) reloadNodeTree:(IMBNode*)inOldNode;

// Try to reload any top-level nodes that do not have access rights and which might benefit from the newly
// granted URL...

+ (void) reloadTopLevelNodesWithoutAccessRights;


// Node accessors (must only be called on the main thread)...

@property (retain,readonly) NSMutableArray* subnodes;	
- (NSUInteger) countOfSubnodes;
- (IMBNode*) objectInSubnodesAtIndex:(NSUInteger)inIndex;
- (IMBNode*) nodeWithIdentifier:(NSString*)inIdentifier;
- (IMBNode*) topLevelNodeForParserIdentifier:(NSString*)inParserIdentifier;

- (NSArray*) topLevelNodesWithoutAccessRights;
- (NSArray*) libraryRootURLsForNodes:(NSArray*)inNodes;

- (void) logNodes;

// User added nodes...

- (IMBParserMessenger*) addUserAddedNodeForFolder:(NSURL*)inFolderURL;
- (BOOL) removeUserAddedNode:(IMBNode*)inNode;

// Popup menu...

- (NSMenu*) menuWithSelector:(SEL)inSelector target:(id)inTarget addSeparators:(BOOL)inAddSeparator;

// Helpers...

+ (NSArray*) knownMediaTypes;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBLibraryControllerDelegate

@optional

// The following delegate methods are called multiple times during the app lifetime. Return NO from the  
// should methods to suppress an operation. The delegate methods are called on the main thread... 

- (BOOL) libraryController:(IMBLibraryController*)inController shouldCreateNodeWithParserMessenger:(IMBParserMessenger*)inParserMessenger;
- (void) libraryController:(IMBLibraryController*)inController willCreateNodeWithParserMessenger:(IMBParserMessenger*)inParserMessenger;
- (void) libraryController:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParserMessenger:(IMBParserMessenger*)inParserMessenger;

- (BOOL) libraryController:(IMBLibraryController*)inController shouldPopulateNode:(IMBNode*)inNode;
- (void) libraryController:(IMBLibraryController*)inController willPopulateNode:(IMBNode*)inNode;
- (void) libraryController:(IMBLibraryController*)inController didPopulateNode:(IMBNode*)inNode;

// Called when the user right clicks a node or object. These methods give the delegate a chance to add 
// custom menu items to the exisiting context menu...

- (void) libraryController:(IMBLibraryController*)inController willShowContextMenu:(NSMenu*)inMenu forNode:(IMBNode*)inNode;
- (void) libraryController:(IMBLibraryController*)inController willShowContextMenu:(NSMenu*)inMenu forObject:(IMBObject*)inObject;

// Called when the user double clicks selected object in one of the object views. If the delegate chooses to
// handle the event itself it must return YES. If NO is returned, the framework will invoke the default event
// handling behavior (downloading the files to standard loaction and opening in default app)...

- (BOOL) libraryController:(IMBLibraryController*)inController didDoubleClickSelectedObjects:(NSArray*)inObjects inNode:(IMBNode*)inNode;

// A less formal delegate method that is nonetheless checked for and dispatched from IMBNodeViewController. I'm
// declaring it here to quiet warnings about an unrecognized @selector() constant.
- (BOOL) allowsFolderDropForMediaType:(NSString*)inMediaType;

@end


//----------------------------------------------------------------------------------------------------------------------


