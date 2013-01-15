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


#pragma mark CONSTANTS

extern NSString* kIMBExpandAndSelectNodeWithIdentifierNotification;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBLibraryController;
@class NSObjectViewController;
@class IMBOutlineView;
@class IMBNode;
@protocol IMBNodeViewControllerDelegate;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBNodeViewController : NSViewController <NSOutlineViewDataSource,NSOutlineViewDelegate,NSSplitViewDelegate>
{
	IBOutlet NSSplitView* ibSplitView;
	IBOutlet IMBOutlineView* ibNodeOutlineView;
	IBOutlet NSPopUpButton* ibNodePopupButton;
	IBOutlet NSView* ibHeaderContainerView;
	IBOutlet NSView* ibObjectContainerView;
	IBOutlet NSView* ibFooterContainerView;
	
	IMBLibraryController* _libraryController;
	NSString* _selectedNodeIdentifier;
	NSMutableArray* _expandedNodeIdentifiers;
	BOOL _isRestoringState;
 	BOOL _shouldSuppressPopulateNode;
	NSPoint _nodeOutlineViewSavedVisibleRectOrigin;
	id<IMBNodeViewControllerDelegate> _delegate;
	
	NSViewController* _standardHeaderViewController;
	NSViewController* _standardObjectViewController;
	NSViewController* _standardFooterViewController;
	NSViewController* _headerViewController;
	NSViewController* _objectViewController;
	NSViewController* _footerViewController;
}

+ (void) registerNodeViewControllerClass:(Class)inNodeViewControllerClass forMediaType:(NSString*)inMediaType;
+ (IMBNodeViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController delegate:(id<IMBNodeViewControllerDelegate>)inDelegate;


// Library...

@property (retain) IMBLibraryController* libraryController;

// Support for subclasses; please don't rely on it in your own apps
+ (NSImage *)iconForAppWithBundleIdentifier:(NSString *)identifier fallbackFolder:(NSSearchPathDirectory)directory;

- (NSString*) mediaType;
- (NSImage*) icon;
- (NSString*) displayName;

// Delegate...

@property (assign) id<IMBNodeViewControllerDelegate> delegate;

// Saving/Restoring state...

- (void) restoreState;	
- (void) saveState;	


// Selecting a node...

- (void) selectNode:(IMBNode*)inNode;
- (IMBNode*) selectedNode;

- (void) expandSelectedNode;

@property (retain) NSString* selectedNodeIdentifier;
@property (retain) NSMutableArray* expandedNodeIdentifiers;

+ (void) revealNodeWithIdentifier:(NSString*)inIdentifier;	// These methods work via notification and affect
+ (void) selectNodeWithIdentifier:(NSString*)inIdentifier;	// all instances of IMBNodeViewController...


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

@property (retain) NSViewController* standardHeaderViewController;
@property (retain) NSViewController* standardObjectViewController;
@property (retain) NSViewController* standardFooterViewController;

@property (retain) NSViewController* headerViewController;
@property (retain) NSViewController* objectViewController;
@property (retain) NSViewController* footerViewController;

- (void) installObjectViewForNode:(IMBNode*)inNode;
- (NSSize) minimumViewSize;

// Use this method in your host app to tell the current object view (icon, list, or combo view)
// that it needs to re-display itself (e.g. when a badge on an image needs to be updated)...

- (void) setObjectContainerViewNeedsDisplay:(BOOL)inFlag;


// View accessors...

@property (readonly) IMBOutlineView* nodeOutlineView;
@property (readonly) NSPopUpButton* nodePopupButton;
@property (readonly) NSView* headerContainerView;
@property (readonly) NSView* objectContainerView;
@property (readonly) NSView* footerContainerView;


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBNodeViewControllerDelegate

@optional

// The delegate can supply its own object view controllers for certain nodes. 
// If it chooses to do so, this overrides everything else...

- (NSViewController*) nodeViewController:(IMBNodeViewController*)inNodeViewController customHeaderViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) nodeViewController:(IMBNodeViewController*)inNodeViewController customObjectViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) nodeViewController:(IMBNodeViewController*)inNodeViewController customFooterViewControllerForNode:(IMBNode*)inNode;

@end


//----------------------------------------------------------------------------------------------------------------------


