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


#pragma mark HEADERS

#import "IMBObjectViewController.h"
#import "IMBNodeViewController.h"
#import "IMBLibraryController.h"
#import "IMBConfig.h"
#import "IMBParserMessenger.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBNodeObject.h"
#import "IMBProgressWindowController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSView+iMedia.h"
#import "IMBDynamicTableView.h"
#import "IMBOperationQueue.h"
#import "IMBObjectThumbnailLoadOperation.h"
#import "IMBButtonObject.h"
#import "IMBComboTextCell.h"
#import "IMBImageBrowserCell.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kImageRepresentationKeyPath = @"arrangedObjects.imageRepresentation";
static NSString* kIMBObjectImageRepresentationKey = @"imageRepresentation";
static NSString* kObjectCountStringKey = @"objectCountString";
static NSString* kGlobalViewTypeKey = @"globalViewType";

// Keys to be used by delegate

NSString* const IMBObjectViewControllerSegmentedControlKey = @"SegmentedControl";	/* Segmented control for object view selection */


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableDictionary* sRegisteredObjectViewControllerClasses = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBObjectViewController ()

- (CALayer*) iconViewBackgroundLayer;
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

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectViewController

@synthesize libraryController = _libraryController;
@synthesize currentNode = _currentNode;

@synthesize objectArrayController = ibObjectArrayController;
@synthesize tabView = ibTabView;
@synthesize iconView = ibIconView;
@synthesize listView = ibListView;
@synthesize comboView = ibComboView;
@synthesize viewType = _viewType;
@synthesize iconSize = _iconSize;

@synthesize objectCountFormatSingular = _objectCountFormatSingular;
@synthesize objectCountFormatPlural = _objectCountFormatPlural;
@synthesize clickedObject = _clickedObject;
//@synthesize progressWindowController = _progressWindowController;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Subclass Factory


// This is a central registry for for subclasses to register themselves for their +load method. That way they
// can make their existance known to the base class...

