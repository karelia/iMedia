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


#pragma mark HEADERS

#import "IMBObjectViewController.h"
#import "IMBNodeViewController.h"
#import "IMBLibraryController.h"
#import "IMBObjectArrayController.h"
#import "IMBFolderParser.h"
#import "IMBConfig.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBMovieObject.h"
#import "IMBNodeObject.h"
#import "IMBObjectsPromise.h"
#import "IMBImageBrowserCell.h"
#import "IMBProgressWindowController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSView+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBDynamicTableView.h"
#import "IMBComboTextCell.h"
#import "IMBObject.h"
#import "IMBOperationQueue.h"
#import "IMBObjectThumbnailLoadOperation.h"
#import "IMBQLPreviewPanel.h"
#import <Carbon/Carbon.h>
#import "IMBFlickrObject.h"
#import "IMBFlickrNode.h"
#import "NSFileManager+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kImageRepresentationKeyPath = @"arrangedObjects.imageRepresentation";
static NSString* kPosterFrameKeyPath = @"arrangedObjects.posterFrame";
static NSString* kObjectCountStringKey = @"objectCountString";
static NSString* kIMBPrivateItemIndexPasteboardType = @"com.karelia.imedia.imbobjectviewcontroller.itemindex";

NSString* kIMBPublicTitleListPasteboardType = @"imedia.title";
NSString* kIMBPublicMetadataListPasteboardType = @"imedia.metadata";

NSString* kIMBObjectImageRepresentationProperty = @"imageRepresentation";


//----------------------------------------------------------------------------------------------------------------------


// While we're building with a pre-10.6 SDK, we need to declare some 10.6 pasteboard stuff that we'll use 
// conditionally if we detect we are running on 10.6 or later.

#if !defined(MAC_OS_X_VERSION_10_6)

#pragma mark 

@interface NSPasteboard (IMBObjectViewControllerSnowLeopard)

- (NSInteger)clearContents;
- (BOOL)writeObjects:(NSArray *)objects;

@end

@class NSPasteboardItem;

#pragma mark 

@interface NSObject (IMBObjectViewControllerSnowLeopard)

- (BOOL)setDataProvider:(id /*<NSPasteboardItemDataProvider>*/)dataProvider forTypes:(NSArray *)types;
- (BOOL)setString:(NSString *)string forType:(NSString *)type;
- (NSString *)stringForType:(NSString *)type;
- (NSData *)dataForType:(NSString *)type;

@end

#endif


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBObjectViewController ()

- (void) _configureIconView;
- (void) _configureListView;
- (void) _configureComboView;

- (NSMutableDictionary*) _preferences;
- (void) _setPreferences:(NSMutableDictionary*)inDict;
- (void) _saveStateToPreferences;
- (void) _loadStateFromPreferences;
- (void) _reloadIconView;
- (void) _reloadListView;
- (void) _reloadComboView;
- (void) _updateTooltips;

- (BOOL) writesLocalFilesToPasteboard;
- (void) _downloadDraggedObjectsToDestination:(NSURL*)inDestination;
- (NSArray*) _namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectViewController

@synthesize libraryController = _libraryController;
@synthesize nodeViewController = _nodeViewController;
@synthesize objectArrayController = ibObjectArrayController;
@synthesize progressWindowController = _progressWindowController;

@synthesize viewType = _viewType;
@synthesize tabView = ibTabView;
@synthesize iconView = ibIconView;
@synthesize iconSize = _iconSize;

@synthesize listView = ibListView;
- (void)setListView:(NSTableView *)listView;
{
    // Don't want dangling pointers
    [ibListView setDataSource:nil];
    [ibListView setDelegate:nil];
    
    [listView retain];
    [ibListView release]; ibListView = listView;
}

@synthesize comboView = ibComboView;
- (void)setComboView:(NSTableView *)comboView;
{
    // Don't want dangling pointers
    [ibComboView setDataSource:nil];
    [ibComboView setDelegate:nil];
    
    [comboView retain];
    [ibComboView release]; ibComboView = comboView;
}


@synthesize objectCountFormatSingular = _objectCountFormatSingular;
@synthesize objectCountFormatPlural = _objectCountFormatPlural;

@synthesize dropDestinationURL = _dropDestinationURL;

@synthesize clickedObjectIndex = _clickedObjectIndex;
@synthesize clickedObject = _clickedObject;
@synthesize draggedIndexes = _draggedIndexes;

//----------------------------------------------------------------------------------------------------------------------


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
}


