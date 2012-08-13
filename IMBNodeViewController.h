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

// This subclass of NSViewController is responsible for the splitview and the outline view which shows the library 
// nodes (upper half of the window). It loads the views and is also responsible for handling selection and expansion  
// of nodes, and for making sure that the state is persistent across application launches. 

// Please note that this controller is the delegate of all views, so do not modify those delegates. If you do need
// delegate messages for various events, then use the delegate methods of IMBLibraryController...

// There is an instance of this controller per window and per media type. If we have 4 media types (photos, music,
// video, links) and 3 windows containing media browser UI, then we need 12 instances of this controller. This 
// controller coordinates between the views and the IMBLibraryController. Essentially IMBLibraryController is a 
// backend controller, while IMBNodeViewController is a frontend controller.


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBLibraryController;
@class IMBNodeTreeController;
@class IMBOutlineView;
@class IMBParser;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBNodeViewController : NSViewController
{
	IMBLibraryController* _libraryController;
	NSString* _selectedNodeIdentifier;
	NSArray* _expandedNodeIdentifiers;
	BOOL _isRestoringState;
    NSPoint _nodeOutlineViewSavedVisibleRectOrigin;
	IMBParser* _selectedParser;
	
	IBOutlet NSSplitView* ibSplitView;
	IBOutlet IMBNodeTreeController* ibNodeTreeController;
	IBOutlet IMBOutlineView* ibNodeOutlineView;
	IBOutlet NSPopUpButton* ibNodePopupButton;
	IBOutlet NSView* ibObjectHeaderView;
	IBOutlet NSView* ibObjectContainerView;
	IBOutlet NSView* ibObjectFooterView;
	NSView* _standardObjectView;
	NSView* _customObjectView;
	
	NSMutableDictionary* _customHeaderViewControllers;
	NSMutableDictionary* _customObjectViewControllers;
	NSMutableDictionary* _customFooterViewControllers;
}

+ (IMBNodeViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController;

// Library...

@property (retain) IMBLibraryController* libraryController;
@property (readonly) NSString* mediaType;

// Nodes (sourcelist)...

@property (readonly) IMBNodeTreeController* nodeTreeController;
@property (readonly) IMBOutlineView* nodeOutlineView;
@property (readonly) NSPopUpButton* nodePopupButton;
@property (readonly) NSView* objectHeaderView;
@property (readonly) NSView* objectContainerView;
@property (readonly) NSView* objectFooterView;
@property (retain) NSView* standardObjectView;
@property (retain) NSView* customObjectView;

@property (retain) NSString* selectedNodeIdentifier;
@property (copy) NSArray* expandedNodeIdentifiers;
@property (readonly) IMBNode* selectedNode;
@property (retain) IMBParser* selectedParser;

- (void) selectNode:(IMBNode*)inNode;
- (void) expandSelectedNode;

// Context menu support...

- (NSMenu*) menuForNode:(IMBNode*)inNode;

// Actions...

- (BOOL) canReloadNode;
- (IBAction) reloadNode:(id)inSender;

- (BOOL) canAddNode;
- (IBAction) addNode:(id)inSender;

- (BOOL) canRemoveNode;
- (IBAction) removeNode:(id)inSender;

// Object Views...

- (void) installObjectViewForNode:(IMBNode*)inNode;
- (NSSize) minimumViewSize;

// Saving/Restoring state...

- (void) restoreState;	
- (void) saveState;	

// These methods work via notification and affect all instances of IMBNodeViewController...

+ (void) revealNodeWithIdentifier:(NSString*)inIdentifier;
+ (void) selectNodeWithIdentifier:(NSString*)inIdentifier;

// Use this method in your host app to tell the current object view (icon, list, or combo view)
// that it needs to re-display itself (e.g. when a badge on an image needs to be updated)

- (void) setObjectContainerViewNeedsDisplay:(BOOL)inFlag;


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBNodeViewControllerDelegate

@optional

// The delegate can supply its own object view controllers for certain nodes. 
// If it chooses to do so, this overrides everything else...

- (NSViewController*) customHeaderViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) customObjectViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) customFooterViewControllerForNode:(IMBNode*)inNode;

@end


//----------------------------------------------------------------------------------------------------------------------