+ (void) registerObjectViewControllerClass:(Class)inObjectViewControllerClass forMediaType:(NSString*)inMediaType
{
	@synchronized ([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		if (sRegisteredObjectViewControllerClasses == nil)
		{
			sRegisteredObjectViewControllerClasses = [[NSMutableDictionary alloc] init];
		}
		
		[sRegisteredObjectViewControllerClasses setObject:inObjectViewControllerClass forKey:inMediaType];
		
		[pool drain];
	}
}


// This factory method relies of the registry above. It creates an IMBObjectViewController for the mediaType
// of the given IMBLibraryController. The class of the subview is automatically chosen by mediaType...

+ (IMBObjectViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController
{
	// Create a viewController of appropriate class type...
	
	NSString* mediaType = inLibraryController.mediaType;
	Class objectViewControllerClass = [sRegisteredObjectViewControllerClasses objectForKey:mediaType];

    NSString* nibName = [objectViewControllerClass nibName];
    NSBundle* bundle = [objectViewControllerClass bundle];
	IMBObjectViewController* objectViewController = [[[objectViewControllerClass alloc] initWithNibName:nibName bundle:bundle] autorelease];
    
	// Load the view *before* setting the libraryController, so that outlets are set before we load the preferences...
    
	[objectViewController view];										
	objectViewController.libraryController = inLibraryController;		
	return objectViewController;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Customize Subclasses

// The following methods must be overridden in subclasses to define the identity of a subclass...

+ (NSString*) mediaType
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
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


// The cell class to be used in the image browser view (if not provided by the library controller's delegate).
// You may overwrite this method in subclasses to provide your own view specific cell IKImageBrowserCell class...

+ (Class) iconViewCellClass
{
	return nil;
}


// You may subclass this method to provide a custom image browser background layer. Keep in mind   
// though that a custom background layer provided by the delegate will always overrule this one...

+ (CALayer*) iconViewBackgroundLayer
{
	return nil;
}


// Delay in seconds when view is reloaded after imageRepresentations of IMBObjects have changed.
// Longer delays cause fewer reloads of the view, but provide less direct feedback...

+ (double) iconViewReloadDelay
{
	return 0.05;	// Delay in seconds
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Lifetime


- (id) initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle
{
	if (self = [super initWithNibName:inNibName bundle:inBundle])
	{
		self.objectCountFormatSingular = [[self class] objectCountFormatSingular];
		self.objectCountFormatPlural = [[self class] objectCountFormatPlural];
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) dealloc
{
    // Views from IB also have bindings with the object array controller and must be
    // unbound *before* the controller is deallocated
    
    [self unbindViews];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Cancel any scheduled messages...
	
	[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView];
	[NSObject cancelPreviousPerformRequestsWithTarget:ibListView];
	[NSObject cancelPreviousPerformRequestsWithTarget:ibComboView];

	// Remove ourself from the QuickLook preview panel...
	
	QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanel];
	if (panel.delegate == (id)self) panel.delegate = nil;
	if (panel.dataSource == (id)self) panel.dataSource = nil;
	
	// Stop observing the array...
	
	[ibObjectArrayController removeObserver:self forKeyPath:kImageRepresentationKeyPath];
	[ibObjectArrayController removeObserver:self forKeyPath:kArrangedObjectsKey];
	[ibObjectArrayController release];

	for (IMBObject* object in _observedVisibleItems)
	{
        if ([object isKindOfClass:[IMBObject class]])
		{
            [object removeObserver:self forKeyPath:kIMBObjectImageRepresentationKey];
        }
    }
	
    IMBRelease(_observedVisibleItems);
	
	// Other cleanup...

	IMBRelease(_libraryController);
	IMBRelease(_currentNode);
	IMBRelease(_clickedObject);
//	IMBRelease(_progressWindowController);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	self.objectArrayController.delegate = self;
	
	// Configure the object views...
	
	[self _configureIconView];
	[self _configureListView];
	[self _configureComboView];
	
	// Just naming an image file '*Template' is not enough. So we explicitly make sure that all images in the
	// NSSegmentedControl are templates, so that they get correctly inverted when a segment is highlighted...
	
	NSInteger n = [ibSegments segmentCount];
	NSSegmentedCell *cell = [ibSegments cell];

	for (NSInteger i=0; i<n; i++)
	{
		[[ibSegments imageForSegment:i] setTemplate:YES];
	}
	
	// Set accessibilility description for each segment...
	
	NSArray* segmentChildren = [NSAccessibilityUnignoredDescendant(ibSegments) accessibilityAttributeValue: NSAccessibilityChildrenAttribute];

	for (NSInteger i=0; i<n; i++)
	{
		NSInteger tag = [cell tagForSegment:i];
		NSString *axDesc = nil;
		
		switch (tag)
		{
			case kIMBObjectViewTypeIcon:
				axDesc = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.segment.grid",
					nil,IMBBundle(),
					@"Grid",
					@"segmented cell accessibilility description");
				break;
				
			case kIMBObjectViewTypeList:
				axDesc = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.segment.list",
					nil,IMBBundle(),
					@"List",
					@"segmented cell accessibilility description");
				break;
				
			case kIMBObjectViewTypeCombo:
				axDesc = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.segment.combo",
					nil,IMBBundle(),
					@"Combination",
					@"segmented cell accessibilility description");
				break;
				
			default:
				axDesc = @"";
				break;
		}
		
		[[segmentChildren objectAtIndex:i] accessibilitySetOverrideValue:axDesc forAttribute:NSAccessibilityDescriptionAttribute];
	}
	
	// Observe changes to object array...
	
	[ibObjectArrayController retain];
	[ibObjectArrayController addObserver:self forKeyPath:kArrangedObjectsKey options:0 context:(void*)kArrangedObjectsKey];
	[ibObjectArrayController addObserver:self forKeyPath:kImageRepresentationKeyPath options:NSKeyValueObservingOptionNew context:(void*)kImageRepresentationKeyPath];

	// For tooltip display, we pay attention to changes in the icon view's scroller clip view, because 
	// that will naturally indicate a change in visible items (unfortunately IKImageBrowserView's 
	// visibleItemIndexes attribute doesn't seem to be KVO compatible.

	NSScrollView* iconViewScroller = [ibIconView enclosingScrollView];
	NSClipView* clipView = [iconViewScroller contentView];
	
	if (iconViewScroller)
	{
		if ([clipView isKindOfClass:[NSClipView class]])
		{
			[[NSNotificationCenter defaultCenter] 
				addObserver:self 
				selector:@selector(iconViewVisibleItemsChanged:) 
				name:NSViewBoundsDidChangeNotification 
				object:clipView];
		}
	}

	// We need to save preferences before the app quits...
	
	[[NSNotificationCenter defaultCenter] 
		 addObserver:self 
		 selector:@selector(_saveStateToPreferences) 
		 name:NSApplicationWillTerminateNotification 
		 object:nil];
	
	// Observe changes by other controllers to global view type preference if we use global view type
	// so we can change our own view type accordingly
	
	if ([IMBConfig useGlobalViewType])
	{
		[IMBConfig addObserver:self forKeyPath:kGlobalViewTypeKey options:0 context:(void*)kGlobalViewTypeKey];
	}
	
	// After all has been said and done delegate may do additional setup on selected (sub)views
	
	if ([[self delegate] respondsToSelector:@selector(objectViewController:didLoadViews:)])
	{
		NSDictionary* views = [NSDictionary dictionaryWithObjectsAndKeys:ibSegments, IMBObjectViewControllerSegmentedControlKey, nil];
		[[self delegate] objectViewController:self didLoadViews:views];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Do not remove this method. It isn't called directly by the framework, but may be called by host applications...

- (void) unbindViews	
{
	// Tear down bindings *before* the window is closed. This avoids exceptions due to random deallocation order of 
	// top level objects in the nib file. Please note that we are unbinding ibIconView, ibListView, and ibComboView
	// separately in addition to self.view. This is necessary because NSTabView seems to be doing some kind of 
	// optimization where the views of invisible tabs are not really part of the window view hierarchy. However the 
	// view subtrees exist and do have bindings to the IMBObjectArrayController - which need to be torn down as well...
	
	[ibIconView imb_unbindViewHierarchy];
	[ibListView imb_unbindViewHierarchy];
	[ibComboView imb_unbindViewHierarchy];
	[self.view imb_unbindViewHierarchy];
	
    // Clear datasource and delegate, just in case views live longer than this controller...

    [ibIconView setDataSource:nil];
	[ibIconView setDelegate:nil];
	
	[ibListView setDataSource:nil];
    [ibListView setDelegate:nil];
	
    [ibComboView setDataSource:nil];
    [ibComboView setDelegate:nil];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Backend


- (void) setLibraryController:(IMBLibraryController*)inLibraryController
{
	id old = _libraryController;
	_libraryController = [inLibraryController retain];
	[old release];
	
	[self _loadStateFromPreferences];
}


// Returns the mediaType of our libraryController...

- (NSString*) mediaType
{
	return self.libraryController.mediaType;
}


// The delegate object is the same as the libraryController's delegate object. 
// As a convenience, cast to IMBObjectViewControllerDelegate...

- (id <IMBObjectViewControllerDelegate>) delegate
{
	return self.libraryController.delegate;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Persistence 


- (NSMutableDictionary*) _preferences
{
	return [IMBConfig prefsForClass:self.class];
}


- (void) _setPreferences:(NSMutableDictionary*)inDict
{
	[IMBConfig setPrefs:inDict forClass:self.class];
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
#pragma mark User Interface


- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)inChange context:(void*)inContext
{
	// If the array itself has changed then display the new object count...
	
	if (inContext == (void*)kArrangedObjectsKey)
	{
		[self willChangeValueForKey:kObjectCountStringKey];
		[self didChangeValueForKey:kObjectCountStringKey];
	}
	
	// If single thumbnails have changed (due to asynchronous loading) then trigger a reload of the icon or combo view...
	
	else if (inContext == (void*)kImageRepresentationKeyPath)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadIconView) object:nil];
		[self performSelector:@selector(_reloadIconView) withObject:nil afterDelay:[[self class] iconViewReloadDelay] inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	
	// The globally set view type in preferences was changed - adjust our own view type accordingly. Please note 
	// that we are not using setViewType: here as it would cause an endless recursion...
		
	else if (inContext == (void*)kGlobalViewTypeKey && [IMBConfig useGlobalViewType])
	{
		[self willChangeValueForKey:@"viewType"];
		_viewType = [[IMBConfig globalViewType] unsignedIntegerValue];
		[self didChangeValueForKey:@"viewType"];
	}
	
	// Find the row and reload it. Note that KVO notifications may be sent from a background thread (in this 
	// case, we know they will be) We should only update the UI on the main thread, and in addition, we use 
	// NSRunLoopCommonModes to make sure the UI updates when a modal window is up...
		
	else if (inContext == (void*)kIMBObjectImageRepresentationKey)
	{
		NSInteger row = [(IMBObject*)inObject index];
		if (row == NSNotFound) row = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:inObject];

		if (row != NSNotFound)
		{
			[ibComboView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		}
    }
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Subclasses can override these methods to configure or customize look & feel of the various object views...

- (void) _configureIconView
{
	// Make the IKImageBrowserView use our custom cell class. Please note that we check for the existence 
	// of the base class first, as it is un undocumented internal class on 10.5. In 10.6 it is always there...
	
	if ([ibIconView respondsToSelector:@selector(setCellClass:)] && NSClassFromString(@"IKImageBrowserCell"))
	{
		[ibIconView performSelector:@selector(setCellClass:) withObject:[IMBImageBrowserCell class]];
	}
	
	[ibIconView setAnimates:NO];

	if ([ibIconView respondsToSelector:@selector(setIntercellSpacing:)])
	{
		[ibIconView setIntercellSpacing:NSMakeSize(4.0,4.0)];
	}

	if ([ibIconView respondsToSelector:@selector(setBackgroundLayer:)])
	{
		[ibIconView setBackgroundLayer:[self iconViewBackgroundLayer]];
	}
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


// Give the library's delegate a chance to provide a custom background layer (>= 10.6 only)

- (CALayer*) iconViewBackgroundLayer
{
	id delegate = self.delegate;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(imageBrowserBackgroundLayerForController:)])
		{
			return [delegate imageBrowserBackgroundLayerForController:self];
		}
	}
	
	return [[self class ] iconViewBackgroundLayer];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


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


#pragma mark 

// Depending of the IMBConfig setting useGlobalViewType, the controller either uses a global state, or each
// controller keeps its own state. It is up to the application developer to choose a behavior...

- (void) setViewType:(NSUInteger)inViewType
{
	[self willChangeValueForKey:@"canUseIconSize"];
	_viewType = inViewType;
	[IMBConfig setGlobalViewType:[NSNumber numberWithUnsignedInteger:inViewType]];
	[self didChangeValueForKey:@"canUseIconSize"];
}


- (NSUInteger) viewType
{
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
	
//	NSSize size = [ibIconView cellSize];
//	IMBParser* parser = self.currentNode.parser;
//	
//	if ([parser respondsToSelector:@selector(didChangeIconSize:objectView:)])
//	{
//		[parser didChangeIconSize:size objectView:ibIconView];
//	}

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
	
	// If the node has an uninitialized count, or if we exist apart from a node view controller,
	// then consult our array controller directly.
	if ((count < 0) || (node == nil))
	{
		count = (NSInteger) [[ibObjectArrayController arrangedObjects] count];
	}
	
	NSString* format = count==1 ? self.objectCountFormatSingular : self.objectCountFormatPlural;
	return [NSString stringWithFormat:format,count];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (void) _reloadIconView
{
	if ([ibIconView.window isVisible])
	{
		// Remove all tool tips before we start the reload, because there is a narrow window during reload when we have
		// our old tooltips configured and they refer to OLD objects in the icon view. This is a window for crashing 
		// if the system attempts to communicate with the tooltip's owner which is being removed from the view...
		
		[ibIconView removeAllToolTips];

		[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView selector:@selector(reloadData) object:nil];
		[ibIconView performSelector:@selector(reloadData) withObject:nil afterDelay:[[self class] iconViewReloadDelay] inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

		// Items loading into the view will cause a change in the scroller's clip view, which will cause the tooltips
		// to be revised to suit only the current visible items...
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


#pragma mark 

// Please note that providing tooltips is WAY too expensive on 10.5 (possibly due to different internal 
// implementation of IKImageBrowserView). For this reason we disable tooltips on 10.5. Following up on  
// the rationale above, in March, 2011, I changed the method for tooltips in 10.6+ to take advantage of a 
// "visibleItemIndexes" attribute on IKImageBrowserView. This lets us be more conservative in our tooltip 
// configuration and only install tooltips for the visible items. This is great for e.g. photo collections 
// with thousands of items, but puts the responsibility on any code that changes the visible items to assure 
// that _updateTooltips gets called...

- (void) _updateTooltips
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__updateTooltips) object:nil];
	[self performSelector:@selector(__updateTooltips) withObject:nil afterDelay:0.1];
}

- (void) __updateTooltips
{
	[ibIconView removeAllToolTips];
	
	NSArray* objects = ibObjectArrayController.arrangedObjects;
	NSIndexSet* indexes = [ibIconView visibleItemIndexes];
	NSUInteger index = [indexes firstIndex];
	
	while (index != NSNotFound)
	{
		IMBObject* object = [objects objectAtIndex:index];
		NSRect rect = [ibIconView itemFrameAtIndex:index];
		[ibIconView addToolTipRect:rect owner:object userData:NULL];
		index = [indexes indexGreaterThanIndex:index];
	}
}

- (void) iconViewVisibleItemsChanged:(NSNotification*)inNotification
{
	[self _updateTooltips];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserDelegate


- (void) imageBrowserSelectionDidChange:(IKImageBrowserView*)inView
{
	QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanel];
	
	if (panel.dataSource == (id)self)
	{
		[panel reloadData];
		[panel refreshCurrentPreviewItem];
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
			[self expandNodeObject:(IMBNodeObject*)object];
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
// implement the protocol, since we use bindings. But this is for the benefit of
// -[IMBImageBrowserView mouseDragged:] ... I hope it's OK that we are ignoring the inView parameter.

- (id) imageBrowser:(IKImageBrowserView*)inView itemAtIndex:(NSUInteger)inIndex
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inIndex];
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


// IKImageBrowserDataSource method. Calls down to our support method also used by list and combo view...

- (NSUInteger) imageBrowser:(IKImageBrowserView*)inView writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard
{
	if ([self.clickedObject isDraggable])
	{
		return [self writeItemsAtIndexes:inIndexes toPasteboard:inPasteboard];
	}	
	
	return 0;
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
	
	return [[self class ] iconViewCellClass];
}


//----------------------------------------------------------------------------------------------------------------------


// With this method the delegate can return a custom drag image for a drags starting from the IKImageBrowserView...
/*
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
*/


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTableViewDelegate


// If the object for the cell that we are about to display doesn't have any metadata yet, then load it lazily.
// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) tableView:(NSTableView*)inTableView willDisplayCell:(id)inCell forTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inRow];
	NSString* columnIdentifier = [inTableColumn identifier];
	
	// If we are in combo view, then assign thumbnail, title, subd subtitle (metadataDescription). If they are
	// not available yet, then load them lazily (in that case we'll end up here again once they are available)...
	
	if ([inCell isKindOfClass:[IMBComboTextCell class]])
	{
		IMBComboTextCell* cell = (IMBComboTextCell*)inCell;
		cell.imageRepresentation = object.imageRepresentation;
		cell.imageRepresentationType = object.imageRepresentationType;
		cell.title = object.imageTitle;
		cell.subtitle = object.metadataDescription;
	}
	
	// If we are in list view and don't have metadata yet, then load it lazily. We'll end up here again once 
	// they are available...
	
	if ([columnIdentifier isEqualToString:@"size"] && ![object isKindOfClass:[IMBNodeObject class]])
	{
		if (object.metadata == nil)
		{
			[object loadMetadata];
		}
	}
	
	// Host app delegate may provide badge image here. In the list view the icon will be replaced in the NSImageCell...
	
	if ([[self delegate] respondsToSelector:@selector(objectViewController:badgeForObject:)])
	{
		CGImageRef badgeRef = [[self delegate] objectViewController:self badgeForObject:object];
			
		if ([inCell respondsToSelector:@selector(setBadge:)])
		{
			[inCell setBadge:badgeRef];
		}

		if ([columnIdentifier isEqualToString:@"icon"] && [inCell isKindOfClass:[NSImageCell class]])
		{
			if (badgeRef)
			{
				NSSize badgeSize = NSMakeSize(CGImageGetWidth(badgeRef), CGImageGetHeight(badgeRef));
				NSBitmapImageRep* bitmapImageRep = [[[NSBitmapImageRep alloc] initWithCGImage:badgeRef] autorelease];
				NSImage* badge = [[[NSImage alloc] initWithSize:badgeSize] autorelease];
				[badge addRepresentation:bitmapImageRep];
				
				[inCell setImage:badge];
			}
		}
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


- (BOOL) tableView:(NSTableView*)inTableView shouldTrackCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inColumn row:(NSInteger)inRow
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = [objects objectAtIndex:inRow];
	return [object isSelectable];
}


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
	if ([self.clickedObject isDraggable])
	{
		return ([self writeItemsAtIndexes:inIndexes toPasteboard:inPasteboard] > 0);
	}
	
	return NO;
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
		[object removeObserver:self forKeyPath:kIMBObjectImageRepresentationKey];
		
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

		[object addObserver:self forKeyPath:kIMBObjectImageRepresentationKey options:0 context:(void*)kIMBObjectImageRepresentationKey];
     }
	
	// Finally cache our old visible items set
	[_observedVisibleItems release];
    _observedVisibleItems = newVisibleItemsSetRetained;
}


//----------------------------------------------------------------------------------------------------------------------


// Doubleclicking a row opens the selected items. This may trigger a download if the user selected remote objects.
// First give the delegate a chance to handle the double click...

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
			[self expandNodeObject:(IMBNodeObject*)object];
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
#pragma mark IMBObjectArrayControllerDelegate


- (BOOL) objectArrayController:(IMBObjectArrayController*)inController filterObject:(IMBObject*)inObject
{
	id <IMBObjectViewControllerDelegate> delegate = [self delegate];
	
	switch (_objectFilter)
	{
		case kIMBObjectFilterBadge:

			return ([delegate respondsToSelector:@selector(objectViewController:badgeForObject:)] &&
					[delegate objectViewController:self badgeForObject:inObject] != nil);
			
		case kIMBObjectFilterNoBadge:

			return ([delegate respondsToSelector:@selector(objectViewController:badgeForObject:)] &&
					[delegate objectViewController:self badgeForObject:inObject] == nil);

		case kIMBObjectFilterAll:
		default:
		
			return YES;
	}
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
		if (inObject.isLocalFile)
		{
			NSString* path = [inObject path];
			NSFileManager *fileManager = [[NSFileManager alloc] init];
            
			if ([fileManager fileExistsAtPath:path])
			{
				// Open with editor app...
				
				if ((appPath = [IMBConfig editorAppForMediaType:self.mediaType]))
				{
					title = NSLocalizedStringWithDefaultValue(
						@"IMBObjectViewController.menuItem.openWithApp",
						nil,IMBBundle(),
						@"Open With %@",
						@"Menu item in context menu of IMBObjectViewController");
					
					appName = [fileManager displayNameAtPath:appPath];
					title = [NSString stringWithFormat:title,appName];	

					item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInEditorApp:) keyEquivalent:@""];
					[item setRepresentedObject:inObject];
					[item setTarget:self];
					[menu addItem:item];
					[item release];
				}
				
				// Open with viewer app...
				
				if ((appPath = [IMBConfig viewerAppForMediaType:self.mediaType]))
				{
					title = NSLocalizedStringWithDefaultValue(
						@"IMBObjectViewController.menuItem.openWithApp",
						nil,IMBBundle(),
						@"Open With %@",
						@"Menu item in context menu of IMBObjectViewController");
					
					appName = [fileManager displayNameAtPath:appPath];
					title = [NSString stringWithFormat:title,appName];	

					item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInViewerApp:) keyEquivalent:@""];
					[item setRepresentedObject:inObject];
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
					[item setRepresentedObject:inObject];
					[item setTarget:self];
					[menu addItem:item];
					[item release];
				}
				
				// Show in Finder...
				
				title = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.menuItem.revealInFinder",
					nil,IMBBundle(),
					@"Show in Finder",
					@"Menu item in context menu of IMBObjectViewController");
				
				item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
				[item setRepresentedObject:inObject];
				[item setTarget:self];
				[menu addItem:item];
				[item release];
			}
            
            [fileManager release];
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
	
	if ([inObject isSelectable] && [inObject previewItemURL] != nil)
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
	
	// Badges filtering
	
	if ([[self delegate] respondsToSelector:@selector(objectViewController:badgeForObject:)])
	{
		if ([menu numberOfItems] > 0)
		{
			[menu addItem:[NSMenuItem separatorItem]];
		}
			 
		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.showAll",
			nil,IMBBundle(),
			@"Show All",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(showFiltered:) keyEquivalent:@""];
		[item setTag:kIMBObjectFilterAll];
		[item setTarget:self];
		[item setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
        [item setState: _objectFilter == kIMBObjectFilterAll ? NSOnState : NSOffState];
		[menu addItem:item];
		[item release];

		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.showBadgedOnly",
			nil,IMBBundle(),
			@"Show Badged Only",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(showFiltered:) keyEquivalent:@""];
		[item setTag:kIMBObjectFilterBadge];
		[item setTarget:self];
		[item setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
        [item setState: _objectFilter == kIMBObjectFilterBadge ? NSOnState : NSOffState];
		[menu addItem:item];
		[item release];

		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.showUnbadgedOnly",
			nil,IMBBundle(),
			@"Show Unbadged Only",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(showFiltered:) keyEquivalent:@""];
		[item setTag:kIMBObjectFilterNoBadge];
		[item setTarget:self];
		[item setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
        [item setState: _objectFilter == kIMBObjectFilterNoBadge ? NSOnState : NSOffState];
		[menu addItem:item];
		[item release];
	}
	
	// Give the IMBParserMessenger a chance to add menu items...
	
	IMBParserMessenger* parserMessenger = self.currentNode.parserMessenger;
	
	if ([parserMessenger respondsToSelector:@selector(willShowContextMenu:forObject:)])
	{
		[parserMessenger willShowContextMenu:menu forObject:inObject];
	}
	
	// Give delegate a chance to add custom menu items...
	
	id delegate = self.delegate;
	
	if (delegate!=nil && [delegate respondsToSelector:@selector(libraryController:willShowContextMenu:forObject:)])
	{
		[delegate libraryController:self.libraryController willShowContextMenu:menu forObject:inObject];
	}
	
	return menu;
}


