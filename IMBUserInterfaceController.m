/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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

#import "IMBUserInterfaceController.h"
#import "IMBLibraryController.h"
#import "IMBNodeTreeController.h"
#import "IMBObjectArrayController.h"
#import "IMBOutlineView.h"
#import "IMBConfig.h"
#import "IMBParser.h"
#import "IMBNode.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

const NSString* kNodesContext = @"nodes.arrangedObjects";
const NSString* kNodesSelectionContext = @"nodes.selection";
const NSString* kObjectsContext = @"objects.arrangedObjects";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBUserInterfaceController ()

- (void) _startObservingLibraryController;
- (void) _stopObservingLibraryController;
- (NSMutableDictionary*) _preferences;
- (void) _setPreferences:(NSMutableDictionary*)inDict;
- (void) _saveStateToPreferences;
- (void) _loadStateFromPreferences;
- (NSMutableArray*) _expandedNodeIdentifiers;
- (void) _nodesWillChange;
- (void) _nodesDidChange;
- (void) _updatePopupMenu;
- (void) _syncPopupMenuSelection;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBUserInterfaceController

@synthesize libraryController = _libraryController;

@synthesize nodeTreeController = ibNodeTreeController;
@synthesize nodeOutlineView = ibNodeOutlineView;
@synthesize nodePopupButton = ibNodePopupButton;
@synthesize selectedNodeIdentifier = _selectedNodeIdentifier;
@synthesize expandedNodeIdentifiers = _expandedNodeIdentifiers;

@synthesize objectArrayController = ibObjectArrayController;
@synthesize objectTabView = ibObjectTabView;
@synthesize objectTableView = ibObjectTableView;
@synthesize objectImageBrowserView = ibObjectImageBrowserView;
@synthesize objectViewType = _objectViewType;
@synthesize objectIconSize = _objectIconSize;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_selectedNodeIdentifier = nil;
		_expandedNodeIdentifiers = nil;
		_isRestoringState = NO;
	}
	
	return self;
}


- (void) awakeFromNib
{
	ibObjectArrayController.objectUnitSingular = @"image"; //NSLocalizedString(@"objectUnitSingular",@"Name of object media type (singular)");
	ibObjectArrayController.objectUnitPlural =  @"images"; //NSLocalizedString(@"objectUnitPlural",@"Name of object media type (singular)");
	
	// Load the last known state from preferences, and save once the app is about to quit...
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_saveStateToPreferences) 
		name:NSApplicationWillTerminateNotification 
		object:nil];
		
	[ibNodeTreeController retain];
	[ibNodeTreeController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:(void*)kNodesContext];
	[ibNodeTreeController addObserver:self forKeyPath:@"selection" options:0 context:(void*)kNodesSelectionContext];

	[ibObjectArrayController retain];
	[ibObjectArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:(void*)kObjectsContext];
}


- (void) dealloc
{
	[ibObjectArrayController removeObserver:self forKeyPath:@"arrangedObjects"];
	[ibObjectArrayController release];

	[ibNodeTreeController removeObserver:self forKeyPath:@"arrangedObjects"];
	[ibNodeTreeController removeObserver:self forKeyPath:@"selection"];
	[ibNodeTreeController release];

	[self _stopObservingLibraryController];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	IMBRelease(_libraryController);
	IMBRelease(_selectedNodeIdentifier);
	IMBRelease(_expandedNodeIdentifiers);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (void) setLibraryController:(IMBLibraryController*)inLibraryController
{
	[self _stopObservingLibraryController];

	id old = _libraryController;
	_libraryController = [inLibraryController retain];
	[old release];
	
	[self _startObservingLibraryController];
	[self _loadStateFromPreferences];
}


- (NSString*) mediaType
{
	return self.libraryController.mediaType;
}


- (void) _startObservingLibraryController
{
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_nodesWillChange) 
		name:kIMBNodesWillChangeNotification 
		object:_libraryController];
		
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_nodesDidChange) 
		name:kIMBNodesDidChangeNotification 
		object:_libraryController];
}


- (void) _stopObservingLibraryController
{
	[[NSNotificationCenter defaultCenter] 
		removeObserver:self 
		name:kIMBNodesWillChangeNotification 
		object:_libraryController];

	[[NSNotificationCenter defaultCenter] 
		removeObserver:self 
		name:kIMBNodesDidChangeNotification
		object:_libraryController];
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
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:self.expandedNodeIdentifiers forKey:@"expandedNodeIdentifiers"];
	[stateDict setObject:self.selectedNodeIdentifier forKey:@"selectedNodeIdentifier"];
	[self _setPreferences:stateDict];
}