+ (NSString*) mediaType
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSString*) nibName
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSString*) objectCountFormatSingular
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSString*) objectCountFormatPlural
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (IMBObjectViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController
{
	IMBObjectViewController* controller = [[[[self class] alloc] initWithNibName:[self nibName] bundle:[self bundle]] autorelease];
	[controller view];										// Load the view *before* setting the libraryController, 
	controller.libraryController = inLibraryController;		// so that outlets are set before we load the preferences.
	return controller;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (id) initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle
{
	if (self = [super initWithNibName:inNibName bundle:inBundle])
	{
		self.objectCountFormatSingular = [[self class] objectCountFormatSingular];
		self.objectCountFormatPlural = [[self class] objectCountFormatPlural];
	}
	
	return self;
}


- (void) awakeFromNib
{
	// Configure the object views...
	
	[self _configureIconView];
	[self _configureListView];
	[self _configureComboView];
	
	// Just naming an image file '*Template' is not enough. So we explicitly make sure that all images in the
	// NSSegmentedControl are templates, so that they get correctly inverted when a segment is highlighted...
	
	NSInteger n = [ibSegments segmentCount];
	
	for (NSInteger i=0; i<n; i++)
	{
		[[ibSegments imageForSegment:i] setTemplate:YES];
	}
	
	// Observe changes to object array...
	
	[ibObjectArrayController retain];
	[ibObjectArrayController addObserver:self forKeyPath:kArrangedObjectsKey options:0 context:(void*)kArrangedObjectsKey];
	[ibObjectArrayController addObserver:self forKeyPath:kImageRepresentationKeyPath options:NSKeyValueObservingOptionNew context:(void*)kImageRepresentationKeyPath];
	[ibObjectArrayController addObserver:self forKeyPath:kPosterFrameKeyPath options:NSKeyValueObservingOptionNew context:(void*)kPosterFrameKeyPath];

	// We need to save preferences before the app quits...
	
	[[NSNotificationCenter defaultCenter] 
		 addObserver:self 
		 selector:@selector(_saveStateToPreferences) 
		 name:NSApplicationWillTerminateNotification 
		 object:nil];
}


- (void) unbindViews	
{
	// Tear down bindings *before* the window is closed. This avoids exceptions due to random deallocation order of 
	// top level objects in the nib file. Please note that we are unbinding ibIconView, ibListView, and ibComboView
	// seperately in addition to self.view. This is necessary because NSTabView seems to be doing some kind of 
	// optimization where the views of invisible tabs are not really part of the window view hierarchy. However the 
	// view subtrees exist and do have bindings to the IMBObjectArrayController - which need to be torn down as well...
	
	[ibIconView imb_unbindViewHierarchy];
	[ibListView imb_unbindViewHierarchy];
	[ibComboView imb_unbindViewHierarchy];
	[self.view imb_unbindViewHierarchy];
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Cancel any scheduled messages...
	
	[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView];
	[NSObject cancelPreviousPerformRequestsWithTarget:ibListView];
	[NSObject cancelPreviousPerformRequestsWithTarget:ibComboView];

	// remove ourself from the QuickLook preview panel...
	
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		Class panelClass = NSClassFromString(@"QLPreviewPanel");
		QLPreviewPanel* panel = [panelClass sharedPreviewPanel];
		if (panel.delegate == (id)self) panel.delegate = nil;
		if (panel.dataSource == (id)self) panel.dataSource = nil;
	}
	
	// Stop observing the array...
	
	[ibObjectArrayController removeObserver:self forKeyPath:kPosterFrameKeyPath];
	[ibObjectArrayController removeObserver:self forKeyPath:kImageRepresentationKeyPath];
	[ibObjectArrayController removeObserver:self forKeyPath:kArrangedObjectsKey];
	[ibObjectArrayController release];
    
    // Tear down table views...
    
    [self setListView:nil];
    [self setComboView:nil];

	// Other cleanup...
	
	IMBRelease(_libraryController);
	IMBRelease(_nodeViewController);
	IMBRelease(_progressWindowController);
	IMBRelease(_dropDestinationURL);
	IMBRelease(_clickedObject);
	IMBRelease(_draggedIndexes);

	for (IMBObject* object in _observedVisibleItems)
	{
        if ([object isKindOfClass:[IMBObject class]])
		{
#ifdef DEBUG
//			NSLog(@"dealloc REMOVE [%p:%@'%@' removeObs…:%p 4kp:imageRep…", object,[object class],[object name], self);
#endif
            [object removeObserver:self forKeyPath:kIMBObjectImageRepresentationProperty];
            [object removeObserver:self forKeyPath:kIMBPosterFrameProperty];
        }
    }
	
    IMBRelease(_observedVisibleItems);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)inChange context:(void*)inContext
{
	// If the array itself has changed then display the new object count...
	
	if (inContext == (void*)kArrangedObjectsKey)
	{
		[self willChangeValueForKey:kObjectCountStringKey];
		[self didChangeValueForKey:kObjectCountStringKey];
	}
	
	// If single thumbnails have changed (due to asynchronous loading) then trigger a reload of the IKImageBrowserView...
	
	else if (inContext == (void*)kImageRepresentationKeyPath)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadIconView) object:nil];
		[self performSelector:@selector(_reloadIconView) withObject:nil afterDelay:0.05 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadComboView) object:nil];
		[self performSelector:@selector(_reloadComboView) withObject:nil afterDelay:0.05 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	else if (inContext == (void*)kPosterFrameKeyPath)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadComboView) object:nil];
		[self performSelector:@selector(_reloadComboView) withObject:nil afterDelay:0.05 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	
	// Find the row and reload it. Note that KVO notifications may be sent from a background thread (in this 
	// case, we know they will be) We should only update the UI on the main thread, and in addition, we use 
	// NSRunLoopCommonModes to make sure the UI updates when a modal window is up...
		
	else if ([inKeyPath isEqualToString:kIMBObjectImageRepresentationProperty] ||
			 [inKeyPath isEqualToString:kIMBPosterFrameProperty])
	{
		IMBDynamicTableView* affectedTableView = (IMBDynamicTableView*)inContext;
		NSInteger row = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:inObject];
		
		if (NSNotFound != row)
		{
			[affectedTableView 
				performSelectorOnMainThread:@selector(_reloadRow:) 
				withObject:[NSNumber numberWithInt:row] 
				waitUntilDone:NO modes:[NSArray 
				arrayWithObject:NSRunLoopCommonModes]];
		}
    }
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBNode*) currentNode
{
	return [_nodeViewController selectedNode];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) delegate
{
	return self.libraryController.delegate;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Persistence 


- (void) setLibraryController:(IMBLibraryController*)inLibraryController
{
	id old = _libraryController;
	_libraryController = [inLibraryController retain];
	[old release];
	
	[self _loadStateFromPreferences];
}


- (NSString*) mediaType
{
	return self.libraryController.mediaType;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSMutableDictionary*) _preferences
{
	NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
	return [NSMutableDictionary dictionaryWithDictionary:[classDict objectForKey:self.mediaType]];
}


- (void) _setPreferences:(NSMutableDictionary*)inDict
{
	NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
	[classDict setObject:inDict forKey:self.mediaType];
	[IMBConfig setPrefs:classDict forClass:self.class];
}


- (void) _saveStateToPreferences
{
	NSIndexSet* selectionIndexes = [ibObjectArrayController selectionIndexes];
	NSData* selectionData = [NSKeyedArchiver archivedDataWithRootObject:selectionIndexes];
	
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:[NSNumber numberWithUnsignedInteger:self.viewType] forKey:@"viewType"];
	[stateDict setObject:[NSNumber numberWithDouble:self.iconSize] forKey:@"iconSize"];
	[stateDict setObject:selectionData forKey:@"selectionData"];
	
	[self _setPreferences:stateDict];
}


- (void) _loadStateFromPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	self.viewType = [[stateDict objectForKey:@"viewType"] unsignedIntegerValue];
	self.iconSize = [[stateDict objectForKey:@"iconSize"] doubleValue];
	
	//	NSData* selectionData = [stateDict objectForKey:@"selectionData"];
	//	NSIndexSet* selectionIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:selectionData];
	//	[ibObjectArrayController setSelectionIndexes:selectionIndexes];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark User Interface


// Subclasses can override these methods to configure or customize look & feel of the various object views...

- (void) _configureIconView
{
//	// Make the IKImageBrowserView use our custom cell class. Please note that we check for the existence 
//	// of the base class first, as it is un undocumented internal class on 10.5. In 10.6 it is always there...
//	
//	if ([ibIconView respondsToSelector:@selector(setCellClass:)] && NSClassFromString(@"IKImageBrowserCell"))
//	{
//		[ibIconView performSelector:@selector(setCellClass:) withObject:[IMBImageBrowserCell class]];
//	}
//	
//	[ibIconView setAnimates:NO];

//	if ([ibIconView respondsToSelector:@selector(setIntercellSpacing:)])
//	{
//		[ibIconView setIntercellSpacing:NSMakeSize(4.0,4.0)];
//	}
}


