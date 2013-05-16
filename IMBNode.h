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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBObject;
@class IMBParserMessenger;
@class IMBParser;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBNode : NSObject <NSCopying,NSCoding>
{
	// Primary properties...

	NSImage* _icon;
	NSImage* _highlightIcon;        // Optional. To be used when node is highlighted.
	NSString* _name;
	NSString* _identifier;
	NSString* _mediaType;
	NSURL* _mediaSource;
	NSDictionary* _attributes;
	NSUInteger _groupType;
	
	// Subnodes & Objects...
	
	NSMutableArray* _subnodes;
	NSArray* _objects;
	IMBNode* _parentNode;	// not retained!

	// Info about our parser...
	
	IMBParserMessenger* _parserMessenger;
	NSString* _parserIdentifier;
	NSError* _error;

	// State information...

	NSUInteger _displayPriority;
	NSInteger _displayedObjectCount;
	
	BOOL _isGroupNode;
	BOOL _isTopLevelNode;
	BOOL _isLeafNode;
	BOOL _isLoading;
	BOOL _isUserAdded;
	BOOL _isIncludedInPopup;
	BOOL _wantsRecursiveObjects;
	BOOL _shouldDisplayObjectView;
    IMBResourceAccessibility _accessibility;
    BOOL _isAccessRevocable;
	
	// Observing file system changes...
	
	IMBWatcherType _watcherType;
	NSString* _watchedPath;

	// Badges...
	
	IMBBadgeType _badgeTypeNormal;
	IMBBadgeType _badgeTypeMouseover;
	id _badgeTarget;
	SEL _badgeSelector;
}


//----------------------------------------------------------------------------------------------------------------------


// Primary properties for a node:

@property (retain) NSImage* icon;					// 16x16 icon for user interface
@property (retain) NSImage* highlightIcon;			// Optional. To be used when node is highlighted.
@property (copy) NSString* name;					// Display name for user interface
@property (copy) NSString* identifier;				// Unique identifier of form parserClassName://path/to/node
@property (retain) NSString* mediaType;				// See IMBCommon.h
@property (retain) NSURL* mediaSource;				// Only toplevel nodes need this property
@property (retain) NSDictionary* attributes;		// Optional metadata about a node
@property (assign) NSUInteger groupType;			// Used for grouping toplevel nodes

// Info about our parser...

@property (retain) IMBParserMessenger* parserMessenger;
@property (copy) NSString* parserIdentifier;		// Unique identifier of the parser
@property (retain) NSError* error;					// Per node error


//----------------------------------------------------------------------------------------------------------------------


// Node tree accessors. If the subnodes property is nil, that doesn't mean that there are no subnodes - instead it
// means that the array hasn't been created yet and will be created lazily at a later time. If on the other hand 
// subnodes is an empty array, then there really aren't any subnodes...

@property (retain,readonly) NSArray* subnodes;		
		
// Designated initializer

- (id) initWithParser:(IMBParser*)inParser topLevel:(BOOL)inTopLevel;

- (NSUInteger) countOfSubnodes;
- (IMBNode*) objectInSubnodesAtIndex:(NSUInteger)inIndex;

// For parser classes and IMBLibraryController, who need to modify nodes, use this method. By calling it, the node 
// is marked as populated...

- (NSMutableArray*) mutableArrayForPopulatingSubnodes;

// The parentNode is not retained!

@property (assign,readonly) IMBNode* parentNode;


//----------------------------------------------------------------------------------------------------------------------


// Object accessors. If the objects property is nil, that doesn't mean that there are no objects - instead it
// means that the array hasn't been created yet and will be created lazily at a later time. If on the other hand 
// objects is an empty array, then there really aren't any objects...

@property (retain) NSArray* objects;

- (NSUInteger) countOfShallowObjects;
- (IMBObject*) objectInShallowObjectsAtIndex:(NSUInteger)inIndex;

- (NSUInteger) countOfRecursiveObjects;
- (IMBObject*) objectInRecursiveObjectsAtIndex:(NSUInteger)inIndex;

- (NSUInteger) countOfBindableObjects;
- (IMBObject*) objectInBindableObjectsAtIndex:(NSUInteger)inIndex;

// This property can be used by parsers if the real object count differs from what the NSArrayController sees. 
// An example would be a folder based parser. If a folder contains 3 images and 3 subfolders, then 6 objects 
// are reported by the NSArrayController, but we really only want "3 images" displayed in the user interface.
// If property is left at the uninitialized value of -1, then countOfBindableObjects is used as is. If a parser
// chooses to write a non negative value into this property, then this number is displayed instead...
 
@property (assign) NSInteger displayedObjectCount;


//----------------------------------------------------------------------------------------------------------------------


// State information about a node...

@property (assign) BOOL isGroupNode;
@property (assign) BOOL isTopLevelNode;
@property (assign) BOOL isLeafNode;
@property (assign) BOOL isLoading;
@property (assign) BOOL isUserAdded;
@property (assign) BOOL isIncludedInPopup;
@property (assign) BOOL wantsRecursiveObjects;
@property (assign) BOOL shouldDisplayObjectView;	
@property (assign) NSUInteger displayPriority;		// to push certain nodes up or down in the list
@property (assign) IMBResourceAccessibility accessibility;
@property (assign) BOOL isAccessRevocable;          // will enable us to show a "logout" badge or not

// Observing file system changes...

@property (assign) IMBWatcherType watcherType;
@property (copy) NSString* watchedPath;

// Support for node badge icon/button. Set the normal and the mouseover icon with the IMBadgeType. 
// The selector gets sent to the target when the badge is clicked.

@property (assign) IMBBadgeType badgeTypeNormal;
@property (assign) IMBBadgeType badgeTypeMouseover;
@property (retain) id badgeTarget;
@property (assign) SEL badgeSelector;


//----------------------------------------------------------------------------------------------------------------------


// Helper methods

- (NSComparisonResult) compare:(IMBNode*)inNode;
+ (NSUInteger) insertionIndexForNode:(IMBNode*)inSubnode inSubnodes:(NSArray*)inSubnodes;
- (BOOL) isAncestorOfNode:(IMBNode*)inNode;
- (BOOL) isDescendantOfNode:(IMBNode*)inNode;

- (NSIndexPath*) indexPath;
- (IMBNode*) topLevelNode;

// Returns the root url of this node's library (may be different from self.mediaSource)

- (NSURL*)libraryRootURL;

- (IMBNode*) subnodeWithIdentifier:(NSString*)identifier;
- (BOOL) isPopulated;

// The normal (non-mouseover), non-loading badge type for this node possibly derived
// from other properties.

- (IMBBadgeType) badgeTypeNormalNonLoading;

- (BOOL)hasBadgeCallback;

- (void)performBadgeCallback;
@end


//----------------------------------------------------------------------------------------------------------------------


// The following methods are for internal use in the framework only...

@interface IMBNode (Private)

- (void) unpopulate;

@end


//----------------------------------------------------------------------------------------------------------------------