- (IBAction) openInEditorApp:(id)inSender
{
	NSString* appPath = [IMBConfig editorAppForMediaType:self.mediaType];
	IMBObject* object = (IMBObject*)[inSender representedObject];

	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			
			if (url)
			{
				if (appPath) [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:appPath];
				else [[NSWorkspace sharedWorkspace] openURL:url];
			}
		}
	}];
}


- (IBAction) openInViewerApp:(id)inSender
{
	NSString* appPath = [IMBConfig viewerAppForMediaType:self.mediaType];
	IMBObject* object = (IMBObject*)[inSender representedObject];

	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			
			if (url)
			{
				if (appPath) [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:appPath];
				else [[NSWorkspace sharedWorkspace] openURL:url];
			}
		}
	}];
}


- (IBAction) openInApp:(id)inSender
{
	IMBObject* object = (IMBObject*)[inSender representedObject];

	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			if (url) [[NSWorkspace sharedWorkspace] openURL:url];
		}
	}];
}


- (IBAction) download:(id)inSender
{
//	IMBParser* parser = self.currentNode.parser;
//	NSArray* objects = [ibObjectArrayController selectedObjects];
//	IMBObjectsPromise* promise = [parser objectPromiseWithObjects:objects];
//	[promise setDelegate:self completionSelector:@selector(_postProcessDownload:)];
//    [promise start];
}