- (void) _configureListView
{
	[ibListView setTarget:self];
	[ibListView setAction:@selector(tableViewWasClicked:)];
	[ibListView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
	
    [ibListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];	// I think this was to work around a bug
    [ibListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}


- (void) _configureComboView
{
	[ibComboView setTarget:self];
	[ibComboView setAction:@selector(tableViewWasClicked:)];
	[ibComboView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
	
    [ibComboView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];	// I think this was to work around a bug
    [ibComboView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) willShowView
{
	// To be overridden by subclass...
	
	[self willChangeValueForKey:@"viewType"];
	[self didChangeValueForKey:@"viewType"];
}


- (void) didShowView
{
	// To be overridden by subclass...
}


- (void) willHideView
{
	// To be overridden by subclass...
}


- (void) didHideView
{
	// To be overridden by subclass...
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) icon
{
	return nil;	// Must be overridden by subclass
}


- (NSString*) displayName
{
	return nil;	// Must be overridden by subclass
}


//----------------------------------------------------------------------------------------------------------------------


// Depending of the IMBConfig setting useGlobalViewType, the controller either uses a global state, or each
// controller keeps its own state. It is up to the application developer to choose a behavior...

- (void) setViewType:(NSUInteger)inViewType
{
	[self willChangeValueForKey:@"canUseIconSize"];
	_viewType = inViewType;
	[IMBConfig setPrefsValue:[NSNumber numberWithUnsignedInteger:inViewType] forKey:@"globalViewType"];
	[self didChangeValueForKey:@"canUseIconSize"];
}


- (NSUInteger) viewType
{
	if ([IMBConfig useGlobalViewType])
	{
		return [[IMBConfig prefsValueForKey:@"globalViewType"] unsignedIntegerValue];
	}
	
	return _viewType;
}


// Availability of the icon size slide depends on the view type (e.g. not available in list view)...

- (BOOL) canUseIconSize
{
	return self.viewType != kIMBObjectViewTypeList;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) setIconSize:(double)inIconSize
{
	// Get the row that seems most important in the combo view. Its either the selected row or the middle visible row...
	
	NSRange visibleRows = [ibComboView rowsInRect:[ibComboView visibleRect]];
	NSUInteger firstVisibleRow = visibleRows.location;
	NSUInteger lastVisibleRow = visibleRows.location + visibleRows.length;
	NSUInteger anchorRow = (firstVisibleRow + lastVisibleRow) / 2;
	
	NSIndexSet* selection = [ibObjectArrayController selectionIndexes];
	
	if (selection) 
	{
		NSUInteger firstSelectedRow = [selection firstIndex];
		NSUInteger lastSelectedRow = [selection lastIndex];

		if (firstSelectedRow != NSNotFound &&
			lastSelectedRow != NSNotFound &&
			firstSelectedRow >= firstVisibleRow && 
			lastSelectedRow <= lastVisibleRow)
		{
			anchorRow = (firstSelectedRow + lastSelectedRow) / 2;;
		}	
	}
	
	// Change the cell size of the icon view. Also notify the parser so it can update thumbnails if necessary...
	
	_iconSize = inIconSize;
	[IMBConfig setPrefsValue:[NSNumber numberWithDouble:inIconSize] forKey:@"globalIconSize"];
	
	NSSize size = [ibIconView cellSize];
	IMBParser* parser = self.currentNode.parser;
	
	if ([parser respondsToSelector:@selector(didChangeIconSize:objectView:)])
	{
		[parser didChangeIconSize:size objectView:ibIconView];
	}

	// Update the views. The row height of the combo view needs to be adjusted accordingly...
	
	[ibIconView setNeedsDisplay:YES];
	[ibComboView setNeedsDisplay:YES];

	CGFloat height = 60.0 + 100.0 * _iconSize;
	[ibComboView setRowHeight:height];
	
	// Scroll the combo view so that it appears to be anchored at the same image as before...
	
	NSRect cellFrame = [ibComboView frameOfCellAtColumn:0 row:anchorRow];
	NSRect viewFrame = [ibComboView  frame];
	NSRect superviewFrame = [[ibComboView superview] frame];
	
	CGFloat y = NSMidY(cellFrame) - 0.5 * NSHeight(superviewFrame);
	CGFloat ymax = NSHeight(viewFrame) - NSHeight(superviewFrame);
	if (y < 0.0) y = 0.0;
	if (y > ymax) y = ymax;
	
	NSClipView* clipview = (NSClipView*)[ibComboView superview];
	[clipview scrollToPoint:NSMakePoint(0.0,y)];
	[[ibComboView enclosingScrollView] reflectScrolledClipView:clipview];
	
	// Tooltips in the icon view need to be rebuilt...
	
	[self _updateTooltips];
}


- (double) iconSize
{
	if ([IMBConfig useGlobalViewType])
	{
		return [[IMBConfig prefsValueForKey:@"globalIconSize"] doubleValue];
	}
	
	return _iconSize;
}


//----------------------------------------------------------------------------------------------------------------------


// Return the oject count for the currently selected node. Please note that we ask the node first. Only if the 
// count is missing, we ask the NSArrayController. This way we can react to custom situations, like 3 images and 3 
// subfolders being reported as "3 images" instead of "6 images"...

- (NSString*) objectCountString
{
	IMBNode* node = [self currentNode];
	NSInteger count = node.displayedObjectCount;
	if (count < 0) count = (NSInteger) [[ibObjectArrayController arrangedObjects] count];
	
	NSString* format = count==1 ? self.objectCountFormatSingular : self.objectCountFormatPlural;
	return [NSString stringWithFormat:format,count];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) _reloadIconView
{
	if ([ibIconView.window isVisible])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView selector:@selector(reloadData) object:nil];
		[ibIconView performSelector:@selector(reloadData) withObject:nil afterDelay:0.05 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		[self _updateTooltips];
	}
}


- (void) _reloadListView
{
	if ([ibListView.window isVisible])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:ibListView selector:@selector(reloadData) object:nil];
		[ibListView performSelector:@selector(reloadData) withObject:nil afterDelay:0.05 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


- (void) _reloadComboView
{
	if ([ibComboView.window isVisible])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:ibComboView selector:@selector(reloadData) object:nil];
		[ibComboView performSelector:@selector(reloadData) withObject:nil afterDelay:0.05 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Please note that providing tooltips is WAY too expensive on 10.5 (possibly due to different internal 
// implementation of IKImageBrowserView). For this reason we disable tooltips on 10.5...


- (void) _updateTooltips
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__updateTooltips) object:nil];
	[self performSelector:@selector(__updateTooltips) withObject:nil afterDelay:0.1];
}
	
	
- (void) __updateTooltips
{
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		[ibIconView removeAllToolTips];
		
		NSArray* objects = ibObjectArrayController.arrangedObjects;
		NSInteger i = 0;
		
		for (IMBObject* object in objects)
		{
			NSRect rect = [ibIconView itemFrameAtIndex:i++];
			[ibIconView addToolTipRect:rect owner:object userData:NULL];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Saving/Restoring state...


- (void) restoreState
{
	[self _loadStateFromPreferences];
}


- (void) saveState
{
	[self _saveStateToPreferences];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Context Menu

- (NSMenu*) menuForObject:(IMBObject*)inObject
{
	// Create an empty menu that will be pouplated in several steps...
	
	NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"contextMenu"] autorelease];
	NSMenuItem* item = nil;
	NSString* title = nil;
	NSString* appPath = nil;;
	NSString* appName = nil;;
	NSString* type = nil;
	
	// For node objects (folders) provide a menu item to drill down the hierarchy...
	
	if ([inObject isKindOfClass:[IMBNodeObject class]])
	{
		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.open",
			nil,IMBBundle(),
			@"Open",
			@"Menu item in context menu of IMBObjectViewController");
		
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openSubNode:) keyEquivalent:@""];
		[item setRepresentedObject:[inObject location]];
		[item setTarget:self];
		[menu addItem:item];
		[item release];
	}
	
	// For local file object (path or url) add menu items to open the file (in editor and/or viewer apps)...
		
	else
	{
		id location = [inObject location];
		NSURL* url = (NSURL*)location;
		BOOL localFile = [location isKindOfClass:[NSString class]] || [location isKindOfClass:[NSURL class]] && [url isFileURL];
		
		if (localFile)
		{
			NSString* path = [inObject path];
			
			if ([[NSFileManager imb_threadSafeManager] fileExistsAtPath:path])
			{
				// Open with source app. Commented out for now as apps like iPhoto do not seem to be able to open
				// and display images within its own libary. All it does is display a cryptic error message...
				
//				if ([inObject.parser respondsToSelector:@selector(appPath)])
//				{
//					if (appPath = [inObject.parser performSelector:@selector(appPath)])
//					{
//						title = NSLocalizedStringWithDefaultValue(
//							@"IMBObjectViewController.menuItem.openWithApp",
//							nil,IMBBundle(),
//							@"Open With %@",
//							@"Menu item in context menu of IMBObjectViewController");
//						
//						appName = [[NSFileManager imb_threadSafeManager] displayNameAtPath:appPath];
//						title = [NSString stringWithFormat:title,appName];	
//
//						item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInSourceApp:) keyEquivalent:@""];
//						[item setRepresentedObject:inObject];
//						[item setTarget:self];
//						[menu addItem:item];
//						[item release];
//					}
//				}
				
				// Open with editor app...
				
				if (appPath = [IMBConfig editorAppForMediaType:self.mediaType])
				{
					title = NSLocalizedStringWithDefaultValue(
						@"IMBObjectViewController.menuItem.openWithApp",
						nil,IMBBundle(),
						@"Open With %@",
						@"Menu item in context menu of IMBObjectViewController");
					
					appName = [[NSFileManager imb_threadSafeManager] displayNameAtPath:appPath];
					title = [NSString stringWithFormat:title,appName];	

					item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInEditorApp:) keyEquivalent:@""];
					[item setRepresentedObject:path];
					[item setTarget:self];
					[menu addItem:item];
					[item release];
				}
				
				// Open with viewer app...
				
				if (appPath = [IMBConfig viewerAppForMediaType:self.mediaType])
				{
					title = NSLocalizedStringWithDefaultValue(
						@"IMBObjectViewController.menuItem.openWithApp",
						nil,IMBBundle(),
						@"Open With %@",
						@"Menu item in context menu of IMBObjectViewController");
					
					appName = [[NSFileManager imb_threadSafeManager] displayNameAtPath:appPath];
					title = [NSString stringWithFormat:title,appName];	

					item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInViewerApp:) keyEquivalent:@""];
					[item setRepresentedObject:path];
					[item setTarget:self];
					[menu addItem:item];
					[item release];
				}
				
				// Open with default app determined by OS...
				
				else if ([[NSWorkspace imb_threadSafeWorkspace] getInfoForFile:path application:&appPath type:&type])
				{
					title = NSLocalizedStringWithDefaultValue(
						@"IMBObjectViewController.menuItem.openWithFinder",
						nil,IMBBundle(),
						@"Open with Finder",
						@"Menu item in context menu of IMBObjectViewController");

					item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInApp:) keyEquivalent:@""];
					[item setRepresentedObject:path];
					[item setTarget:self];
					[menu addItem:item];
					[item release];
				}
				
				// Reveal in Finder...
				
				title = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.menuItem.revealInFinder",
					nil,IMBBundle(),
					@"Reveal in Finder",
					@"Menu item in context menu of IMBObjectViewController");
				
				item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
				[item setRepresentedObject:path];
				[item setTarget:self];
				[menu addItem:item];
				[item release];
			}
		}
		
		// Remote URL object can be downloaded or opened in a web browser...
		
		else if ([[inObject location] isKindOfClass:[NSURL class]])
		{
			title = NSLocalizedStringWithDefaultValue(
				@"IMBObjectViewController.menuItem.download",
				nil,IMBBundle(),
				@"Download",
				@"Menu item in context menu of IMBObjectViewController");
			
			item = [[NSMenuItem alloc] initWithTitle:title action:@selector(download:) keyEquivalent:@""];
			[item setRepresentedObject:[inObject location]];
			[item setTarget:self];
			[menu addItem:item];
			[item release];
			
			title = NSLocalizedStringWithDefaultValue(
				@"IMBObjectViewController.menuItem.openInBrowser",
				nil,IMBBundle(),
				@"Open With Browser",
				@"Menu item in context menu of IMBObjectViewController");
			
			item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInBrowser:) keyEquivalent:@""];
			[item setRepresentedObject:[inObject location]];
			[item setTarget:self];
			[menu addItem:item];
			[item release];
		}
	}
	
	// QuickLook...
	
	if ([inObject isSelectable])
	{
//		#if IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK
		if (IMBRunningOnSnowLeopardOrNewer())
		{
			title = NSLocalizedStringWithDefaultValue(
				@"IMBObjectViewController.menuItem.quickLook",
				nil,IMBBundle(),
				@"Quick Look",
				@"Menu item in context menu of IMBObjectViewController");
				
			item = [[NSMenuItem alloc] initWithTitle:title action:@selector(quicklook:) keyEquivalent:@""];
			[item setRepresentedObject:inObject];
			[item setTarget:self];
			[menu addItem:item];
			[item release];
		}
//		#endif
	}
	
	// Give parser a chance to add menu items...
	
	IMBParser* parser = self.currentNode.parser;
	
	if ([parser respondsToSelector:@selector(willShowContextMenu:forObject:)])
	{
		[parser willShowContextMenu:menu forObject:inObject];
	}
	
	// Give delegate a chance to add custom menu items...
	
	id delegate = self.delegate;
	
	if (delegate!=nil && [delegate respondsToSelector:@selector(libraryController:willShowContextMenu:forObject:)])
	{
		[delegate libraryController:self.libraryController willShowContextMenu:menu forObject:inObject];
	}
	
	return menu;
}


