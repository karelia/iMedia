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

// This subclass of NSViewController is responsible for the lower half of a browser window, i.e. the object views.
// It loads the views and handles things like view options and their presistence. Please note that this controller   
// is the delegate of all views, so do not modify those delegates. If you do need delegate messages for various  
// events, then use the delegate methods of IMBLibraryController.

// There is an instance of this controller per window and per media type. If we have 4 media types (photos, music,
// video, links) and 3 windows containing media browser UI, then we need 12 instances of this controller. This 
// controller coordinates between the views and the IMBLibraryController. Essentially IMBLibraryController is a 
// backend controller, while IMBObjectViewController is a frontend controller.

// ATTENTION: This is an abstract base class. Do not use an instance of this class, but use a specific subclass
// like IMBPhotosViewController or IMBMusicViewController instead...


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBCommon.h"
#import "IMBQLPreviewPanel.h"
#import "IMBObjectsPromise.h"
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

extern NSString* kIMBObjectImageRepresentationProperty;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBNode;
@class IMBObject;
@class IMBLibraryController;
@class IMBNodeViewController;
@class IMBObjectArrayController;
@class IMBProgressWindowController;
@class IKImageBrowserView;
@protocol IMBObjectViewControllerDelegate;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


@interface IMBObjectViewController : NSViewController <IMBObjectsPromiseDelegate,IMBObjectArrayControllerDelegate,NSPasteboardItemDataProvider,QLPreviewPanelDelegate,QLPreviewPanelDataSource>
{
	IMBLibraryController* _libraryController;
	IMBNode* _currentNode;
		
	IBOutlet IMBObjectArrayController* ibObjectArrayController;
	IBOutlet NSTabView* ibTabView;
	IBOutlet IKImageBrowserView* ibIconView;
	IBOutlet NSSegmentedControl *ibSegments;
 	IBOutlet NSTableView* ibListView;
	IBOutlet NSTableView* ibComboView;
	IMBObjectFilter ibObjectFilter;
	NSUInteger _viewType;
	double _iconSize;
	
	NSString* _objectCountFormatSingular;
	NSString* _objectCountFormatPlural;
	NSMutableSet* _observedVisibleItems;
	
	BOOL _isDragging;
	NSURL* _dropDestinationURL;
	NSIndexSet* _draggedIndexes;	// save the index set of what is dragged (from a table view) for NSFilesPromisePboardType
	NSInteger _clickedObjectIndex;	// For table views, to know which one was actually clicked upon for dragging
	IMBObject* _clickedObject;
	IMBProgressWindowController* _progressWindowController;
}

+ (NSBundle*) bundle;
+ (IMBObjectViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController;
+ (void) registerObjectViewControllerClass:(Class)inObjectViewControllerClass forMediaType:(NSString*)inMediaType;


// Library...

@property (retain) IMBLibraryController* libraryController;
@property (readonly) NSString* mediaType;
@property (retain) IMBNode* currentNode;
@property (readonly) IMBObjectArrayController* objectArrayController;

// Saving/Restoring state...

- (void) restoreState;	
- (void) saveState;	

// Objects (media files)...

@property (retain) IMBProgressWindowController* progressWindowController;

// Views...

@property (readonly) NSTabView* tabView;
@property (readonly) IKImageBrowserView* iconView;
@property (readonly) NSTableView* listView;
@property (readonly) NSTableView* comboView;

@property (assign) NSUInteger viewType;
@property (assign) double iconSize;
@property (readonly) BOOL canUseIconSize;

@property (retain) NSURL* dropDestinationURL;

@property (assign) NSInteger clickedObjectIndex;
@property (retain) IMBObject* clickedObject;
@property (retain) NSIndexSet *draggedIndexes;

- (void) unbindViews;	

// User Interface...
 
+ (Class) iconViewCellClass;
+ (CALayer*) iconViewBackgroundLayer;

+ (NSString*) objectCountFormatSingular;
+ (NSString*) objectCountFormatPlural;

@property (retain) NSString* objectCountFormatSingular;
@property (retain) NSString* objectCountFormatPlural;
@property (readonly) NSString* objectCountString;

- (void) willShowView;
- (void) didShowView;

- (void) willHideView;
- (void) didHideView;

// Context menu support...

- (NSMenu*) menuForObject:(IMBObject*)inObject;

// Helpers...

- (id <IMBObjectViewControllerDelegate>) delegate;
- (void) expandNodeObject:(IMBObject*)inObject;
- (IBAction) openSelectedObjects:(id)inSender;
- (void) openObjects:(NSArray*)inObjects;
- (IBAction) quicklook:(id)inSender;

//- (IBAction) tableViewWasDoubleClicked:(id)inSender;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBObjectViewControllerDelegate <NSObject>

@optional

// If the delegate implements this method, then it can request a custom cell for the IKImageBrowserView...

- (Class) imageBrowserCellClassForController:(IMBObjectViewController*)inController;

// If the delegate implements this method, then it can its own backround layer for the IKImageBrowserView...

- (CALayer*) imageBrowserBackgroundLayerForController:(IMBObjectViewController*)inController;

// With this method the delegate can return a custom drag image for a drags starting from the IKImageBrowserView...

- (NSImage*) draggedImageForController:(IMBObjectViewController*)inController draggedObjects:(NSArray*)inObjects;

// With this method the delegate may add setup instructions for selected (sub)views of the controller.
// The delegate is advised to be conservative with what to instruct as it may violate framework integrity.
// The following views a currently provided for delegate setup:
//
extern NSString* const IMBObjectViewControllerSegmentedControlKey;		/* Segmented control for object view selection */

- (void) objectViewController:(IMBObjectViewController*)inController didLoadViews:(NSDictionary*)inViews;

// The delegate may provide a badge image to decorate the image of inObject

- (CGImageRef) objectViewController:(IMBObjectViewController*) inController badgeForObject:(IMBObject*) inObject;

@end


//----------------------------------------------------------------------------------------------------------------------