- (IBAction) openInBrowser:(id)inSender
{
	NSURL* url = (NSURL*)[inSender representedObject];
	[[NSWorkspace imb_threadSafeWorkspace] openURL:url];
}


- (IBAction) revealInFinder:(id)inSender
{
	IMBObject* object = (IMBObject*)[inSender representedObject];
	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			NSString* path = [url path];
			NSString* folder = [path stringByDeletingLastPathComponent];
			[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
		}
	}];
}


- (IBAction) openSubNode:(id)inSender
{
//	IMBNode* node = (IMBNode*)[inSender representedObject];
//	[_nodeViewController expandSelectedNode];
//	[_nodeViewController selectNode:node];
}


- (IBAction) showFiltered:(id)inSender
{
//	ibObjectFilter = (IMBObjectFilter) [inSender tag];
//	[inSender setState:NSOnState];
//	[[self objectArrayController] rearrangeObjects];
//	[[self nodeViewController] setObjectContainerViewNeedsDisplay:YES];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Dragging


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
	NSIndexSet* indexes = [self filteredDraggingIndexes:inIndexes]; 
	NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:indexes];
	NSMutableArray* pasteboardItems = [NSMutableArray arrayWithCapacity:objects.count];
	NSArray* types = [NSArray arrayWithObjects:kIMBObjectPasteboardType,(NSString*)kUTTypeFileURL,nil];
	
	for (IMBObject* object in objects)
	{
		NSPasteboardItem* item = [[NSPasteboardItem alloc] init];
		[item setDataProvider:object forTypes:types];
		[pasteboardItems addObject:item];
		[item release];
	}
	
	[inPasteboard clearContents];
	[inPasteboard writeObjects:pasteboardItems];
	return pasteboardItems.count;