- (IBAction) openInSourceApp:(id)inSender
{
	IMBObject* object = (IMBObject*) [inSender representedObject];
	NSString* path = [object path];
	NSString* app = nil;
	
	if ([object.parser respondsToSelector:@selector(appPath)])
	{
		app = [object.parser performSelector:@selector(appPath)];
	}
	
	[[NSWorkspace imb_threadSafeWorkspace] openFile:path withApplication:app];
}


- (IBAction) openInEditorApp:(id)inSender
{
	NSString* app = [IMBConfig editorAppForMediaType:self.mediaType];
	NSString* path = (NSString*)[inSender representedObject];
	[[NSWorkspace imb_threadSafeWorkspace] openFile:path withApplication:app];
}


- (IBAction) openInViewerApp:(id)inSender
{
	NSString* app = [IMBConfig viewerAppForMediaType:self.mediaType];
	NSString* path = (NSString*)[inSender representedObject];
	[[NSWorkspace imb_threadSafeWorkspace] openFile:path withApplication:app];
}


- (IBAction) openInApp:(id)inSender
{
	NSString* path = (NSString*)[inSender representedObject];
	[[NSWorkspace imb_threadSafeWorkspace] openFile:path];
}


- (IBAction) download:(id)inSender
{
	IMBParser* parser = self.currentNode.parser;
	NSArray* objects = [ibObjectArrayController selectedObjects];
	IMBObjectsPromise* promise = [parser objectPromiseWithObjects:objects];
	[promise setDelegate:self completionSelector:@selector(_postProcessDownload:)];
    [promise start];
}


- (IBAction) openInBrowser:(id)inSender
{
	NSURL* url = (NSURL*)[inSender representedObject];
	[[NSWorkspace imb_threadSafeWorkspace] openURL:url];
}


