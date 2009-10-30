/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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
#import "IMBObjectPromise.h"
#import "IMBImageBrowserCell.h"
#import "IMBProgressWindowController.h"
#import "IMBQuickLookController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "IMBDynamicTableView.h"
#import "IMBComboTextCell.h"
#import "IMBObject.h"
#import "IMBOperationQueue.h"
#import "IMBObjectThumbnailLoadOperation.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kImageRepresentationKeyPath = @"arrangedObjects.imageRepresentation";
static NSString* kObjectCountStringKey = @"objectCountString";

NSString *const kIMBObjectImageRepresentationProperty = @"imageRepresentation";


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
- (void) _reloadComboView;

- (void) _downloadSelectedObjectsToDestination:(NSURL*)inDestination;
- (NSArray*) _namesOfPromisedFiles;

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
@synthesize listView = ibListView;
@synthesize comboView = ibComboView;
@synthesize iconSize = _iconSize;

@synthesize objectCountFormatSingular = _objectCountFormatSingular;
@synthesize objectCountFormatPlural = _objectCountFormatPlural;


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
	// We need to save preferences before the app quits...
	
	[[NSNotificationCenter defaultCenter] 
	 addObserver:self 
	 selector:@selector(_saveStateToPreferences) 
	 name:NSApplicationWillTerminateNotification 
	 object:nil];
	
	// Observe changes to object array...
	
	[ibObjectArrayController retain];
	[ibObjectArrayController addObserver:self forKeyPath:kArrangedObjectsKey options:0 context:(void*)kArrangedObjectsKey];
	[ibObjectArrayController addObserver:self forKeyPath:kImageRepresentationKeyPath options:NSKeyValueObservingOptionNew context:(void*)kImageRepresentationKeyPath];
	
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
}


