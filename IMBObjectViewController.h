/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


extern NSString* const kIMBObjectImageRepresentationProperty;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBLibraryController;
@class IMBNodeViewController;
@class IMBObjectArrayController;
@class IMBProgressWindowController;
@class IMBObject;
@class IMBNode;
@class IKImageBrowserView;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark PROTOCOLS

// We have to declare a fake prototypes because the 10.6 runtime interrogates our compliance with the protocol,
// rather that interrogating the presence of the particular method we implement.

#if ! IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK

@protocol NSPasteboardItemDataProvider <NSObject> 
@end

@protocol QLPreviewPanelDelegate <NSObject> 
@end

@protocol QLPreviewPanelDataSource <NSObject> 
@end

#endif


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


@interface IMBObjectViewController : NSViewController <NSPasteboardItemDataProvider,QLPreviewPanelDelegate,QLPreviewPanelDataSource>
//#if IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK
//<NSPasteboardItemDataProvider,QLPreviewPanelDelegate,QLPreviewPanelDataSource>
//#else
//<NSPasteboardItemDataProvider>
//#endif
{
	IMBLibraryController* _libraryController;
	IMBNodeViewController* _nodeViewController;
	IMBProgressWindowController* _progressWindowController;
		
	IBOutlet IMBObjectArrayController* ibObjectArrayController;
	IBOutlet NSTabView* ibTabView;
	IBOutlet IKImageBrowserView* ibIconView;
	IBOutlet NSTableView* ibListView;
	IBOutlet NSTableView* ibComboView;
	IBOutlet NSSegmentedControl *ibSegments;
 	
	NSUInteger _viewType;
	double _iconSize;
	
	NSString* _objectCountFormatSingular;
	NSString* _objectCountFormatPlural;
	BOOL _isDragging;
	
	NSMutableSet *_observedVisibleItems;
	
	NSURL *_dropDestinationURL;
	
	NSIndexSet *_draggedIndexes;	// save the index set of what is dragged (from a table view) for NSFilesPromisePboardType
	
	// For table views, to know which one was actually clicked upon for dragging
	NSInteger _clickedObjectIndex;
	IMBObject* _clickedObject;

}

+ (IMBObjectViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController;

// Library...

@property (retain) IMBLibraryController* libraryController;
@property (retain) IMBNodeViewController* nodeViewController;
@property (readonly) NSString* mediaType;
@property (readonly) IMBNode* currentNode;

// Objects (media files)...

@property (readonly) IMBObjectArrayController* objectArrayController;
@property (retain) IMBProgressWindowController* progressWindowController;

// Views...

@property (readonly) NSTabView* tabView;
@property (readonly) IKImageBrowserView* iconView;
@property (readonly) NSTableView* listView;
@property (readonly) NSTableView* comboView;

@property (assign) NSUInteger viewType;
@property (assign) double iconSize;
@property (readonly) BOOL canUseIconSize;

@property (retain) NSURL *dropDestinationURL;

@property (assign) NSInteger clickedObjectIndex;
@property (retain) IMBObject* clickedObject;
@property (retain) NSIndexSet *draggedIndexes;

- (void) unbindViews;	

// User Interface...
 
- (NSImage*) icon;
- (NSString*) displayName;

@property (retain) NSString* objectCountFormatSingular;
@property (retain) NSString* objectCountFormatPlural;
@property (readonly) NSString* objectCountString;

- (void) willShowView;
- (void) didShowView;

- (void) willHideView;
- (void) didHideView;

// Saving/Restoring state...

- (void) restoreState;	
- (void) saveState;	

// Context menu support...

- (NSMenu*) menuForObject:(IMBObject*)inObject;

// Helpers...

- (IBAction) openSelectedObjects:(id)inSender;
- (void) openObjects:(NSArray*)inObjects inSelectedNode:(IMBNode*)inSelectedNode;
- (IBAction) quicklook:(id)inSender;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBObjectViewControllerDelegate

@optional

// If the delegate implements this method, then it can reequest a custom cell for the IKImageBrowserView...

- (Class) imageBrowserCellClassForController:(IMBObjectViewController*)inController;

// With this method the delegate can return a custom drag image for a drags starting from the IKImageBrowserView...

- (NSImage*) draggedImageForController:(IMBObjectViewController*)inController draggedObjects:(NSArray*)inObjects;

@end


//----------------------------------------------------------------------------------------------------------------------