- (IBAction) revealInFinder:(id)inSender
{
	NSString* path = (NSString*)[inSender representedObject];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace imb_threadSafeWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


- (IBAction) openSubNode:(id)inSender
{
	IMBNode* node = (IMBNode*)[inSender representedObject];
	[_nodeViewController expandSelectedNode];
	[_nodeViewController selectNode:node];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Opening

// Open the selected objects...

- (IBAction) openSelectedObjects:(id)inSender
{
	IMBNode* node = self.currentNode;
	NSArray* objects = [ibObjectArrayController selectedObjects];
	[self openObjects:objects inSelectedNode:node];
}


// Open the specified objects. Double-clicking opens the files (with the default app). Please note that 
// IMBObjects are first passed through an IMBObjectsPromise (which is returned by the parser), because 
// the resources to be opened may not yet be available. In this case the promise object loads them 
// asynchronously and calls _openLocalURLs: once the load has finished...
	

- (void) openObjects:(NSArray*)inObjects inSelectedNode:(IMBNode*)inSelectedNode
{
	if (inSelectedNode)
	{
		IMBParser* parser = inSelectedNode.parser;
		IMBObjectsPromise* promise = [parser objectPromiseWithObjects:inObjects];
		[promise setDelegate:self completionSelector:@selector(_openLocalURLs:)];
        [promise start];
	}
}


#pragma mark
#pragma mark Post-download action


// Post process.

- (void) _postProcessDownload:(IMBObjectsPromise*)inObjectsPromise
{
	if ([inObjectsPromise isKindOfClass:[NSError class]])	// overloaded... error object
	{
		[NSApp presentError:(NSError*)inObjectsPromise];
	}
}


// "Local" means that for whatever the object represents, opening it now requires no network or other time-intensive
// procedure to obtain the usable object content. The term "local" is slightly misleading when it comes to
// IMBObjects that refer strictly to a web link, where "opening" them just means loading them in a browser...

- (void) _openLocalURLs:(IMBObjectsPromise*)inObjectPromise
{
	if ([inObjectPromise isKindOfClass:[NSError class]])	// overloaded... error object
	{
		[NSApp presentError:(NSError*)inObjectPromise];
	}
	else
	{
		[self _postProcessDownload:inObjectPromise];		// first do our post-processing
		
		for (NSURL* url in inObjectPromise.fileURLs)
		{
			// In case of an error getting a URL, the promise may have put an NSError in the stack instead
			
			if ([url isKindOfClass:[NSURL class]])
			{
				NSString* appPath = [IMBConfig editorAppForMediaType:self.mediaType];
				if (appPath == nil) appPath = [IMBConfig viewerAppForMediaType:self.mediaType];

				if ([self writesLocalFilesToPasteboard] && appPath != nil)
				{
					[[NSWorkspace imb_threadSafeWorkspace] openFile:url.path withApplication:appPath];
				}
				else
				{
					[[NSWorkspace imb_threadSafeWorkspace] openURL:url];
				}
			}
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Dragging


// By default all object view controllers manage objects which correspond to local file URLs when dragged or copied to pasteboard.

- (BOOL) writesLocalFilesToPasteboard
{
	return YES;
}

// Finish promise, from "dumb" applications that handle NSFilesPromisePboardType

- (void) draggedImage:(NSImage*)inImage endedAt:(NSPoint)inScreenPoint operation:(NSDragOperation)inOperation
{
	if (self.dropDestinationURL)		// is this finishing a promise drag?  This is when we want to load it.
	{
		// Resolve any promise
		[self _downloadDraggedObjectsToDestination:self.dropDestinationURL];
		self.dropDestinationURL = nil;
	}

	_isDragging = NO;
}

// On 10.6 and later, we provide multiple URLs with lazy provision, using NSPasteboardItems
// (<NSPasteboardItemDataProvider> protocol compliance)
- (void)pasteboard:(NSPasteboard *)inPasteboard item:(NSPasteboardItem *)inItem provideDataForType:(NSString *)inType
{
	// We rely on the NSPasteboardItem allocator to only register us as the callback for one or the other types,
	// depending no whether the NSURL in question is expected to be a file URL or not.
	if (([inType isEqualToString:(NSString*)kUTTypeURL]) || 
		([inType isEqualToString:(NSString*)kUTTypeFileURL]))
	{	
		// Get the index out of the pasteboard item, and map it back to our real object
		NSString* indexString = [inItem stringForType:kIMBPrivateItemIndexPasteboardType];
		if (indexString != nil)
		{
			UInt32 itemIndex = [indexString integerValue];
			NSArray *arrangedObjects = [ibObjectArrayController arrangedObjects];
			if ([arrangedObjects count])
			{
				IMBObject* mappedObject = [arrangedObjects objectAtIndex:itemIndex];
				if (mappedObject != nil)
				{
					// Use our promise object to load the content
					IMBObjectsPromise* promise = [IMBObjectsPromise promiseFromPasteboard:inPasteboard];
					
					// Make sure we got a promise, AND check that there are actually some items to download,
					// before we actually try to start downloading.
					if (promise != nil && [promise.objects count] > 0)
					{
						promise.destinationDirectoryPath = nil;	// only download (to temporary directory) if needed.
						[promise setDelegate:self completionSelector:@selector(_postProcessDownload:)];
                        [promise start];
						[promise waitUntilFinished];
						
						NSURL* thisURL = [promise fileURLForObject:mappedObject];
						if ((thisURL != nil) && ([thisURL isKindOfClass:[NSURL class]]))
						{
							// public.url is documented as containing the "bytes of the URL"
							[inItem setData:[[thisURL absoluteString] dataUsingEncoding:NSUTF8StringEncoding] forType:inType];
						}
					}
				}
			}
		}
	}
}


// 10.5 API.
// Gets called by ClearContents and declareTypes:owner: and ... ?

- (void)pasteboardFinishedWithDataProvider:(NSPasteboard *)pasteboard
{
	// NSLog(@"%s", __FUNCTION__);		// Do we want to do anything here? Clear out drag pasteboard contents?
}


// 10.5 API:
// Even dumber are apps that do not support NSFilesPromisePboardType, but only know about NSFilenamesPboardType.
// In this case we'll download to the temp folder and block synchronously until the download has completed...
//
// This requires there to be an iMBObjectPromise on the pasteboard; we use that to extract the other information requested.

- (void) pasteboard:(NSPasteboard*)inPasteboard provideDataForType:(NSString*)inType
{
	// NSLog(@"%s:%@", __FUNCTION__, inType);
	IMBObjectsPromise* promise = [IMBObjectsPromise promiseFromPasteboard:inPasteboard];
    
	promise.destinationDirectoryPath = nil;	// only download (to temporary directory) if needed.
	[promise setDelegate:self completionSelector:@selector(_postProcessDownload:)];
    [promise start];
	[promise waitUntilFinished];

	if ([promise.fileURLs count] > 0)
	{
		if (/*_isDragging == NO &&*/ [inType isEqualToString:NSFilenamesPboardType])
		{
			// Every URL will be able to provide a path, we'll leave it to the destination to decide
			// whether it can make any use of it or not.
			
			// In case there were NSError objects in the localURLs array, we want to ignore them. So we'll
			// go through each item and try to get a path out ...
			NSMutableArray* localPaths = [NSMutableArray arrayWithCapacity:promise.fileURLs.count];
			for (NSURL* thisObject in promise.fileURLs)
			{
				if ([thisObject isKindOfClass:[NSURL class]])
				{
					[localPaths addObject:thisObject.path];
				}
			}
			[inPasteboard setPropertyList:localPaths forType:NSFilenamesPboardType];
		}
		else if (([inType isEqualToString:NSURLPboardType]) ||
				 ([inType isEqualToString:(NSString*)kUTTypeURL]
				 || 
				 [inType isEqualToString:@"CorePasteboardFlavorType 0x6675726C"]))
		{
			// The best we can do for URL type on 10.5 is to provide the URL for the first item in our list. In case
			// thereare NSError objects in the list, we'll go through until we find an actual URL, and use that 
			// as the item for the pasteboard			
			NSURL* thisURL = nil;
			for (NSURL* thisObject in promise.fileURLs)
			{
				if ([thisObject isKindOfClass:[NSURL class]])
				{
					thisURL = thisObject;
					break;
				}
			}
			
			if (thisURL != nil)
			{
				if ([inType isEqualToString:NSURLPboardType])
				{
					[thisURL writeToPasteboard:inPasteboard];			
				}
				else
				{
					[inPasteboard setData:[[thisURL absoluteString] dataUsingEncoding:NSUTF8StringEncoding] forType:inType];
				}
			}
		}
	}
}


- (void) _downloadDraggedObjectsToDestination:(NSURL*)inDestination
{
	IMBNode* node = self.currentNode;
	
	if (node)
	{
		IMBParser* parser = node.parser;
		NSArray *arrangedObjects = [ibObjectArrayController arrangedObjects];
		NSArray *objects = [arrangedObjects objectsAtIndexes:self.draggedIndexes];
		IMBObjectsPromise* promise = [parser objectPromiseWithObjects:objects];
		promise.destinationDirectoryPath = [inDestination path];
		
		[promise setDelegate:self completionSelector:@selector(_postProcessDownload:)];
        [promise start];
	}
}

- (NSArray*) _namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination
{
	NSFileManager *fileManager = [NSFileManager imb_threadSafeManager];
	NSString *dropDestPath = [inDropDestination path];
	NSArray *arrangedObjects = [ibObjectArrayController arrangedObjects];
	NSArray *objects = [arrangedObjects objectsAtIndexes:self.draggedIndexes];
	NSMutableArray* names = [NSMutableArray array];
	
	for (IMBObject* object in objects)
	{
		NSString *path = [object path];
		if (path)
		{
			NSString* name = [[object path] lastPathComponent];
			NSString *base = [name stringByDeletingPathExtension];
			NSString *ext = [name pathExtension];
			NSString *newPath = [fileManager imb_generateUniqueFileNameAtPath:dropDestPath base:base extension:ext];
			name = [newPath lastPathComponent];
			
			[names addObject:name];
		}
	}
	
	return names;
}


// SpeedLimit http://mschrag.github.com/ is a good way to debug this....

- (void) objectsPromise:(IMBObjectsPromise*)inObjectPromise didProgress:(double)inFraction;
{
    if (!self.progressWindowController)
    {
        IMBProgressWindowController* controller = [[[IMBProgressWindowController alloc] init] autorelease];
        
        NSString* title = NSLocalizedStringWithDefaultValue(
                                                            @"IMBObjectViewController.progress.title",
                                                            nil,IMBBundle(),
                                                            @"Downloading Media Files",
                                                            @"Window title of progress panel of IMBObjectViewController");
        
        NSString* message = NSLocalizedStringWithDefaultValue(
                                                              @"IMBObjectViewController.progress.message.preparing",
                                                              nil,IMBBundle(),
                                                              @"Preparing…",
                                                              @"Text message in progress panel of IMBObjectViewController");
        
        // Make sure the window is at a higher window level than our view's window, so it doesn't get hidden
        [[controller window] setLevel:[[[self view] window] level] + 1];
        
        [controller setTitle:title];
        [controller setMessage:message];
        [controller.progressBar startAnimation:nil];
        [controller setCancelTarget:inObjectPromise];
        [controller setCancelAction:@selector(cancel:)];
        [controller.cancelButton setEnabled:YES];
        [controller.window makeKeyAndOrderFront:nil];
        
        self.progressWindowController = controller;
    }
    
	[self.progressWindowController setProgress:inFraction];
	[self.progressWindowController setMessage:@""];
	[self.progressWindowController.cancelButton setEnabled:YES];
}


- (void) objectsPromiseDidFinish:(IMBObjectsPromise*)inObjectPromise
{
	self.progressWindowController = nil;
}



//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserDelegate


- (void) imageBrowserSelectionDidChange:(IKImageBrowserView*)inView
{
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		Class panelClass = NSClassFromString(@"QLPreviewPanel");
		QLPreviewPanel* panel = [panelClass sharedPreviewPanel];
		
		if (panel.dataSource == (id)self)
		{
			[panel reloadData];
			[panel refreshCurrentPreviewItem];
		}
	}
}


// First give the delegate a chance to handle the double click. It it chooses not to, then we will 
// handle it ourself by simply opening the files (with their default app)...

- (void) imageBrowser:(IKImageBrowserView*)inView cellWasDoubleClickedAtIndex:(NSUInteger)inIndex
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = self.delegate;
	BOOL didHandleEvent = NO;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(libraryController:didDoubleClickSelectedObjects:inNode:)])
		{
			IMBNode* node = self.currentNode;
			NSArray* objects = [ibObjectArrayController selectedObjects];
			didHandleEvent = [delegate libraryController:controller didDoubleClickSelectedObjects:objects inNode:node];
		}
	}
	
	if (!didHandleEvent && inIndex != NSNotFound)
	{
		NSArray* objects = [ibObjectArrayController arrangedObjects];
		IMBObject* object = [objects objectAtIndex:inIndex];
		
		if ([object isKindOfClass:[IMBNodeObject class]])
		{
			IMBNode* subnode = (IMBNode*)object.location;
			[_nodeViewController expandSelectedNode];
			[_nodeViewController selectNode:subnode];
		}
		else if ([object isKindOfClass:[IMBButtonObject class]])
		{
			[(IMBButtonObject*)object sendDoubleClickAction];
		}
		else
		{
			[self openSelectedObjects:inView];
		}	
	}	
}