- (void) _loadStateFromPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	
	self.expandedNodeIdentifiers = [stateDict objectForKey:@"expandedNodeIdentifiers"];
	self.selectedNodeIdentifier = [stateDict objectForKey:@"selectedNodeIdentifier"];
	
	float splitviewPosition = [[stateDict objectForKey:@"splitviewPosition"] floatValue];
	if (splitviewPosition > 0.0) [ibSplitView setPosition:splitviewPosition ofDividerAtIndex:0];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)inChange context:(void*)inContext
{
	if (inContext == (void*)kNodesContext)
	{
//		[self _updatePopupMenu];
	}
	else if (inContext == (void*)kNodesSelectionContext)
	{
		[self _syncPopupMenuSelection];
	}
	else if (inContext == (void*)kObjectsContext)
	{
		[ibObjectImageBrowserView reloadData];
		[ibObjectArrayController willChangeValueForKey:@"objectCountString"];
		[ibObjectArrayController didChangeValueForKey:@"objectCountString"];
	}
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSSplitView Delegate


// Store the current divider position in the preferences...

- (CGFloat) splitView:(NSSplitView*)inSplitView constrainSplitPosition:(CGFloat)inPosition ofSubviewAt:(NSInteger)inIndex
{
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:[NSNumber numberWithFloat:inPosition] forKey:@"splitviewPosition"];
	[self _setPreferences:stateDict];

	if (inIndex == 0)
	{
		inPosition = MAX(inPosition,36.0);
	}
	
	return inPosition;
}


// When resising the splitview, then make sure that only the bottom part (object view) gets resized, and 
// that the IMBOutlineView is not affected...

- (void) splitView:(NSSplitView*)inSplitView resizeSubviewsWithOldSize:(NSSize)inOldSize
{
    NSView* topView = [[inSplitView subviews] objectAtIndex:0];  
    NSView* bottomView = [[inSplitView subviews] objectAtIndex:1];
    float dividerThickness = [inSplitView dividerThickness]; 
	
    NSRect newFrame = [inSplitView frame];   
	                
    NSRect topFrame = [topView frame];                    
	topFrame.size.width = newFrame.size.width;
   
    NSRect bottomFrame = [bottomView frame];    
    bottomFrame.origin = NSMakePoint(0,0);  
    bottomFrame.size.height = newFrame.size.height - topFrame.size.height - dividerThickness;
    bottomFrame.size.width = newFrame.size.width;          
    bottomFrame.origin.y = topFrame.size.height + dividerThickness; 
 
	[topView setFrame:topFrame];
    [bottomView setFrame:bottomFrame];
}


// When the splitview moved up so far that the IMBOutlineView gets too small, then hide the outline and show 
// the popup instead...