/*
	IMBNode* node = self.currentNode;
	NSUInteger itemsWritten = 0;
	NSIndexSet* indexes = [self filteredDraggingIndexes:inIndexes]; 
	NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:indexes];
	
	if (node)
	{
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
*/	
//	return itemsWritten;	
}


//----------------------------------------------------------------------------------------------------------------------


// SpeedLimit http://mschrag.github.com/ is a good way to debug this....

//- (void) objectsPromise:(IMBObjectsPromise*)inObjectPromise didProgress:(double)inFraction;
//{
//	IMBProgressWindowController *progressWindowController = [self progressWindowController];
//
//    if (!progressWindowController)
//    {
//        IMBProgressWindowController* controller = [[[IMBProgressWindowController alloc] init] autorelease];
//        
//        NSString* title = NSLocalizedStringWithDefaultValue(
//                                                            @"IMBObjectViewController.progress.title",
//                                                            nil,IMBBundle(),
//                                                            @"Downloading Media Files",
//                                                            @"Window title of progress panel of IMBObjectViewController");
//        
//        NSString* message = NSLocalizedStringWithDefaultValue(
//                                                              @"IMBObjectViewController.progress.message.preparing",
//                                                              nil,IMBBundle(),
//                                                              @"Preparing…",
//                                                              @"Text message in progress panel of IMBObjectViewController");
//        
//        // Make sure the window is at a higher window level than our view's window, so it doesn't get hidden
//        [[controller window] setLevel:[[[self view] window] level] + 1];
//        
//        [controller setTitle:title];
//        [controller setMessage:message];
//        [controller.progressBar startAnimation:nil];
//        [controller setCancelTarget:inObjectPromise];
//        [controller setCancelAction:@selector(cancel:)];
//        [controller.cancelButton setEnabled:YES];
//        [controller.window makeKeyAndOrderFront:nil];
//        
//        progressWindowController = self.progressWindowController = controller;
//    }
//    
//	[progressWindowController setProgress:inFraction];
//	[progressWindowController setMessage:@""];
//	[progressWindowController.cancelButton setEnabled:YES];
//}