//----------------------------------------------------------------------------------------------------------------------


// Since IKImageBrowserView doesn't support context menus out of the box, we need to display them manually in 
// the following two delegate methods. Why couldn't Apple take care of this?

- (void) imageBrowser:(IKImageBrowserView*)inView backgroundWasRightClickedWithEvent:(NSEvent*)inEvent
{
	NSMenu* menu = [self menuForObject:nil];
	[NSMenu popUpContextMenu:menu withEvent:inEvent forView:inView];
}


- (void) imageBrowser:(IKImageBrowserView*)inView cellWasRightClickedAtIndex:(NSUInteger)inIndex withEvent:(NSEvent*)inEvent
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inIndex];
	NSMenu* menu = [self menuForObject:object];
	[NSMenu popUpContextMenu:menu withEvent:inEvent forView:inView];
}


//----------------------------------------------------------------------------------------------------------------------


// Here we sort of mimic the IKImageBrowserDataSource protocol, even though we really don't really
// implement the protocol, since we use bindings.  But this is for the benefit of
// -[IMBImageBrowserView mouseDragged:] ... I hope it's OK that we are ignoring the aBrowser parameter.

- (id /*IKImageBrowserItem*/) imageBrowser:(IKImageBrowserView*)inView itemAtIndex:(NSUInteger)inIndex
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inIndex];
	return object;
}


//----------------------------------------------------------------------------------------------------------------------

// Filter the dragged indexes to only include the selectable (and thus draggable) ones.

- (NSIndexSet*) filteredDraggingIndexes:(NSIndexSet*)inIndexes
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	
	NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
	NSUInteger index = [inIndexes firstIndex];
	
	while (index != NSNotFound)
	{
		IMBObject* object = [objects objectAtIndex:index];
		if ([object isSelectable]) [indexes addIndex:index];
		index = [inIndexes indexGreaterThanIndex:index];
	}
	
	return indexes;
}


// Encapsulate all dragged objects in a promise, archive it and put it on the pasteboard. The client can then
// start loading the objects in the promise and iterate over the resulting files...
//
// This method is used for both imageBrowser:writeItemsAtIndexes:toPasteboard: and tableView:writeRowsWithIndexes:toPasteboard:


- (NSUInteger) writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard
{
	IMBNode* node = self.currentNode;
	NSUInteger itemsWritten = 0;
	
	if (node)
	{
		NSIndexSet* indexes = [self filteredDraggingIndexes:inIndexes]; 
		NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:indexes];
		
		if ([objects count] > 0)
		{
			IMBParser* parser = node.parser;

			// Promise data for all of the objects being dragged. (In 10.6, each index will be extracted one-by-one.)
			IMBObjectsPromise* promise = [parser objectPromiseWithObjects:objects];
			if ([promise.objects count] > 0)	// if not downloadable, these won't appear in objects list
			{
				NSData* promiseData = [NSKeyedArchiver archivedDataWithRootObject:promise];
				
				NSArray* declaredTypes = nil;
				
				// We currently use a mix of 10.5 and 10.6 style pasteboard behaviors.
				//
				// 10.6 affords us the opportunity to write multiple items on the pasteboard at once, 
				// which is ideal especially when we are writing URLs, for which there was no sanctioned 
				// method of writing multiple to the pasteboard in 10.5.
				//
				// Because the 10.6 method of providing a list of filenames is also provide a list of URLs,
				// it means we can fill both cases in 10.6 by simply providing URLs. But in order to promise
				// URLs lazily we have to set an array of NSPasteboardItem on the pasteboard, with each item 
				// set to callback to us as data provider.
				//
				//
				//  NOTE: FOR NOW, WE ARE SHORT-CIRCUITING THIS BRANCH, AND NOT DOING ANY 10.6 PASTEBOARD WORK.
				//  WE MAY WANT TO REVISIT THIS WHEN WE HAVE A 10.6-ONLY API.
				//
				if (NO && IMBRunningOnSnowLeopardOrNewer())
				{				
					(void) [inPasteboard clearContents];
					NSMutableArray* itemArray = [NSMutableArray arrayWithCapacity:[indexes count]];
					
					// Create an array of NSPasteboardItem, each with a promise to fulfill data in the provider callback
					NSUInteger thisIndex = [indexes firstIndex];
					while (thisIndex != NSNotFound)
					{
						IMBObject* thisObject = [[ibObjectArrayController arrangedObjects] objectAtIndex:thisIndex];
						if (thisObject != nil)
						{
							// Allocate class indirectly since we compiling against the 10.5 SDK, not the 10.6
							NSPasteboardItem* thisItem = [[[NSClassFromString(@"NSPasteboardItem") alloc] init] autorelease];
							
							// We need to be declare kUTTypeFileURL in order to get file drags to work as expected to e.g. the Finder,
							// but we have to be careful not to declare kUTTypeFileURL for e.g. bookmark URLs. We might want to put this 
							// in the objects themself, but for now to get things working let's consult a method on ourselves that subclasses
							// can override if they don't create file URLs.
							NSArray* whichTypes = nil;
							if ([self writesLocalFilesToPasteboard])	// are we putting references to the files on the pasteboard?
							{
								whichTypes = [NSArray arrayWithObjects:(NSString*)kUTTypeURL,(NSString*)kUTTypeFileURL,nil];
							}
							else
							{
								whichTypes = [NSArray arrayWithObjects:(NSString*)kUTTypeURL,nil];
							}
							
							[thisItem setDataProvider:self forTypes:whichTypes];
							[thisItem setString:[NSString stringWithFormat:@"%d", thisIndex] forType:kIMBPrivateItemIndexPasteboardType];
							[thisItem setString:thisObject.name forType:kIMBPublicTitleListPasteboardType];
							[thisItem setPropertyList:thisObject.metadata forType:kIMBPublicMetadataListPasteboardType];
							[thisItem setData:promiseData forType:kIMBPasteboardTypeObjectsPromise];
							[itemArray addObject:thisItem];
						}
						
						thisIndex = [indexes indexGreaterThanIndex:thisIndex];
					}
					
					[inPasteboard writeObjects:itemArray];			// write array of NSPasteboardItems.
				}
				else
				{
					// On 10.5, we vend the object promise as well as promises for filenames and a URL.
					// We don't manually set NSFilenamesPboardType or NSURLPboardType, so we'll be asked to provide
					// concrete filenames or a single URL in the callback pasteboard:provideDataForType:
					NSMutableArray *fileTypes = [NSMutableArray array];
					NSMutableArray *titles = [NSMutableArray array];
					NSMutableArray *metadatas = [NSMutableArray array];
					
					if ([self writesLocalFilesToPasteboard])
					{
						// Try declaring promise AFTER the other types
						declaredTypes = [NSArray arrayWithObjects:kIMBPasteboardTypeObjectsPromise,NSFilesPromisePboardType,NSFilenamesPboardType, 
										 
										 // Also our own special metadata types that clients can make use of
										 kIMBPublicTitleListPasteboardType, kIMBPublicMetadataListPasteboardType,
										 
										 nil]; 
						// Used to be this. Any advantage to having both?  [NSArray arrayWithObjects:kIMBPasteboardTypeObjectsPromise,NSFilenamesPboardType,nil]
						
						NSUInteger thisIndex = [indexes firstIndex];
						while (thisIndex != NSNotFound)
						{
							IMBObject *object = [[ibObjectArrayController arrangedObjects] objectAtIndex:thisIndex];
							NSString *path = [object path];
							NSString *type = [path pathExtension];
							if ( [type length] == 0  )	type = NSFileTypeForHFSTypeCode( kDragPseudoFileTypeDirectory );	// type is a directory
							if (object.metadata && object.name)
							{
								// Keep all 3 items in sync, so the arrays are of the same length.
								[fileTypes addObject:type];
								[titles addObject:object.name];
								[metadatas addObject:object.metadata];								
							}
							
							thisIndex = [indexes indexGreaterThanIndex:thisIndex];
						}
					}
					else
					{
						declaredTypes = [NSArray arrayWithObjects:kIMBPasteboardTypeObjectsPromise,NSURLPboardType,kUTTypeURL,nil];
					}
					
					[inPasteboard declareTypes:declaredTypes owner:self];
					[inPasteboard setData:promiseData forType:kIMBPasteboardTypeObjectsPromise];
					if ([fileTypes count])
					{
						BOOL wasSet = NO;
						wasSet = [inPasteboard setPropertyList:fileTypes forType:NSFilesPromisePboardType];
						if (!wasSet) NSLog(@"Could not set pasteboard type %@ to be %@", NSFilesPromisePboardType, fileTypes);
						wasSet = [inPasteboard setPropertyList:titles forType:kIMBPublicTitleListPasteboardType];
						if (!wasSet) NSLog(@"Could not set pasteboard type %@ to be %@", kIMBPublicTitleListPasteboardType, titles);
						wasSet = [inPasteboard setPropertyList:metadatas forType:kIMBPublicMetadataListPasteboardType];
						if (!wasSet) NSLog(@"Could not set pasteboard type %@ to be %@", kIMBPublicMetadataListPasteboardType, metadatas);

//						#ifdef DEBUG
//						NSLog(@"Titles on pasteboard: %@", titles);
//						NSLog(@"MetaData on pasteboard: %@", metadatas);
//						#endif
					}
				}
				
				_isDragging = YES;
				itemsWritten = objects.count;
			}
		}
	}
	
	return itemsWritten;	
}