- (void) dealloc
{
	[ibObjectArrayController removeObserver:self forKeyPath:kImageRepresentationKeyPath];
	[ibObjectArrayController removeObserver:self forKeyPath:kArrangedObjectsKey];
	[ibObjectArrayController release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	IMBRelease(_libraryController);
	IMBRelease(_nodeViewController);
	IMBRelease(_progressWindowController);
	
	for (IMBObject* object in _observedVisibleItems)
	{
        if ([object isKindOfClass:[IMBObject class]])
		{
            [object removeObserver:self forKeyPath:kIMBObjectImageRepresentationProperty];
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
		//		[self _reloadIconView];
		[self willChangeValueForKey:kObjectCountStringKey];
		[self didChangeValueForKey:kObjectCountStringKey];
	}
	
	// If single thumbnails have changed (due to asynchronous loading) then trigger a reload of the IKIMageBrowserView...
	
	else if (inContext == (void*)kImageRepresentationKeyPath)
	{
//		id object = [inChange objectForKey:NSKeyValueChangeNewKey];
//		NSLog(@"%s %@",__FUNCTION__,inChange);
		[self _reloadIconView];
		[self _reloadComboView];
	}
	else if ([inKeyPath isEqualToString:kIMBObjectImageRepresentationProperty])
	{
        // Find the row and reload it.
        // Note that KVO notifications may be sent from a background thread (in this case, we know they will be)
        // We should only update the UI on the main thread, and in addition, we use NSRunLoopCommonModes to make sure the UI updates when a modal window is up.
		IMBDynamicTableView *affectedTableView = (IMBDynamicTableView *)inContext;
		NSInteger row = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:inObject];
		if (NSNotFound != row)
		{
			[affectedTableView performSelectorOnMainThread:@selector(_reloadRow:) withObject:[NSNumber numberWithInt:row] waitUntilDone:NO modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
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
	//	NSIndexSet* selectionIndexes = [ibObjectArrayController selectionIndexes];
	//	NSData* selectionData = [NSKeyedArchiver archivedDataWithRootObject:selectionIndexes];
	
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:[NSNumber numberWithUnsignedInteger:self.viewType] forKey:@"viewType"];
	[stateDict setObject:[NSNumber numberWithDouble:self.iconSize] forKey:@"iconSize"];
	//	[stateDict setObject:selectionData forKey:@"selectionData"];
	[self _setPreferences:stateDict];
}


- (void) _loadStateFromPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	self.viewType = [[stateDict objectForKey:@"viewType"] unsignedIntValue];
	self.iconSize = 0.15; //[[stateDict objectForKey:@"iconSize"] doubleValue];
	
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
}


- (void) _configureListView
{
	[ibListView setTarget:self];
	[ibListView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
    [ibListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [ibListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}


- (void) _configureComboView
{
	[ibComboView setTarget:self];
	[ibComboView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
    [ibComboView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [ibComboView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) willShowView
{
	// To be overridden by subclass...
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


// Availability of the icon size slide depends on the view type (e.g. not available in list view...

- (void) setViewType:(NSUInteger)inViewType
{
	[self willChangeValueForKey:@"canUseIconSize"];
	_viewType = inViewType;
	[self didChangeValueForKey:@"canUseIconSize"];
}

- (BOOL) canUseIconSize
{
	return self.viewType != kIMBObjectViewTypeList;
}


//----------------------------------------------------------------------------------------------------------------------


// When the icon size changes, get the current cell size in the IKImageBrowserView and notify the parser.
// This may be helpful for the parser so that it can supply larger thumbnails...

- (void) setIconSize:(double)inIconSize
{
	_iconSize = inIconSize;
	
	NSSize size = [ibIconView cellSize];
	IMBParser* parser = self.currentNode.parser;
	
	if ([parser respondsToSelector:@selector(objectViewDidChangeIconSize:)])
	{
		[parser objectViewDidChangeIconSize:size];
	}

	CGFloat height = 60.0 + 80.0 * _iconSize;
	[ibComboView setRowHeight:height];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) objectCountString
{
	NSUInteger count = [[ibObjectArrayController arrangedObjects] count];
	NSString* format = count==1 ? self.objectCountFormatSingular : self.objectCountFormatPlural;
	return [NSString stringWithFormat:format,count];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) _reloadIconView
{
	[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView selector:@selector(reloadData) object:nil];
	[ibIconView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}


- (void) _reloadComboView
{
	[NSObject cancelPreviousPerformRequestsWithTarget:ibComboView selector:@selector(reloadData) object:nil];
	[ibComboView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
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
	
	// Check if the object is a local file. If yes add appropriate standard menu items...
	
	if ([[inObject location] isKindOfClass:[NSString class]])
	{
		NSString* path = [inObject path];
		
		if ([[NSFileManager threadSafeManager] fileExistsAtPath:path])
		{
			NSString* appPath = nil;
			NSString* type = nil;
			BOOL found = [[NSWorkspace threadSafeWorkspace] getInfoForFile:path application:&appPath type:&type];
			
			// Open with <application>...
			
			if (found)
			{
				title = NSLocalizedStringWithDefaultValue(
														  @"IMBObjectViewController.menuItem.openInApp",
														  nil,IMBBundle(),
														  @"Open in %@",
														  @"Menu item in context menu of IMBObjectViewController");
				
				NSString* appName = [[NSFileManager threadSafeManager] displayNameAtPath:appPath];
				title = [NSString stringWithFormat:title,appName];	
			}
			else
			{
				title = NSLocalizedStringWithDefaultValue(
														  @"IMBObjectViewController.menuItem.openWithFinder",
														  nil,IMBBundle(),
														  @"Open with Finder",
														  @"Menu item in context menu of IMBObjectViewController");
			}
			
			item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInApp:) keyEquivalent:@""];
			[item setRepresentedObject:path];
			[item setTarget:self];
			[menu addItem:item];
			[item release];
			
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
	
	// URL object can be opened in a web browser...
	
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
												  @"Open in Browser",
												  @"Menu item in context menu of IMBObjectViewController");
		
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInBrowser:) keyEquivalent:@""];
		[item setRepresentedObject:[inObject location]];
		[item setTarget:self];
		[menu addItem:item];
		[item release];
	}
	
	//	// QuickLook...
	//	
	//	title = NSLocalizedStringWithDefaultValue(
	//		@"IMBObjectViewController.menuItem.quickLook",
	//		nil,IMBBundle(),
	//		@"Quicklook",
	//		@"Menu item in context menu of IMBObjectViewController");
	//		
	//	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(quicklook:) keyEquivalent:@""];
	//	[item setRepresentedObject:inObject];
	//	[item setTarget:self];
	//	[menu addItem:item];
	//	[item release];
	
	// Give parser a chance to add menu items...
	
	IMBParser* parser = self.currentNode.parser;
	
	if ([parser respondsToSelector:@selector(willShowContextMenu:forObject:)])
	{
		[parser willShowContextMenu:menu forObject:inObject];
	}
	
	// Give delegate a chance to add custom menu items...
	
	id delegate = self.delegate;
	
	if (delegate!=nil && [delegate respondsToSelector:@selector(controller:willShowContextMenu:forObject:)])
	{
		[delegate controller:self.libraryController willShowContextMenu:menu forObject:inObject];
	}
	
	return menu;
}


- (IBAction) openInApp:(id)inSender
{
	NSString* path = (NSString*)[inSender representedObject];
	[[NSWorkspace threadSafeWorkspace] openFile:path];
}


- (IBAction) download:(id)inSender
{
	IMBParser* parser = self.currentNode.parser;
	NSArray* objects = [ibObjectArrayController selectedObjects];
	IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
	[promise startLoadingWithDelegate:self finishSelector:nil];
}


- (IBAction) openInBrowser:(id)inSender
{
	NSURL* url = (NSURL*)[inSender representedObject];
	[[NSWorkspace threadSafeWorkspace] openURL:url];
}


- (IBAction) revealInFinder:(id)inSender
{
	NSString* path = (NSString*)[inSender representedObject];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace threadSafeWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


- (IBAction) openSubNode:(id)inSender
{
	IMBNode* node = (IMBNode*)[inSender representedObject];
	[_nodeViewController expandSelectedNode];
	[_nodeViewController selectNode:node];
}


//- (IBAction) quicklook:(id)inSender
//{
//	[[IMBQuickLookController sharedController] setDataSource:self];
//	[[IMBQuickLookController sharedController] toggle:nil];
//}


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


// Open the specified objects...

- (void) openObjects:(NSArray*)inObjects inSelectedNode:(IMBNode*)inSelectedNode
{
	IMBObject* firstObject = [inObjects count]>0 ? [inObjects objectAtIndex:0] : nil;
	
	// If this is a single IMBNodeObject, then expand the currently selected node and select the appropriate subnode...
	
	if ([firstObject isKindOfClass:[IMBNodeObject class]])
	{
		IMBNode* subnode = (IMBNode*)firstObject.location;
		[_nodeViewController expandSelectedNode];
		[_nodeViewController selectNode:subnode];
	}
	
	// Double-clicking opens the files (with the default app). Please note that IMBObjects are first passed through an 
	// IMBObjectPromise (which is returned by the parser), because the resources to be opened may not yet be available.
	// In this case the promise object loads them asynchronously and calls _openLocalURLs: once the load has finished...
	
	else if (inSelectedNode)
	{
		IMBParser* parser = inSelectedNode.parser;
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:inObjects];
		[promise startLoadingWithDelegate:self finishSelector:@selector(_openLocalURLs:withError:)];
	}
}

// "Local" means that for whatever the object represents, opening it now requires no network or 
// other time-intensive procedure to obtain the usable object content. The term "local" is slightly
// misleading when it comes to IMBObjects that refer strictly to a web link, where "opening" them 
// just means loading them in a browser.
- (void) _openLocalURLs:(IMBObjectPromise*)inObjectPromise withError:(NSError*)inError
{
	if (inError == nil)
	{
		for (NSURL* url in inObjectPromise.localURLs)
		{
			// In case of an error getting a URL, the promise may have put an NSError in the stack instead
			if ([url isKindOfClass:[NSURL class]])
			{
				[[NSWorkspace threadSafeWorkspace] openURL:url];
			}
		}
	}
	else
	{
		[NSApp presentError:inError];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QuickLook

//- (NSURL*) _urlForObject:(IMBObject*)inObject
//{
//	return [inObject url];
//}
//
//
//- (NSArray*) URLsForQuickLookController:(IMBQuickLookController*)inController
//{
//	NSMutableArray* urls = [NSMutableArray array];
//	
//	for (IMBObject* object in ibObjectArrayController.selectedObjects)
//	{
//		NSURL* url = [self _urlForObject:object];
//		if (url) [urls addObject:url];
//	}
//	
//	return urls;
//}
//
//
//- (NSRect) quickLookController:(IMBQuickLookController*)inController frameForURL:(NSURL*)inURL
//{
//	NSRect frame = NSZeroRect;
//	NSView* srcView = nil;
//	
//	for (IMBObject* object in ibObjectArrayController.selectedObjects)
//	{
// 		NSURL* url = [self _urlForObject:object];
//		
//		if ([url isEqual:inURL])
//		{
//			NSInteger index = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:object];
//
//			if (index != NSNotFound)
//			{
//				if (_viewType == kIMBObjectViewTypeIcon)
//				{
//					frame = [ibIconView itemFrameAtIndex:index];
//					srcView = ibIconView;
//				}	
//				else if (_viewType == kIMBObjectViewTypeList)
//				{
//					frame = [ibListView frameOfCellAtColumn:0 row:index];
//					srcView = ibListView;
//				}	
//				else if (_viewType == kIMBObjectViewTypeCombo)
//				{
//					frame = [ibComboView frameOfCellAtColumn:0 row:index];
//					srcView = ibComboView;
//				}	
//			}
//
//			frame = [srcView convertRectToBase:frame];
//			frame.origin = [srcView.window convertBaseToScreen:frame.origin];
//		}
//	}
//
//NSLog(@"%s frame=%@",__FUNCTION__,NSStringFromRect(frame));
//	return frame;
//}
//
//
//- (BOOL) quickLookController:(IMBQuickLookController*)inController handleEvent:(NSEvent*)inEvent
//{
//	NSString* characters = [inEvent charactersIgnoringModifiers];
//	unichar c = ([characters length] > 0) ? [characters characterAtIndex:0] : 0;
//	NSView* srcView = nil;
//	
//	switch (c)
//	{
//		case NSLeftArrowFunctionKey:
//		case NSRightArrowFunctionKey:
//		case NSUpArrowFunctionKey:
//		case NSDownArrowFunctionKey:
//		
//			if (_viewType == kIMBObjectViewTypeIcon)
//				srcView = ibIconView;
//			else if (_viewType == kIMBObjectViewTypeList)
//				srcView = ibListView;
//			else if (_viewType == kIMBObjectViewTypeCombo)
//				srcView = ibComboView;
//
//			[srcView keyDown:inEvent];
//			[inController update:nil];
//			return YES;
//	}
//	
//	return NO;
//}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Dragging


- (void) draggedImage:(NSImage*)inImage endedAt:(NSPoint)inScreenPoint operation:(NSDragOperation)inOperation
{
	_isDragging = NO;
}


// For dumb applications we have the Cocoa NSFilesPromisePboardType as a fallback. In this case we'll handle 
// the IMBObjectPromise for the client and block it until all objects are loaded...

- (NSArray*) namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination
{
	[self _downloadSelectedObjectsToDestination:inDropDestination];
	return [self _namesOfPromisedFiles];
}


// Even dumber are apps that do not support NSFilesPromisePboardType, but only know about NSFilenamesPboardType.
// In this case we'll download to the temp folder and block synchronously until the download has completed...

- (void) pasteboard:(NSPasteboard*)inPasteboard provideDataForType:(NSString*)inType
{
    if (/*_isDragging == NO &&*/ [inType isEqualToString:NSFilenamesPboardType])
	{
		NSData* data = [inPasteboard dataForType:kIMBObjectPromiseType];
		IMBObjectPromise* promise = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		promise.downloadFolderPath = NSTemporaryDirectory();
		[promise startLoadingWithDelegate:self finishSelector:nil];
		[promise waitUntilDone];

		// Every URL will be able to provide a path, we'll leave it to the destination to decide
		// whether it can make any use of it or not.
		[inPasteboard setPropertyList:[promise.localURLs valueForKey:@"path"] forType:NSFilenamesPboardType];
    }
}


- (void) _downloadSelectedObjectsToDestination:(NSURL*)inDestination
{
	IMBNode* node = self.currentNode;
	
	if (node)
	{
		IMBParser* parser = node.parser;
		NSArray* objects = [ibObjectArrayController selectedObjects];
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
		promise.downloadFolderPath = [inDestination path];
		
		[promise startLoadingWithDelegate:self finishSelector:nil];
	}
}


- (NSArray*) _namesOfPromisedFiles
{
	NSArray* objects = [ibObjectArrayController selectedObjects];
	NSMutableArray* names = [NSMutableArray array];
	
	for (IMBObject* object in objects)
	{
		NSString* path = [object path];
		if (path) [names addObject:[path lastPathComponent]];
	}
	
	return names;
}


- (void) prepareProgressForObjectPromise:(IMBObjectPromise*)inObjectPromise
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
	
	[controller window];
	[controller setTitle:title];
	[controller setMessage:message];
	[controller.progressBar startAnimation:nil];
	[controller setCancelTarget:inObjectPromise];
	[controller setCancelAction:@selector(cancel:)];
	[controller.cancelButton setEnabled:NO];
	[controller.window makeKeyAndOrderFront:nil];
	
	self.progressWindowController = controller;
}


- (void) displayProgress:(double)inFraction forObjectPromise:(IMBObjectPromise*)inObjectPromise
{
	[self.progressWindowController setProgress:inFraction];
	[self.progressWindowController setMessage:@""];
	[self.progressWindowController.cancelButton setEnabled:YES];
}


- (void) cleanupProgressForObjectPromise:(IMBObjectPromise*)inObjectPromise
{
	self.progressWindowController = nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserDelegate

// First give the delegate a chance to handle the double click. It it chooses not to, then we will 
// handle it ourself by simply opening the files (with their default app)...

- (void) imageBrowser:(IKImageBrowserView*)inView cellWasDoubleClickedAtIndex:(NSUInteger)inIndex
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = self.delegate;
	BOOL didHandleEvent = NO;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(controller:didDoubleClickSelectedObjects:inNode:)])
		{
			IMBNode* node = self.currentNode;
			NSArray* objects = [ibObjectArrayController selectedObjects];
			didHandleEvent = [delegate controller:controller didDoubleClickSelectedObjects:objects inNode:node];
		}
	}
	
	if (!didHandleEvent)
	{
		[self openSelectedObjects:inView];
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


// Encapsulate all dragged objects in a promise, archive it and put it on the pasteboard. The client can then
// start loading the objects in the promise and iterate over the resulting files...

- (NSUInteger) imageBrowser:(IKImageBrowserView*)inView writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard
{
	IMBNode* node = self.currentNode;
	
	if (node)
	{
		NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:inIndexes];
		
		IMBParser* parser = node.parser;
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:promise];
		
		[inPasteboard declareTypes:[NSArray arrayWithObjects:kIMBObjectPromiseType,/*NSFilesPromisePboardType,*/NSFilenamesPboardType,nil] owner:self];
		[inPasteboard setData:data forType:kIMBObjectPromiseType];
		//		[inPasteboard setPropertyList:[NSArray arrayWithObject:@"jpg"] forType:NSFilesPromisePboardType];
		
		_isDragging = YES;
		return objects.count;
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTableViewDelegate


// If the object for the cell that we are about to display doesn't have any metadata yet, then load it lazily...
// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) tableView:(NSTableView*)inTableView willDisplayCell:(id)inCell forTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inRow];
	
//	if (object.metadata == nil)
//	{
//		[object.parser loadMetadataForObject:object];
//	}
	
	if ([inCell isKindOfClass:[IMBComboTextCell class]])
	{
		IMBComboTextCell* cell = (IMBComboTextCell*)inCell;
		
		if ([object isKindOfClass:[IMBMovieObject class]])
		{
			cell.imageRepresentation = (id) [(IMBMovieObject*)object posterFrame];
			cell.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
			cell.title = object.name;
			cell.subtitle = object.metadataDescription;
		}
		else
		{
			cell.imageRepresentation = object.imageRepresentation;
			cell.imageRepresentationType = object.imageRepresentationType;
			cell.title = object.name;
			cell.subtitle = object.metadataDescription;
		}
	}
	else
	{
		NSLog(@"%s - not an IMBComboTextCell cell",__FUNCTION__);
	}
}


//----------------------------------------------------------------------------------------------------------------------


// We do not allow any editing in the list or combo view...

- (BOOL) tableView:(NSTableView*)inTableView shouldEditTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// Doubleclicking a row opens the selected items. This may trigger a download if the user selected remote objects...

- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = controller.delegate;
	BOOL didHandleEvent = NO;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(controller:didDoubleClickSelectedObjects:inNode:)])
		{
			IMBNode* node = self.currentNode;
			NSArray* objects = [ibObjectArrayController selectedObjects];
			didHandleEvent = [delegate controller:controller didDoubleClickSelectedObjects:objects inNode:node];
		}
	}
	
	if (!didHandleEvent)
	{
		[self openSelectedObjects:inSender];
	}	
}


//----------------------------------------------------------------------------------------------------------------------


// Encapsulate all dragged objects in a promise, archive it and put it on the pasteboard. The client can then
// start loading the objects in the promise and iterate over the resulting files...

- (BOOL) tableView:(NSTableView*)inTableView writeRowsWithIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard 
{
	IMBNode* node = self.currentNode;
	
	if (node)
	{
		NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:inIndexes];
		
		IMBParser* parser = node.parser;
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:promise];
		
		[inPasteboard declareTypes:[NSArray arrayWithObjects:kIMBObjectPromiseType,/*NSFilesPromisePboardType,*/NSFilenamesPboardType,nil] owner:self];
		[inPasteboard setData:data forType:kIMBObjectPromiseType];
		//		[inPasteboard setPropertyList:[NSArray arrayWithObject:@"jpg"] forType:NSFilesPromisePboardType];
		
		_isDragging = YES;
		return YES;
	}
	
	return NO;
}