- (void) splitViewDidResizeSubviews:(NSNotification*)inNotification
{
	NSRect frame = [[ibNodeOutlineView enclosingScrollView] frame];
	BOOL collapsed = frame.size.height < 60.0;
	
	[[ibNodeOutlineView enclosingScrollView] setHidden:collapsed];
	[ibNodePopupButton setHidden:!collapsed];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSOutlineView Delegate


// If the user is  expanding an item in the IMBOutlineView then ask the delegate of the library controller if 
// we are allowed to expand the node. If expansion was not triggered by a user event, but by the controllers
// then always allow it...

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldExpandItem:(id)inItem
{
	BOOL shouldExpand = YES;
	
	if (!_isRestoringState)
	{
		id delegate = self.libraryController.delegate;
		
		if ([delegate respondsToSelector:@selector(controller:shouldExpandNode:)])
		{
			IMBNode* node = [inItem representedObject];
			shouldExpand = [delegate controller:self.libraryController shouldExpandNode:node];
		}
	}
	
	return shouldExpand;
}


// Expanding was allowed, so instruct the library controller to add subnodes to the node if necessary...

- (void) outlineViewItemWillExpand:(NSNotification*)inNotification
{
//	if (!_isRestoringState)
	{
		id item = [[inNotification userInfo] objectForKey:@"NSObject"];
		IMBNode* node = [item representedObject];
		[self.libraryController expandNode:node];
	}
}


// When nodes were expanded or collapsed, then store the current state of the user interface...

- (void) _setExpandedNodeIdentifiers
{
	if (!_isRestoringState && !self.libraryController.isReplacingNode)
	{
		self.expandedNodeIdentifiers = [self _expandedNodeIdentifiers];
	}
}

- (void) outlineViewItemDidExpand:(NSNotification*)inNotification
{
	[self _setExpandedNodeIdentifiers];
}

- (void) outlineViewItemDidCollapse:(NSNotification*)inNotification
{
	[self _setExpandedNodeIdentifiers];
}


//----------------------------------------------------------------------------------------------------------------------


// Ask the library delegate if we may change the selection...

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldSelectItem:(id)inItem
{
	BOOL shouldSelect = YES;

	if (!_isRestoringState)
	{
		IMBNode* node = [inItem representedObject];
		id delegate = self.libraryController.delegate;
		
		if ([delegate respondsToSelector:@selector(controller:shouldSelectNode:)])
		{
			shouldSelect = [delegate controller:self.libraryController shouldSelectNode:node];
		}
	}
	
	return shouldSelect;	
}


// If the selection just changed due to a direct user event (clicking), then instruct the library controller 
// to populate the node (if necessary) and remember the identifier of the selected node...

- (void) outlineViewSelectionDidChange:(NSNotification*)inNotification;
{
	if (!_isRestoringState && !self.libraryController.isReplacingNode)
	{
		NSInteger row = [ibNodeOutlineView selectedRow];
		id item = row>=0 ? [ibNodeOutlineView itemAtRow:row] : nil;
		IMBNode* node = [item representedObject];

		if (node)
		{
			[self.libraryController selectNode:node];
			self.selectedNodeIdentifier = node.identifier;
		}
	}

	// Sync the selection of the popup menu...
	
	[self _syncPopupMenuSelection];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Saving & Restoring State


// Get the identifiers of all currently expanded nodes. The result is a flat array, which is needed in the method
// _restoreUserInterfaceState to try to restore the state of the user interface...

- (NSMutableArray*) _expandedNodeIdentifiers
{
	NSMutableArray* expandedNodeIdentifiers = [NSMutableArray array];
	
	NSInteger n = [ibNodeOutlineView numberOfRows];
	
	for (NSInteger i=0; i<n; i++)
	{
		id item = [ibNodeOutlineView itemAtRow:i];
		
		if ([ibNodeOutlineView isItemExpanded:item])
		{
			IMBNode* node = [item representedObject];
			[expandedNodeIdentifiers addObject:node.identifier];
		}
	}

	return expandedNodeIdentifiers;
}


// Get IMBNode at specified table row...

- (IMBNode*) _nodeAtRow:(NSInteger)inRow
{
	id item = [ibNodeOutlineView itemAtRow:inRow];
	IMBNode* node = [item representedObject];
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// Called in response to a IMBNodesWillChangeNotification notification. Set a flag that helps us to do the right 
// thing in the IMBOutlineView delegate methods. If nodes are currently being replaced, then we will allow any 
// changes, because those changes were not initiated by user events...

- (void) _nodesWillChange
{

}


//----------------------------------------------------------------------------------------------------------------------


// Called in response to a IMBNodesDidChangeNotification notification. Restore expanded state from the saved info.
// We now have new node instances, but we can use the identifiers to locate the correct ones. First expand nodes
// as needed, then select the correct node...

- (void) _nodesDidChange
{
	NSInteger i,rows,count;
	IMBNode* node;
	NSString* identifier;
	
	// Temporarily disable storing of saved state (we only want that when the user actuall clicks in the UI...
	
	_isRestoringState = YES;
	
	// Restore the expanded nodes...
	
	NSMutableArray* expandedNodeIdentifiers = [NSMutableArray arrayWithArray:self.expandedNodeIdentifiers];
	
	while (count = [expandedNodeIdentifiers count])
	{
		rows = [ibNodeOutlineView numberOfRows];
		
		for (i=0; i<rows; i++)
		{
			node = [self _nodeAtRow:i];
			identifier = node.identifier;
			
			if ([expandedNodeIdentifiers indexOfObject:identifier] != NSNotFound)
			{
				[ibNodeOutlineView expandItem:[ibNodeOutlineView itemAtRow:i]];
				[expandedNodeIdentifiers removeObject:identifier];
				break;
			}
		}
		
		if ([expandedNodeIdentifiers count] == count)
		{
			break;
		}
	}
	
	// Restore the selected node. Walk through all visible nodes. If we find the correct one then select it...
	
	rows = [ibNodeOutlineView numberOfRows];
	
	for (i=0; i<rows; i++)
	{
		node = [self _nodeAtRow:i];
		identifier = node.identifier;
		
		if ([identifier isEqualToString:self.selectedNodeIdentifier])
		{
			[self selectNode:node];
		}
	}
	
	// Rebuild the popup menu manually. Please note that the popup menu does not currently use bindings...
	
	[self _updatePopupMenu];
	[self _syncPopupMenuSelection];
		
	// We are done, now the user is once again in charge...
	
	_isRestoringState = NO;
}


//----------------------------------------------------------------------------------------------------------------------


// Selecting a node requires two parts. First the node needs to be selected in the NSTreeController. This will
// be directly reflected in the selection of the NSOutlineView and the NSPopUpButton. The second part is that
// a previously empty nodes needs to be populated by the libraryController...

- (void) selectNode:(IMBNode*)inNode
{
	if (inNode)
	{	
		NSIndexPath* indexPath = inNode.indexPath;
		[ibNodeTreeController setSelectionIndexPath:indexPath];
		[self.libraryController selectNode:inNode];
	}	
}


// Return the first selected node. Here we assume that the NSTreeController was configured to only allow single
// selection or no selection...

- (IMBNode*) selectedNode
{
	NSArray* selectedNodes = [ibNodeTreeController selectedObjects];
	
	if ([selectedNodes count] > 0)
	{
		return [selectedNodes objectAtIndex:0];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Popup Menu


// Rebuild the popup menu and. Please note that the popup menu does not currently use bindings...

- (void) _updatePopupMenu
{
	NSMenu* menu = [self.libraryController 
		menuWithSelector:@selector(setSelectedNodeFromPopup:) 
		target:self 
		addSeparators:YES];
		
	[ibNodePopupButton setMenu:menu];
}


// This action is only called by a direct user event from the popup menu...

- (IBAction) setSelectedNodeFromPopup:(id)inSender
{
	NSString* identifier = (NSString*) ibNodePopupButton.selectedItem.representedObject;
	IMBNode* node = [self.libraryController nodeWithIdentifier:identifier];
	[self selectNode:node];
}


// Make sure that the selected item of the popup menu matches the selected node in the outline view...

- (void) _syncPopupMenuSelection
{
	// Sync the selection of the popup menu...
	
	NSMenu* menu = [ibNodePopupButton menu];
	NSInteger n = [menu numberOfItems];
	
	for (NSInteger i=0; i<n; i++)
	{
		NSMenuItem* item = [menu itemAtIndex:i];
		NSString* identifier = (NSString*) item.representedObject;
		if ([identifier isEqualToString:self.selectedNodeIdentifier])
		{
			[ibNodePopupButton selectItem:item];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserView 


- (NSUInteger) numberOfItemsInImageBrowser:(IKImageBrowserView*)inBrowser
{
	return [[ibObjectArrayController arrangedObjects] count];
}


- (id) imageBrowser:(IKImageBrowserView*)inBrowser itemAtIndex:(NSUInteger)inIndex
{
	return [[ibObjectArrayController arrangedObjects] objectAtIndex:inIndex];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Actions


// A node can be reloaded if it is not already being loaded, expanded, or populated in a background operation...

- (BOOL) canReloadNode
{
	IMBNode* node = [self selectedNode];
	return !node.isLoading;
}


- (IBAction) reloadNode:(id)inSender
{
	IMBNode* node = [self selectedNode];
	[self.libraryController reloadNode:node];
}


// We can always add a custom node...

- (BOOL) canAddNode
{
	return YES;
}


- (IBAction) addNode:(id)inSender
{
	// TODO: implement...
}


//----------------------------------------------------------------------------------------------------------------------


// Custom root nodes that are not currently being loaded can be removed...

- (BOOL) canRemoveNode
{
	IMBNode* node = [self selectedNode];
	if (node.isLoading) return NO;
	return node.parser.isCustom && node.parentNode==nil;
}


- (IBAction) removeNode:(id)inSender
{
	// TODO: implement...
}


//----------------------------------------------------------------------------------------------------------------------


@end