// IKImageBrowserDataSource method. Calls down to our support method used by combo view and browser view.

- (NSUInteger) imageBrowser:(IKImageBrowserView*)inView writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard
{
	return [self writeItemsAtIndexes:inIndexes toPasteboard:inPasteboard];
}


//----------------------------------------------------------------------------------------------------------------------


// If the IKImageBrowserView asked for a custom cell class, then pass on the request to the library's delegate. 
// That way the application is given a chance to customize the look of the browser...

- (Class) imageBrowserCellClassForController:(IMBObjectViewController*)inController
{
	id delegate = self.delegate;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(imageBrowserCellClassForController:)])
		{
			return [delegate imageBrowserCellClassForController:self];
		}
	}
	
	return nil;
}


// With this method the delegate can return a custom drag image for a drags starting from the IKImageBrowserView...

- (NSImage*) draggedImageForController:(IMBObjectViewController*)inController draggedObjects:(NSArray*)inObjects
{
	id delegate = self.delegate;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(draggedImageForController:draggedObjects:)])
		{
			return [delegate draggedImageForController:self draggedObjects:inObjects];
		}
	}
	
	return nil;
}


// For dumb applications we have the Cocoa NSFilesPromisePboardType as a fallback. In this case we'll handle 
// the IMBObjectsPromise for the client and block it until all objects are loaded...

// THIS VARIATION IS FOR THE DRAG WE INITIATE FROM OUR CUSTOM IKIMAGEBROWSERVIEW SUBCLASS.

- (NSArray*) namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination
{
	self.draggedIndexes = [ibObjectArrayController selectionIndexes];
	self.dropDestinationURL = inDropDestination;		// remember so that when drag is finished
	NSArray *result = [self _namesOfPromisedFilesDroppedAtDestination:inDropDestination];
	return result;
}
// The drag will finish at draggedImage:endedAt:operation:


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTableViewDelegate


// If the object for the cell that we are about to display doesn't have any metadata yet, then load it lazily...
// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) tableView:(NSTableView*)inTableView willDisplayCell:(id)inCell forTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inRow];
	
	if (object.metadata == nil)
	{
		[object.parser loadMetadataForObject:object];
	}
	
	if ([inCell isKindOfClass:[IMBComboTextCell class]])
	{
		IMBComboTextCell* cell = (IMBComboTextCell*)inCell;
		
		if ([object isKindOfClass:[IMBMovieObject class]])
		{
			cell.imageRepresentation = (id) [(IMBMovieObject*)object posterFrame];
			cell.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
		}
		else
		{
			cell.imageRepresentation = object.imageRepresentation;
			cell.imageRepresentationType = object.imageRepresentationType;
		}
		
		cell.title = object.imageTitle;
		cell.subtitle = object.metadataDescription;
	}
}


//----------------------------------------------------------------------------------------------------------------------


// We do not allow any editing in the list or combo view...

- (BOOL) tableView:(NSTableView*)inTableView shouldEditTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	return NO;
}


// Check whether a particular row is selectable...

- (BOOL) tableView:(NSTableView*)inTableView shouldSelectRow:(NSInteger)inRow
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = [objects objectAtIndex:inRow];
	return [object isSelectable];
}


//- (BOOL) tableView:(NSTableView*)inTableView shouldTrackCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inColumn row:(NSInteger)inRow
//{
//	NSArray* objects = [ibObjectArrayController arrangedObjects];
//	IMBObject* object = [objects objectAtIndex:inRow];
//	return [object isSelectable];
//}


//----------------------------------------------------------------------------------------------------------------------


// Provide a tooltip for the row...

- (NSString*) tableView:(NSTableView*)inTableView toolTipForCell:(NSCell*)inCell rect:(NSRectPointer)inRect tableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow mouseLocation:(NSPoint)inMouseLocation
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = [objects objectAtIndex:inRow];
	return [object tooltipString];
}


- (BOOL) tableView:(NSTableView*)inTableView shouldShowCellExpansionForTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// Encapsulate all dragged objects iny a promise, archive it and put it on the pasteboard. The client can then
// start loading the objects in the promise and iterate over the resulting files...

- (BOOL) tableView:(NSTableView*)inTableView writeRowsWithIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard 
{
	if ([_clickedObject isDraggable])
	{
		return ([self writeItemsAtIndexes:inIndexes toPasteboard:inPasteboard] > 0);
	}
	
	return NO;
}


// For dumb applications we have the Cocoa NSFilesPromisePboardType as a fallback. In this case we'll handle 
// the IMBObjectsPromise for the client and block it until all objects are loaded...

- (NSArray*) tableView:(NSTableView*)inTableView namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination forDraggedRowsWithIndexes:(NSIndexSet*)inIndexes
{
	self.draggedIndexes = inIndexes;
	self.dropDestinationURL = inDropDestination;
	return [self _namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination];
}


//----------------------------------------------------------------------------------------------------------------------


// We pre-load the images in batches. Assumes that we only have one client table view.  If we were to add another 
// IMBDynamicTableView client, we would need to deal with this architecture a bit since we have ivars here about 
// which rows are visible.