// For dumb applications we have the Cocoa NSFilesPromisePboardType as a fallback. In this case we'll handle 
// the IMBObjectPromise for the client and block it until all objects are loaded...

- (NSArray*) tableView:(NSTableView*)inTableView namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination forDraggedRowsWithIndexes:(NSIndexSet*)inIndexes
{
	[self _downloadSelectedObjectsToDestination:inDropDestination];
	return [self _namesOfPromisedFiles];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBDynamicTableViewDelegate

// We pre-load the images in batches.

// Assumes that we only have one client table view.  If we were to add another IMBDynamicTableView client, we would need to
// deal with this architecture a bit since we have ivars here about which rows are visible.


- (void)dynamicTableView:(IMBDynamicTableView *)tableView changedVisibleRowsFromRange:(NSRange)oldVisibleRows toRange:(NSRange)newVisibleRows
{
	// NSLog(@"%s",__FUNCTION__);
	
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
		[object removeObserver:self forKeyPath:kIMBObjectImageRepresentationProperty];
		
		NSArray *ops = [[IMBOperationQueue sharedQueue] operations];
		for (IMBObjectThumbnailLoadOperation* op in ops)
		{
			if ([op isKindOfClass:[IMBObjectThumbnailLoadOperation class]])
			{
				IMBObject* loadingObject = [op object];
				if (loadingObject == object)
				{
					//NSLog(@"Lowering priority of load of %@", entity.name);
					[op setQueuePriority:NSOperationQueuePriorityVeryLow];		// re-prioritize lower
					break;
				}
			}
		}
    }
	
    // With newly visible items, observe them and kick off a request to load the image
	
    for (IMBObject* object in itemsNewlyVisible)
	{
		if (nil == [object imageRepresentation])
		{
			// Check if it is already queued -- if it's there already, bump up priority.
			
			NSOperation *foundOperation = nil;
			
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
				//NSLog(@"Raising priority of load of %@", imageEntity.name);
				[foundOperation setQueuePriority:NSOperationQueuePriorityNormal];		// re-prioritize back to normal
			}
			else
			{
				//NSLog(@"Queueing load of %@", imageEntity.name);
				[object load];
			}
		}
		
		// Add observer always to balance
		[object addObserver:self forKeyPath:kIMBObjectImageRepresentationProperty options:0 context:(void*)ibComboView];
     }
	
	// Finally cache our old visible items set
	[_observedVisibleItems release];
    _observedVisibleItems = newVisibleItemsSetRetained;
}


//----------------------------------------------------------------------------------------------------------------------


@end