//- (void) objectsPromiseDidFinish:(IMBObjectsPromise*)inObjectPromise
//{
//	[[self.progressWindowController window] orderOut:nil];
//	self.progressWindowController = nil;
//}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Open Media Files

// Double-clicking and IMBNodeObject (folder icon) in the object view expands and selects the represented node. 
// The result is that we are drilling into that "folder"...

- (void) expandNodeObject:(IMBNodeObject*)inNodeObject
{
	if ([inNodeObject isKindOfClass:[IMBNodeObject class]])
	{
		NSString* identifier = inNodeObject.representedNodeIdentifier;
		IMBNode* node = [self.libraryController nodeWithIdentifier:identifier];

		[[NSNotificationCenter defaultCenter] 
			postNotificationName:kIMBExpandAndSelectNodeWithIdentifierNotification 
			object:nil 
			userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				self,@"objectViewController",
				node,@"node",
				nil]];
	}
}


// Open the selected objects...

- (IBAction) openSelectedObjects:(id)inSender
{
	NSArray* objects = [ibObjectArrayController selectedObjects];
	[self openObjects:objects];
}


// Open the specified objects. Please note that in sandboxed applications (which usually do not have the necessary
// rights to access arbitrary media files) this requires an asynchronous round trip to an XPC service. Once we do
// get the bookmark, we can resolve it to a URL that we can access. Open it in the default app...
	

