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
#import "IMBLibraryController.h"
#import "IMBObjectArrayController.h"
#import "IMBConfig.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBObjectPromise.h"
#import "NSWorkspace+iMedia.h"


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

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectViewController

@synthesize libraryController = _libraryController;
@synthesize nodeTreeController = _nodeTreeController;
@synthesize objectArrayController = ibObjectArrayController;

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
	IMBRelease(_nodeTreeController);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) _configureIconView
{
	// Subclasses can override this method to customize look & feel...
	
	if ([ibIconView respondsToSelector:@selector(setCanControlQuickLookPanel:)])
	{
		[ibIconView setCanControlQuickLookPanel:YES];
	}

	if ([ibIconView respondsToSelector:@selector(setIntercellSpacing:)])
	{
		[ibIconView setIntercellSpacing:NSMakeSize(4.0,6.0)];
	}
}


- (void) _configureListView
{
	// Subclasses can override this method to customize look & feel...
}


- (void) _configureComboView
{
	// Subclasses can override this method to customize look & feel...
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
#pragma mark View Options 


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


#pragma mark 
#pragma mark Object Count

	
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


- (NSString*) objectCountString
{
	NSUInteger count = [[ibObjectArrayController arrangedObjects] count];
	NSString* format = count==1 ? self.objectCountFormatSingular : self.objectCountFormatPlural;
	return [NSString stringWithFormat:format,count];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Context Menu 


- (NSMenu*) menuForObject:(IMBObject*)inObject
{
	return nil;
}


- (NSMenu*) menuForBackground;
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserDelegate
 

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView*)inView
{

}


//----------------------------------------------------------------------------------------------------------------------


// Double-clicking opens the file (with its default app). Please note that IMBObjects are first passed through an 
// IMBObjectPromise (which is returned by the parser), because the files may not yet be available locally. In this
// case the promise object loads them asynchronously and calls _openLocalFiles: once the download has finsihed...

- (void) imageBrowser:(IKImageBrowserView*)inView cellWasDoubleClickedAtIndex:(NSUInteger)inIndex
{
	NSArray* selectedNodes = [_nodeTreeController selectedObjects];
	IMBNode* node = selectedNodes.count>0 ? [selectedNodes objectAtIndex:0] : nil;
	IMBParser* parser = node.parser;
	
	IMBObject* object = (IMBObject*) [[ibObjectArrayController arrangedObjects] objectAtIndex:inIndex];
	NSArray* objects = [NSArray arrayWithObject:object];
	
	IMBObjectPromise* promise = [parser objectPromiseWithObjects:objects];
	[promise startLoadingWithDelegate:self finishSelector:@selector(_openLocalFiles:)];
}


- (void) _openLocalFiles:(IMBObjectPromise*)inObjectPromise
{
	for (NSString* path in inObjectPromise.localFiles)
	{
		[[NSWorkspace threadSafeWorkspace] openFile:path];
	}	
}


//----------------------------------------------------------------------------------------------------------------------


- (NSUInteger) imageBrowser:(IKImageBrowserView*)inView writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard
{

}


//----------------------------------------------------------------------------------------------------------------------


- (void) imageBrowser:(IKImageBrowserView*)inView backgroundWasRightClickedWithEvent:(NSEvent*)inEvent
{

}


- (void) imageBrowser:(IKImageBrowserView*)inView cellWasRightClickedAtIndex:(NSUInteger)inIndex withEvent:(NSEvent*)inEvent
{

}


//----------------------------------------------------------------------------------------------------------------------


@end

