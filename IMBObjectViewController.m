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
#import "IMBObjectPromise.h"
#import "IMBImageBrowserCell.h"
#import "IMBProgressWindowController.h"
#import "IMBQuickLookController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kImageRepresentationKey = @"arrangedObjects.imageRepresentation";
static NSString* kObjectCountStringKey = @"objectCountString";


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
	[ibObjectArrayController addObserver:self forKeyPath:kImageRepresentationKey options:0 context:(void*)kImageRepresentationKey];
	
	// Configure the object views...
	
	[self _configureIconView];
	[self _configureListView];
	[self _configureComboView];
}


- (void) dealloc
{
	[ibObjectArrayController removeObserver:self forKeyPath:kImageRepresentationKey];
	[ibObjectArrayController removeObserver:self forKeyPath:kArrangedObjectsKey];
	[ibObjectArrayController release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	IMBRelease(_libraryController);
	IMBRelease(_nodeViewController);
	IMBRelease(_progressWindowController);
	
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
	
	else if (inContext == (void*)kImageRepresentationKey)
	{
		[self _reloadIconView];
	}
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


- (void) _reloadIconView
{
	[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView selector:@selector(reloadData) object:nil];
	[ibIconView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
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
	self.iconSize = [[stateDict objectForKey:@"iconSize"] doubleValue];
	
//	NSData* selectionData = [stateDict objectForKey:@"selectionData"];
//	NSIndexSet* selectionIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:selectionData];
//	[ibObjectArrayController setSelectionIndexes:selectionIndexes];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark User Interface


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Subclasses can override these methods to configure or customize look & feel of the various object views...

- (void) _configureIconView
{
	// Make the IKImageBrowserView use our custom cell class. Please note that we check for the existence 
	// of the base class first, as it is un undocumented internal class on 10.5. In 10.6 it is always there...
	
	if ([ibIconView respondsToSelector:@selector(setCellClass:)] && NSClassFromString(@"IKImageBrowserCell"))
	{
		[ibIconView performSelector:@selector(setCellClass:) withObject:[IMBImageBrowserCell class]];
	}
}


- (void) _configureListView
{
	[ibListView setTarget:self];
	[ibListView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
}


- (void) _configureComboView
{
	[ibComboView setTarget:self];
	[ibComboView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
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
// This may be helpfull for the parser so that it can supply larger thumbnails...

- (void) setIconSize:(double)inIconSize
{
	_iconSize = inIconSize;
	
	NSSize size = [ibIconView cellSize];
	IMBNode* selectedNode = [_nodeViewController selectedNode];
	IMBParser* parser = selectedNode.parser;
	
	if ([parser respondsToSelector:@selector(objectViewDidChangeIconSize:)])
	{
		[parser objectViewDidChangeIconSize:size];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) objectCountString
{
	NSUInteger count = [[ibObjectArrayController arrangedObjects] count];
	NSString* format = count==1 ? self.objectCountFormatSingular : self.objectCountFormatPlural;
	return [NSString stringWithFormat:format,count];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

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
		[item setRepresentedObject:[inObject value]];
		[item setTarget:self];
		[menu addItem:item];
		[item release];
	}
	
	// Check if the object is a local file. If yes add appropriate standard menu items...
	
	if ([[inObject value] isKindOfClass:[NSString class]])
	{
		NSString* path = (NSString*)[inObject value];

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
	
	else if ([[inObject value] isKindOfClass:[NSURL class]])
	{
		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.openInBrowser",
			nil,IMBBundle(),
			@"Open in Browser",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInBrowser:) keyEquivalent:@""];
		[item setRepresentedObject:[inObject value]];
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
	
	IMBNode* selectedNode = [_nodeViewController selectedNode];
	IMBParser* parser = selectedNode.parser;
	
	if ([parser respondsToSelector:@selector(addMenuItemsToContextMenu:forObject:)])
	{
		[parser willShowContextMenu:menu forObject:inObject];
	}
	
	// Give delegate a chance to add custom menu items...
	
	id delegate = self.libraryController.delegate;
	
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
#pragma mark IKImageBrowserDelegate
 

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView*)inView
{

}


//----------------------------------------------------------------------------------------------------------------------


// First give the delegate a chance to handle the double click. It it chooses not to, then we will 
// handle it ourself by simply opening the files (with their default app)...

- (void) imageBrowser:(IKImageBrowserView*)inView cellWasDoubleClickedAtIndex:(NSUInteger)inIndex
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = controller.delegate;
	BOOL didHandleEvent = NO;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(controller:didDoubleClickSelectedObjects:inNode:)])
		{
			IMBNode* node = [_nodeViewController selectedNode];
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
	IMBNode* selectedNode = [_nodeViewController selectedNode];

	if (selectedNode)
	{
		NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:inIndexes];

		IMBParser* parser = selectedNode.parser;
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:promise];
		
		[inPasteboard declareTypes:[NSArray arrayWithObjects:kIMBObjectPromiseType,NSFilesPromisePboardType,NSFilenamesPboardType,nil] owner:self];
		[inPasteboard setData:data forType:kIMBObjectPromiseType];
		[inPasteboard setPropertyList:[NSArray arrayWithObject:@"jpg"] forType:NSFilesPromisePboardType];
		
		return objects.count;
	}
	
	return 0;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTableViewDelegate
 

- (BOOL) tableView:(NSTableView*)inTableView shouldEditTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	return NO;
}


- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = controller.delegate;
	BOOL didHandleEvent = NO;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(controller:didDoubleClickSelectedObjects:inNode:)])
		{
			IMBNode* node = [_nodeViewController selectedNode];
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
	IMBNode* selectedNode = [_nodeViewController selectedNode];

	if (selectedNode)
	{
		NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:inIndexes];

		IMBParser* parser = selectedNode.parser;
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:promise];
		
		[inPasteboard declareTypes:[NSArray arrayWithObjects:kIMBObjectPromiseType,NSFilesPromisePboardType,NSFilenamesPboardType,nil] owner:self];
		[inPasteboard setData:data forType:kIMBObjectPromiseType];
		[inPasteboard setPropertyList:[NSArray arrayWithObject:@"jpg"] forType:NSFilesPromisePboardType];
		
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
#pragma mark Opening
 

// Open the selected objects...

- (IBAction) openSelectedObjects:(id)inSender
{
	IMBNode* selectedNode = [_nodeViewController selectedNode];
	NSArray* objects = [ibObjectArrayController selectedObjects];
	[self openObjects:objects inSelectedNode:selectedNode];
}


// Open the specified objects...

- (void) openObjects:(NSArray*)inObjects inSelectedNode:(IMBNode*)inSelectedNode
{
	IMBObject* firstObject = [inObjects count]>0 ? [inObjects objectAtIndex:0] : nil;
	
	// If this is a single IMBNodeObject, then expand the currently selected node and select the appropriate subnode...
	
	if ([firstObject isKindOfClass:[IMBNodeObject class]])
	{
		IMBNode* subnode = (IMBNode*)firstObject.value;
		[_nodeViewController expandSelectedNode];
		[_nodeViewController selectNode:subnode];
	}
		
	// Double-clicking opens the files (with the default app). Please note that IMBObjects are first passed through an 
	// IMBObjectPromise (which is returned by the parser), because the files may not yet be available locally. In this
	// case the promise object loads them asynchronously and calls _openLocalFiles: once the download has finsihed...
		
	else if (inSelectedNode)
	{
		IMBParser* parser = inSelectedNode.parser;
		IMBObjectPromise* promise = [parser objectPromiseWithObjects:inObjects];
		[promise startLoadingWithDelegate:self finishSelector:@selector(_openLocalFiles:withError:)];
	}
}


- (void) _openLocalFiles:(IMBObjectPromise*)inObjectPromise withError:(NSError*)inError
{
	if (inError == nil)
	{
		for (NSString* path in inObjectPromise.localFiles)
		{
			[[NSWorkspace threadSafeWorkspace] openFile:path];
		}
	}
	else
	{
		[NSApp presentError:inError];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Dragging
 

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
    if ([inType isEqualToString:NSFilenamesPboardType])
	{
		NSData* data = [inPasteboard dataForType:kIMBObjectPromiseType];
		IMBObjectPromise* promise = [NSKeyedUnarchiver unarchiveObjectWithData:data];

		promise.downloadFolderPath = NSTemporaryDirectory();
		[promise startLoadingWithDelegate:self finishSelector:nil];
		[promise waitUntilDone];
		
		[inPasteboard setPropertyList:promise.localFiles forType:NSFilenamesPboardType];
    }
}


- (void) _downloadSelectedObjectsToDestination:(NSURL*)inDestination
{
	IMBNode* selectedNode = [_nodeViewController selectedNode];
	NSArray* objects = [ibObjectArrayController selectedObjects];
	
	if (selectedNode)
	{
		IMBParser* parser = selectedNode.parser;
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
		NSString* path = nil;
		
		if ([object.value isKindOfClass:[NSString class]])
			path = (NSString*)object.value;
		else if ([object.value isKindOfClass:[NSURL class]])	
			path = [(NSURL*)object.value path];
		
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
		@"Downloading",
		@"Window title of progress panel of IMBObjectViewController");

	NSString* message = NSLocalizedStringWithDefaultValue(
		@"IMBObjectViewController.progress.message.preparing",
		nil,IMBBundle(),
		@"Preparing…",
		@"Text message in progress panel of IMBObjectViewController");

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
#pragma mark QuickLook
 

//- (NSURL*) _urlForObject:(IMBObject*)inObject
//{
//	if ([inObject.value isKindOfClass:[NSURL class]])
//	{
//		return (NSURL*) inObject.value;
//	}
//	else if ([inObject.value isKindOfClass:[NSString class]])
//	{
//		NSString* path = (NSString*) inObject.value;
//		return [NSURL fileURLWithPath:path];
//	}
//	
//	return nil;
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


@end