- (void) openObjects:(NSArray*)inObjects
{
	NSString* appPath = nil;
	if (appPath == nil) appPath = [IMBConfig editorAppForMediaType:self.mediaType];
	if (appPath == nil) appPath = [IMBConfig viewerAppForMediaType:self.mediaType];
	
	for (IMBObject* object in inObjects)
	{
		[object requestBookmarkWithCompletionBlock:^(NSError* inError)
		{
			if (inError)
			{
				[NSApp presentError:inError];
			}
			else
			{
				NSURL* url = [object URLByResolvingBookmark];
				
				if (url)
				{
					if (appPath != nil && [url isFileURL])
					{
						[[NSWorkspace imb_threadSafeWorkspace] openFile:url.path withApplication:appPath];
					}
					else
					{
						[[NSWorkspace imb_threadSafeWorkspace] openURL:url];
					}
				}
			}
		}];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QuickLook


// Toggle the visibility of the Quicklook panel...

- (IBAction) quicklook:(id)inSender
{
	if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
	{
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	} 
	else
	{
		QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanel];
		[panel makeKeyAndOrderFront:nil];
		[ibTabView.window makeKeyWindow];	// Important to make key event handling work correctly!
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook datasource methods...

- (NSInteger) numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel*)inPanel
{
	return ibObjectArrayController.selectedObjects.count;
}


- (id<QLPreviewItem>) previewPanel:(QLPreviewPanel*)inPanel previewItemAtIndex:(NSInteger)inIndex
{
	if (inIndex >= 0 && inIndex < ibObjectArrayController.selectedObjects.count)
	{
		return [ibObjectArrayController.selectedObjects objectAtIndex:inIndex];
	}
	
	return nil;
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

