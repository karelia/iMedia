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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark ABSTRACT

// This subclass of NSViewController is responsible for the lower half of a browser window, i.e. the object views.
// It loads the views and handles things like view options and their persistence. Please note that this controller   
// is the delegate of all views, so do not modify those delegates. If you do need delegate messages for various  
// events, then use the delegate methods of IMBLibraryController.

// There is an instance of this controller per window and per media type. If we have 4 media types (photos, music,
// video, links) and 3 windows containing media browser UI, then we need 12 instances of this controller. This 
// controller coordinates between the views and the IMBLibraryController. Essentially IMBLibraryController is a 
// backend controller, while IMBObjectViewController is a frontend controller.

// ATTENTION: This is an abstract base class. Do not use an instance of this class, but use a specific subclass
// like IMBImageObjectViewController or IMBAudioObjectViewController instead...


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBCommon.h"
#import "IMBQLPreviewPanel.h"
#import "IMBObjectArrayController.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

enum
{
	kIMBObjectViewTypeIcon,
	kIMBObjectViewTypeList,
	kIMBObjectViewTypeCombo,
};
typedef NSUInteger kIMBObjectViewType;

typedef enum
{ 
	kIMBObjectFilterAll = 0,
	kIMBObjectFilterBadge,
	kIMBObjectFilterNoBadge
} 
IMBObjectFilter;

extern NSString* kIMBObjectBadgesDidChangeNotification;





//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBNode;
@class IMBObject;
@class IMBNodeObject;
@class IMBLibraryController;
@class IMBNodeViewController;
@class IMBObjectArrayController;
@class IMBProgressWindowController;
@class IKImageBrowserView;
@protocol IMBObjectViewControllerDelegate;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


@interface IMBObjectViewController : NSViewController <IMBObjectArrayControllerDelegate,QLPreviewPanelDelegate,QLPreviewPanelDataSource>
{
	// Backend...
	
	IMBLibraryController* _libraryController;
	IMBNode* _currentNode;
	IBOutlet IMBObjectArrayController* ibObjectArrayController;
	IMBObjectFilter _objectFilter;
	id<IMBObjectViewControllerDelegate> _delegate;
	
	// User Interface...
	
	IBOutlet NSTabView* ibTabView;
	IBOutlet IKImageBrowserView* ibIconView;
 	IBOutlet NSTableView* ibListView;
	IBOutlet NSTableView* ibComboView;
	IBOutlet NSSegmentedControl* ibSegments;
	
	NSUInteger _viewType;
	double _iconSize;
	NSString* _objectCountFormatSingular;
	NSString* _objectCountFormatPlural;
	NSMutableSet* _observedVisibleItems;
	
	// Event Handling...
	
	IMBObject* _clickedObject;
//	IMBProgressWindowController* _progressWindowController;
}

// Subclasses can register themselves here from threir +load method at this central registry. We also have a 
// central factory method to create an IMBObjectViewController by media type...

+ (void) registerObjectViewControllerClass:(Class)inObjectViewControllerClass forMediaType:(NSString*)inMediaType;
+ (IMBObjectViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController delegate:(id<IMBObjectViewControllerDelegate>)inDelegate;

// Customize Subclasses. Overriding these methods lets you define your subclass identity...
 
+ (NSString*) mediaType;						// required
+ (NSString*) nibName;							// required
+ (NSString*) objectCountFormatSingular;		// required
+ (NSString*) objectCountFormatPlural;			// required

+ (Class) iconViewCellClass;					// optional
+ (CALayer*) iconViewBackgroundLayer;			// optional

// Backend: An IMBObjectViewController must be connected to a IMBLibraryController. The currentNode is set from 
// the outside, wheneven a node is selected in the NSOutlineView of a IMBNodeViewController. This in turn fills  
// the IMBObjectArrayController with content...

@property (retain) IMBLibraryController* libraryController;
- (NSString*) mediaType;
@property (assign) id<IMBObjectViewControllerDelegate> delegate;

@property (retain) IMBNode* currentNode;
@property (readonly) IMBObjectArrayController* objectArrayController;

// Persistence...

- (void) restoreState;	
- (void) saveState;	

// User Interface...

@property (readonly) NSTabView* tabView;
@property (readonly) IKImageBrowserView* iconView;
@property (readonly) NSTableView* listView;
@property (readonly) NSTableView* comboView;

@property (assign) NSUInteger viewType;
@property (assign) double iconSize;
@property (readonly) BOOL canUseIconSize;

@property (readonly) NSString* objectCountString;

@property (retain) NSString* objectCountFormatSingular;
@property (retain) NSString* objectCountFormatPlural;

- (void) willShowView;	// Called when an object view is shown
- (void) didShowView;

- (void) willHideView;	// Called when an object view is hidden
- (void) didHideView;

- (void) unbindViews;	// Can be used by host application to tear down bindings before a window is closed (useful to break retain cycles!)

- (NSRect) iconRectForTableView:(NSTableView*)inTableView row:(NSInteger)inRow inset:(CGFloat)inInset;

// Event Handling

@property (retain) IMBObject* clickedObject;

- (NSMenu*) menuForObject:(IMBObject*)inObject;
- (NSIndexSet*) filteredDraggingIndexes:(NSIndexSet*)inIndexes;
- (NSUInteger) writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard;

//@property (retain) IMBProgressWindowController* progressWindowController;

// Open Media Files...

- (void) expandNodeObject:(IMBNodeObject*)inNodeObject;
- (IBAction) openSelectedObjects:(id)inSender;
- (void) openObjects:(NSArray*)inObjects;

// Quicklook...

- (IBAction) quicklook:(id)inSender;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBObjectViewControllerDelegate <NSObject>

@optional

// The delegate may provide a badge to decorate the thumbnail of inObject...

- (NSImage*) objectViewController:(IMBObjectViewController*)inController badgeForObject:(IMBObject*)inObject;

// If the delegate implements this method, then it can request a custom cell for the IKImageBrowserView...

- (Class) imageBrowserCellClassForController:(IMBObjectViewController*)inController;

// If the delegate implements this method, then it can create its own backround layer for the IKImageBrowserView...

- (CALayer*) imageBrowserBackgroundLayerForController:(IMBObjectViewController*)inController;

// With this method the delegate can return a custom drag image for a drags starting from the IKImageBrowserView...

- (NSImage*) draggedImageForController:(IMBObjectViewController*)inController draggedObjects:(NSArray*)inObjects;

// With this method the delegate may add setup instructions for selected (sub)views of the controller.
// The delegate is advised to be conservative with what to instruct as it may violate framework integrity.
// The following views a currently provided for delegate setup:

extern NSString* const IMBObjectViewControllerSegmentedControlKey;		/* Segmented control for object view selection */

- (void) objectViewController:(IMBObjectViewController*)inController didLoadViews:(NSDictionary*)inViews;

@end


//----------------------------------------------------------------------------------------------------------------------


