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

@class IMBObject;
//@class IMBParser;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBNode : NSObject <NSCopying,NSCoding>
{
	// Primary properties...

	NSImage* _icon;
	NSString* _name;
	NSString* _identifier;
	NSString* _mediaType;
	NSURL* _mediaSource;
	NSString* _parserIdentifier;
	
	IMBNode* _parentNode;	// not retained!
	NSArray* _subnodes;
	NSArray* _objects;

	// State information...

	NSDictionary* _attributes;
	NSUInteger _groupType;
	NSUInteger _displayPriority;
	NSInteger _displayedObjectCount;
	BOOL _isTopLevelNode;
	BOOL _group;
	BOOL _leaf;
	BOOL _loading;
	BOOL _includedInPopup;
	BOOL _isUserAdded;
	BOOL _wantsRecursiveObjects;
	
//	IMBParser* _parser;
//	IMBWatcherType _watcherType;
//	NSString* _watchedPath;

	// Badges...
	
	IMBBadgeType _badgeTypeNormal;
	IMBBadgeType _badgeTypeMouseover;
	id _badgeTarget;
	SEL _badgeSelector;

	// Custom object views...
	
	BOOL _shouldDisplayObjectView;
	NSViewController* _customHeaderViewController;
	NSViewController* _customObjectViewController;
	NSViewController* _customFooterViewController;
}

// Primary properties for a node:

@property (retain) NSImage* icon;					// 16x16 icon for user interface
@property (copy) NSString* name;					// Display name for user interface
@property (copy) NSString* identifier;				// Unique identifier of form parserClassName://path/to/node
@property (retain) NSString* mediaType;				// See IMBCommon.h
@property (retain) NSURL* mediaSource;				// Only toplevel nodes need this property
@property (copy) NSString* parserIdentifier;		// Unique identifier of the parser

@property (retain) NSDictionary* attributes;		// Optional metadata about a node
@property (assign) NSUInteger groupType;			// Used for grouping toplevel nodes
@property (assign) NSUInteger displayPriority;		// to push certain nodes up or down in the list

// Node tree accessors. If the subnodes property is nil, that doesn't mean that there are no subnodes - instead it
// means that the array hasn't been created yet and will be created lazily at a later time. If on the other hand 
// subnodes is an empty array, then there really aren't any subnodes...

@property (copy) NSArray* subnodes;				
@property (assign,readonly) IMBNode* parentNode;
@property (readonly) IMBNode* topLevelNode;
@property (assign) BOOL isTopLevelNode;

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
// are reported by the NSArrayController, but we really only want 3 image displayed in the user interface.
// If property is left at the uninitialized value of -1, then countOfBindableObjects is used as is. If a parser
// chooses to write a non negative value into this property, then this number is displayed instead...
 
@property (assign) NSInteger displayedObjectCount;

// State information about a node...

@property (assign,getter=isGroup) BOOL group;
@property (assign,getter=isLeaf) BOOL leaf;
@property (assign,getter=isLoading) BOOL loading;
@property (assign) BOOL includedInPopup;
@property (assign) BOOL isUserAdded;
@property (assign) BOOL wantsRecursiveObjects;

// Support for live watching and asynchronous nodes

//@property (retain) IMBParser* parser;
//@property (assign) IMBWatcherType watcherType;
//@property (copy) NSString* watchedPath;

// Support for node badge icon/button. Set the normal and the mouseover icon with the IMBadgeType. 
// The selector gets sent to the target when the badge is clicked.

@property (assign) IMBBadgeType badgeTypeNormal;
@property (assign) IMBBadgeType badgeTypeMouseover;
@property (retain) id badgeTarget;
@property (assign) SEL badgeSelector;

// Indicates whether a node wants to display an object view. Default is YES, but can be changed...

@property (assign) BOOL shouldDisplayObjectView;	
@property (assign) NSViewController* customHeaderViewController;	
@property (assign) NSViewController* customObjectViewController;	
@property (assign) NSViewController* customFooterViewController;	

// Helper methods

- (NSComparisonResult) compare:(IMBNode*)inNode;
- (BOOL) isAncestorOfNode:(IMBNode*)inNode;
- (BOOL) isDescendantOfNode:(IMBNode*)inNode;

- (NSIndexPath*) indexPath;
- (IMBNode*) subnodeWithIdentifier:(NSString*)identifier;
- (BOOL) isPopulated;


@end


//----------------------------------------------------------------------------------------------------------------------