- (void) dynamicTableView:(IMBDynamicTableView *)tableView changedVisibleRowsFromRange:(NSRange)oldVisibleRows toRange:(NSRange)newVisibleRows
{
	BOOL wantsThumbnails = [tableView wantsThumbnails];
	
	NSArray *newVisibleItems = [[ibObjectArrayController arrangedObjects] subarrayWithRange:newVisibleRows];
	NSMutableSet *newVisibleItemsSetRetained = [[NSMutableSet alloc] initWithArray:newVisibleItems];
	
	NSMutableSet *itemsNoLongerVisible	= [NSMutableSet set];
	NSMutableSet *itemsNewlyVisible		= [NSMutableSet set];
	
	[itemsNewlyVisible setSet:newVisibleItemsSetRetained];
	[itemsNewlyVisible minusSet:_observedVisibleItems];
	
	[itemsNoLongerVisible setSet:_observedVisibleItems];
	[itemsNoLongerVisible minusSet:newVisibleItemsSetRetained];

//	NSLog(@"old Rows: %@", ([_observedVisibleItems count] ? [_observedVisibleItems description] : @"--"));
//	NSLog(@"new rows: %@", ([newVisibleItems count] ? [newVisibleItems description] : @"--"));
//	NSLog(@"Newly visible: %@", ([itemsNewlyVisible count] ? [itemsNewlyVisible description] : @"--"));
//	NSLog(@"Now NOT visbl: %@", ([itemsNoLongerVisible count] ? [itemsNoLongerVisible description] : @"--"));
	
	// With items going away, stop observing  and lower their queue priority if they are still queued
	
    for (IMBObject* object in itemsNoLongerVisible)
	{
#ifdef DEBUG
//		NSLog(@"changedVis…:… REMOVE [%p:%@'%@' removeObs…:%p 4kp:imageRep…", object,[object class],[object name], self);
#endif
		[object removeObserver:self forKeyPath:kIMBObjectImageRepresentationProperty];
		[object removeObserver:self forKeyPath:kIMBPosterFrameProperty];
		
		NSArray *ops = [[IMBOperationQueue sharedQueue] operations];
		for (IMBObjectThumbnailLoadOperation* op in ops)
		{
			if ([op isKindOfClass:[IMBObjectThumbnailLoadOperation class]])
			{
				IMBObject* loadingObject = [op object];
				if (loadingObject == object)
				{
					//NSLog(@"Lowering priority of load of %@", loadingObject.name);
					[op setQueuePriority:NSOperationQueuePriorityVeryLow];		// re-prioritize lower
					break;
				}
			}
		}
    }
	
    // With newly visible items, observe them and kick off a request to load the image
	
    for (IMBObject* object in itemsNewlyVisible)
	{
		if ((wantsThumbnails && [object needsImageRepresentation])		// don't auto-load just by asking for imageRepresentation
			|| (nil == object.metadata))
		{
			// Check if it is already queued -- if it's there already, bump up priority & adjust operation flag
			
			IMBObjectThumbnailLoadOperation *foundOperation = nil;
			
			NSArray *ops = [[IMBOperationQueue sharedQueue] operations];
			for (IMBObjectThumbnailLoadOperation* op in ops)
			{
				if ([op isKindOfClass:[IMBObjectThumbnailLoadOperation class]])
				{
					IMBObject *loadingObject = [op object];
					if (loadingObject == object)
					{
						foundOperation = op;
						break;
					}
				}
			}
			
			if (foundOperation)
			{
				//NSLog(@"Raising priority of load of %@", [foundOperation object].name);
				
				NSUInteger operationMask = kIMBLoadMetadata;
				if (wantsThumbnails)
				{
					operationMask |= kIMBLoadThumbnail;
				}
				foundOperation.options |= operationMask;		// make sure we have the appropriate loading option set
				[foundOperation setQueuePriority:NSOperationQueuePriorityNormal];		// re-prioritize back to normal
			}
			else
			{
				if (wantsThumbnails)
				{
					[object loadThumbnail];	// make sure we load it, though it probably got loaded above
				}
				else
				{
					[object loadMetadata];
				}
			}
		}
		
		// Add observer always to balance
		
#ifdef DEBUG
//		NSLog(@"changedVis…:… _ADD__ [%p:%@'%@' addObs…:%p 4kp:imageRep…", object, [object class],[object name], self);
#endif

		[object addObserver:self forKeyPath:kIMBObjectImageRepresentationProperty options:0 context:(void*)ibComboView];
		[object addObserver:self forKeyPath:kIMBPosterFrameProperty options:0 context:(void*)ibComboView];
     }
	
	// Finally cache our old visible items set
	[_observedVisibleItems release];
    _observedVisibleItems = newVisibleItemsSetRetained;
}


//----------------------------------------------------------------------------------------------------------------------


// Doubleclicking a row opens the selected items. This may trigger a download if the user selected remote objects.
// First give the delefate a chance to handle the double click...

- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = controller.delegate;
	BOOL didHandleEvent = NO;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(libraryController:didDoubleClickSelectedObjects:inNode:)])
		{
			IMBNode* node = self.currentNode;
			NSArray* objects = [ibObjectArrayController selectedObjects];
			didHandleEvent = [delegate libraryController:controller didDoubleClickSelectedObjects:objects inNode:node];
		}
	}
	
	if (!didHandleEvent)
	{
		NSArray* objects = [ibObjectArrayController arrangedObjects];
		NSUInteger row = [(NSTableView*)inSender clickedRow];
		IMBObject* object = row!=-1 ? [objects objectAtIndex:row] : nil;
		
		if ([object isKindOfClass:[IMBNodeObject class]])
		{
			IMBNode* subnode = (IMBNode*)object.location;
			[_nodeViewController expandSelectedNode];
			[_nodeViewController selectNode:subnode];
		}
		else if ([object isKindOfClass:[IMBButtonObject class]])
		{
			[(IMBButtonObject*)object sendDoubleClickAction];
		}
		else
		{
			[self openSelectedObjects:inSender];
		}	
	}	
}


// Handle single clicks for IMBButtonObjects...

- (IBAction) tableViewWasClicked:(id)inSender
{
	// No-op; clicking is handled with more detail from the mouse operations.
	// However we want to make sure our window becomes key with a click.
	[[inSender window] makeKeyWindow];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QuickLook


// Toggle the visibility of the Quicklook panel...

- (IBAction) quicklook:(id)inSender
{
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		Class panelClass = NSClassFromString(@"QLPreviewPanel");

 		if ([panelClass sharedPreviewPanelExists] && [[panelClass sharedPreviewPanel] isVisible])
		{
			[[panelClass sharedPreviewPanel] orderOut:nil];
		} 
		else
		{
			QLPreviewPanel* panel = [panelClass sharedPreviewPanel];
			[panel makeKeyAndOrderFront:nil];
			[ibTabView.window makeKeyWindow];	// Important to make key event handling work correctly!
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook datasource methods...

- (NSInteger) numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel*)inPanel
{
	return ibObjectArrayController.selectedObjects.count;
}


- (id <QLPreviewItem>) previewPanel:(QLPreviewPanel*)inPanel previewItemAtIndex:(NSInteger)inIndex
{
	return [ibObjectArrayController.selectedObjects objectAtIndex:inIndex];
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook delegate methods...

- (BOOL) previewPanel:(QLPreviewPanel*)inPanel handleEvent:(NSEvent *)inEvent
{
	NSView* view = nil;
	
	if (_viewType == kIMBObjectViewTypeIcon)
		view = ibIconView;
	else if (_viewType == kIMBObjectViewTypeList)
		view = ibListView;
	else if (_viewType == kIMBObjectViewTypeCombo)
		view = ibComboView;

	if ([inEvent type] == NSKeyDown)
	{
		[view keyDown:inEvent];
		return YES;
	}
	else if ([inEvent type] == NSKeyUp)
	{
		[view keyUp:inEvent];
		return YES;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSRect) previewPanel:(QLPreviewPanel*)inPanel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)inItem
{
	NSInteger index = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:inItem];
	NSRect frame = NSZeroRect;
	NSView* view = nil;
	NSCell* cell = nil;
	
	if (index != NSNotFound)
	{
		if (_viewType == kIMBObjectViewTypeIcon)
		{
			frame = [ibIconView itemFrameAtIndex:index];
			view = ibIconView;
		}	
		else if (_viewType == kIMBObjectViewTypeList)
		{
			frame = [ibListView frameOfCellAtColumn:0 row:index];
			cell = [[[ibListView tableColumns] objectAtIndex:0] dataCellForRow:index];
			frame = [cell imageRectForBounds:frame];
			view = ibListView;
		}	
		else if (_viewType == kIMBObjectViewTypeCombo)
		{
			frame = [ibComboView frameOfCellAtColumn:0 row:index];
			cell = [[[ibComboView tableColumns] objectAtIndex:0] dataCellForRow:index];
			frame = [cell imageRectForBounds:frame];
			view = ibComboView;
		}	
	}

	if (view)
	{
		frame = [view convertRectToBase:frame];
		frame.origin = [view.window convertBaseToScreen:frame.origin];
	}

	return frame;
}


//----------------------------------------------------------------------------------------------------------------------


@end

