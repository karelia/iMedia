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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBNodeViewController.h"
#import "IMBLibraryController.h"
#import "IMBNodeTreeController.h"
#import "IMBOutlineView.h"
#import "IMBConfig.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBNodeCell.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kSelectionKey = @"selection";

static const double kMinimumNodeViewWidth = 300.0;

static const double kMinimumLibraryViewHeight = 36.0;
static const double kMinimumObjectViewHeight = 144.0;

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBNodeViewController ()

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
- (void) __updatePopupMenu;
- (void) _syncPopupMenuSelection;
- (void) __syncPopupMenuSelection;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBNodeViewController

@synthesize libraryController = _libraryController;
@synthesize nodeTreeController = ibNodeTreeController;
@synthesize selectedNodeIdentifier = _selectedNodeIdentifier;
@synthesize expandedNodeIdentifiers = _expandedNodeIdentifiers;
@synthesize selectedParser = _selectedParser;

@synthesize nodeOutlineView = ibNodeOutlineView;
@synthesize nodePopupButton = ibNodePopupButton;
@synthesize objectContainerView = ibObjectContainerView;
@synthesize standardObjectView = _standardObjectView;
@synthesize customObjectView = _customObjectView;


//----------------------------------------------------------------------------------------------------------------------


// Set default preferences to make sure that group nodes are initially expanded and the user sees all root nodes...

+ (void) initialize
{
	if (self == [IMBNodeViewController class])
	{   
		NSArray* expandedNodeIdentifiers = [NSArray arrayWithObjects:
			@"group://LIBRARIES",
			@"group://FOLDERS",
			@"group://SEARCHES",
			@"group://INTERNET",
			nil];

		NSMutableDictionary* stateDict = [NSMutableDictionary dictionary];
		[stateDict setObject:expandedNodeIdentifiers forKey:@"expandedNodeIdentifiers"];

		NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
		[classDict setObject:stateDict forKey:kIMBMediaTypeImage];
		[classDict setObject:stateDict forKey:kIMBMediaTypeAudio];
		[classDict setObject:stateDict forKey:kIMBMediaTypeMovie];
		[classDict setObject:stateDict forKey:kIMBMediaTypeLink];
		[classDict setObject:stateDict forKey:kIMBMediaTypeContact];

		[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	}
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
}


+ (NSString*) nibName
{
	return @"IMBLibraryView";
}


+ (IMBNodeViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController
{
	IMBNodeViewController* controller = [[[self alloc] initWithNibName:[self nibName] bundle:[self bundle]] autorelease];
	[controller view];										// Load the view *before* setting the libraryController, 
	controller.libraryController = inLibraryController;		// so that outlets are set before we load the preferences.
	return controller;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle
{
	if (self = [super initWithNibName:inNibName bundle:inBundle])
	{
		_selectedNodeIdentifier = nil;
		_expandedNodeIdentifiers = nil;
		_isRestoringState = NO;
	}
	
	return self;
}


- (void) awakeFromNib
{
	// We need to save preferences before tha app quits...
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_saveStateToPreferences) 
		name:NSApplicationWillTerminateNotification 
		object:nil];
	
	// Observe changes to the libary node tree...
	
	[ibNodeTreeController retain];
	[ibNodeTreeController addObserver:self forKeyPath:kArrangedObjectsKey options:0 context:(void*)kArrangedObjectsKey];
	[ibNodeTreeController addObserver:self forKeyPath:kSelectionKey options:0 context:(void*)kSelectionKey];

	// Set the cell class on the outline view...
	
	NSTableColumn* column = [[ibNodeOutlineView tableColumns] objectAtIndex:0];
	IMBNodeCell* cell = [[[IMBNodeCell alloc] init] autorelease];	
	[column setDataCell:cell];	
	
	// Register the the outline view as a dragging destination...
	
	[ibNodeOutlineView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self _stopObservingLibraryController];

	[ibNodeTreeController removeObserver:self forKeyPath:kArrangedObjectsKey];
	[ibNodeTreeController removeObserver:self forKeyPath:kSelectionKey];
	[ibNodeTreeController release];
	
	IMBRelease(_libraryController);
	IMBRelease(_selectedNodeIdentifier);
	IMBRelease(_expandedNodeIdentifiers);
	IMBRelease(_standardObjectView);
	IMBRelease(_customObjectView);
	
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


#pragma mark 


- (NSMutableDictionary*) _preferences
{
	NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
	return [NSMutableDictionary dictionaryWithDictionary:[classDict objectForKey:self.mediaType]];
}


- (void) _setPreferences:(NSMutableDictionary*)inDict
{
	NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
	if (inDict) [classDict setObject:inDict forKey:self.mediaType];
	[IMBConfig setPrefs:classDict forClass:self.class];
}


- (void) _saveStateToPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	
	if (self.expandedNodeIdentifiers) 
	{
		[stateDict setObject:self.expandedNodeIdentifiers forKey:@"expandedNodeIdentifiers"];
	}
	
	if (self.selectedNodeIdentifier)
	{
		[stateDict setObject:self.selectedNodeIdentifier forKey:@"selectedNodeIdentifier"];
	}
	
	// Please note: Due to lack of position getter in NSSplitView we cannot set splitviewPosition here, 
	// but need to do it in NSSplitView delegate method instead...
	
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


#pragma mark 
#pragma mark Presentation constraints

- (NSSize) minimumViewSize
{
	CGFloat minimumHeight = kMinimumLibraryViewHeight + kMinimumObjectViewHeight + [ibSplitView dividerThickness];
	return NSMakeSize(kMinimumNodeViewWidth, minimumHeight);
}

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSSplitView Delegate


// Store the current divider position in the preferences. Since there is no getter for the current position we
// cannot do it a quit time and have to store it here in the delegate method...

- (CGFloat) splitView:(NSSplitView*)inSplitView constrainSplitPosition:(CGFloat)inPosition ofSubviewAt:(NSInteger)inIndex
{
	// This constrains the bottom edge of the top section (the library view) so
	// that it is guaranteed to be tall enough to accomodate its minimal popup-based 
	// chooser, and so that the bottom section (the object view) is tall enough to 
	// accommodate a reasonable row of items at a reasonable zoom level.
	if (inIndex == 0)
	{
		double minPos = kMinimumLibraryViewHeight;
		double maxPos = inSplitView.frame.size.height - kMinimumObjectViewHeight;
		inPosition = MAX(inPosition,minPos);
		inPosition = MIN(inPosition,maxPos);
	}
	
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:[NSNumber numberWithFloat:inPosition] forKey:@"splitviewPosition"];
	[self _setPreferences:stateDict];

	return inPosition;
}


// When resising the splitview, then make sure that only the bottom part (object view) gets resized, and 
// that the IMBOutlineView is not affected... UNLESS the bottom has already been resized to its minimum 
// size.

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
 
	// If the bottom view is squeezed to its minimum, then we have to resort to shrinking the top.
	// If our client heeded our minimumViewSize then we can't have been resized to a size that 
	// causes BOTH our top and bottom views to be shrunk beyond their minimums.
	if (bottomFrame.size.height < kMinimumObjectViewHeight)
	{
		CGFloat bottomOverflow = kMinimumObjectViewHeight - bottomFrame.size.height;
		bottomFrame.size.height = kMinimumObjectViewHeight;
		bottomFrame.origin.y -= bottomOverflow;
		topFrame.size.height -= bottomOverflow;
	}
 
	[topView setFrame:topFrame];
    [bottomView setFrame:bottomFrame];
}


// When the splitview moved up so far that the IMBOutlineView gets too small, then hide the outline and show 
// the popup instead...

- (void) splitViewDidResizeSubviews:(NSNotification*)inNotification
{
	NSRect frame = [[ibNodeOutlineView enclosingScrollView] frame];
	BOOL collapsed = frame.size.height < 52.0;
	
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
		
		if ([delegate respondsToSelector:@selector(controller:shouldPopulateNode:)])
		{
			IMBNode* node = [inItem representedObject];
			shouldExpand = [delegate controller:self.libraryController shouldPopulateNode:node];
		}
	}
	
	return shouldExpand;
}


// Expanding was allowed, so instruct the library controller to add subnodes to the node if necessary...

- (void) outlineViewItemWillExpand:(NSNotification*)inNotification
{
	id item = [[inNotification userInfo] objectForKey:@"NSObject"];
	IMBNode* node = [item representedObject];
	[self.libraryController populateNode:node];
}


// When nodes were expanded or collapsed, then store the current state of the user interface. Also cancel any
// pending populate operation for the nodes that were just collapsed...
	

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

	id item = [[inNotification userInfo] objectForKey:@"NSObject"];
	IMBNode* node = [item representedObject];
	
	[self.libraryController stopPopulatingNodeWithIdentifier:node.identifier];
}


//----------------------------------------------------------------------------------------------------------------------


// Ask the library delegate if we may change the selection.

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldSelectItem:(id)inItem
{
	BOOL shouldSelect = YES;

	if (!_isRestoringState)
	{
		IMBNode* node = [inItem representedObject];
		id delegate = self.libraryController.delegate;
		
		if ([delegate respondsToSelector:@selector(controller:shouldPopulateNode:)])
		{
			shouldSelect = [delegate controller:self.libraryController shouldPopulateNode:node];
		}
		
		if (node.isGroup)
		{
			shouldSelect = NO;
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
		IMBNode* newNode = [item representedObject];

		// Stop loading the old node's contents, assuming we don't need them anymore. Instead populated the
		// newly selected node...
		
		[self.libraryController stopPopulatingNodeWithIdentifier:self.selectedNodeIdentifier];

		if (newNode)
		{
			[self.libraryController populateNode:newNode];
			self.selectedNodeIdentifier = newNode.identifier;
		}

		// If the node has a custom object view, then install it now...
		
		[self installCustomObjectView:[newNode customObjectView]];
		
		// If a completely different parser was selected, then notify the previous parser, that it is most
		// likely no longer needed any can get rid of its cached data...
		
		if (self.selectedParser != newNode.parser)
		{
			[self.selectedParser didStopUsingParser];
			self.selectedParser = newNode.parser;
		}
	}

	// Sync the selection of the popup menu...
	
	[self __syncPopupMenuSelection];
}


/*  Optional - Different cells for each row
    A different data cell can be returned for any particular tableColumn and item, or a cell that will be used for the entire row (a full width cell). The returned cell should properly implement copyWithZone:, since the cell may be copied by NSTableView. If the tableColumn is non-nil, you should return a cell, and generally you will want to default to returning the result from [tableColumn dataCellForRow:row].

    When each row (identified by the item) is being drawn, this method will first be called with a nil tableColumn. At this time, you can return a cell that will be used to draw the entire row, acting like a group. If you do return a cell for the 'nil' tableColumn, be prepared to have the other corresponding datasource and delegate methods to be called with a 'nil' tableColumn value. If don't return a cell, the method will be called once for each tableColumn in the tableView, as usual.

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item;
{
	NSCell *result = nil;
	if (nil != tableColumn)
	{
		NSAssert([item isKindOfClass:[NSTreeNode class]], @"item not expected class");
		return [[[IMBNodeCell alloc] initTextCell:@""] autorelease];
	}
	return result;
}
*/

//----------------------------------------------------------------------------------------------------------------------


// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) outlineView:(NSOutlineView*)inOutlineView willDisplayCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inTableColumn item:(id)inItem
{	
	IMBNode* node = [inItem representedObject];
	IMBNodeCell* cell = (IMBNodeCell*)inCell;

	[cell setImage:node.icon];
	[cell setBadgeType:node.badgeTypeNormal];
}


//----------------------------------------------------------------------------------------------------------------------


-(BOOL) outlineView:(NSOutlineView*)inOutlineView isGroupItem:(id)inItem
{
	IMBNode* node = [inItem representedObject];
	return node.isGroup;
}


//----------------------------------------------------------------------------------------------------------------------


// Check if we have any folder paths in the dragging pasteboard...

- (NSDragOperation) outlineView:(NSOutlineView*)inOutlineView validateDrop:(id<NSDraggingInfo>)inInfo proposedItem:(id)inItem proposedChildIndex:(NSInteger)inIndex
{
	NSArray* paths = [[inInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	BOOL exists,directory;
	
	for (NSString* path in paths)
	{
		exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory];
		
		if (exists && directory)
		{
			[inOutlineView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex]; // Target the whole view
			return NSDragOperationCopy;
		}
	}

	return NSDragOperationNone;
}


// For each folder path that was dropped onto the outline view create a new custom parser. Then reload the library...
 
- (BOOL) outlineView:(NSOutlineView*)inOutlineView acceptDrop:(id<NSDraggingInfo>)inInfo item:(id)inItem childIndex:(NSInteger)inIndex
{
    NSArray* paths = [[inInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	BOOL exists,directory;
	
	for (NSString* path in paths)
	{
		exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory];
		
		if (exists && directory)
		{
			IMBParser* parser = [self.libraryController addCustomRootNodeForFolder:path];
			self.selectedNodeIdentifier = [parser identifierForPath:path];
		}	
	}		
	
	[inOutlineView.window makeFirstResponder:inOutlineView];
	[self.libraryController reload];
	return YES;
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
	
	[self __updatePopupMenu];
	[self __syncPopupMenuSelection];

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
		if (inNode.isGroup)
		{
			[ibNodeTreeController setSelectionIndexPaths:nil];
		}
		else
		{
			NSIndexPath* indexPath = inNode.indexPath;
			[ibNodeTreeController setSelectionIndexPath:indexPath];
			
			// Not redundant! Needed if selection doesn't change due to previous line!
			[self.libraryController populateNode:inNode]; 
			[self installCustomObjectView:[inNode customObjectView]];
		}
	}	
	else
	{
		[ibNodeTreeController setSelectionIndexPaths:nil];
	}
}


// Return the selected node. Here we assume that the NSTreeController was configured to only allow single
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


- (void) expandSelectedNode
{
	// Expand the selected node...
	
	NSInteger rows = [ibNodeOutlineView numberOfRows];
	
	for (NSInteger i=0; i<rows; i++)
	{
		if ([ibNodeOutlineView isRowSelected:i])
		{
			id item = [ibNodeOutlineView itemAtRow:i];
			[ibNodeOutlineView expandItem:item];
			[self _setExpandedNodeIdentifiers];
			break;
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Popup Menu

- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)inChange context:(void*)inContext
{
	if (inContext == (void*)kArrangedObjectsKey)
	{
//		[self __updatePopupMenu];
	}
	else if (inContext == (void*)kSelectionKey)
	{
		[self __syncPopupMenuSelection];
	}
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


// Rebuild the popup menu and. Please note that the popup menu does not currently use bindings...

- (void) _updatePopupMenu
{
	NSMenu* menu = [self.libraryController 
		menuWithSelector:@selector(setSelectedNodeFromPopup:) 
		target:self 
		addSeparators:YES];
		
	[ibNodePopupButton setMenu:menu];
}


- (void) __updatePopupMenu
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updatePopupMenu) object:nil];
	[self performSelector:@selector(_updatePopupMenu) withObject:nil afterDelay:0.0];
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


- (void) __syncPopupMenuSelection
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_syncPopupMenuSelection) object:nil];
	[self performSelector:@selector(_syncPopupMenuSelection) withObject:nil afterDelay:0.0];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Actions


// We can always add a custom node (folder) is we clicked on the background or if the folders group node is selected...

- (BOOL) canAddNode
{
	IMBNode* node = [self selectedNode];
	return node == nil || node.isGroup && node.groupType == kIMBGroupTypeFolder;
}


// Choose a folder...
	
- (IBAction) addNode:(id)inSender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setResolvesAliases:YES];

	NSWindow* window = [ibSplitView window];
	[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}


// Add a root node for this each folder and the reload the library...
	
- (void) openPanelDidEnd:(NSOpenPanel*)inPanel returnCode:(int)inReturnCode contextInfo:(void*)inContextInfo
{
	if (inReturnCode == NSOKButton)
	{
		NSArray* paths = [inPanel filenames];
		for (NSString* path in paths)
		{
			IMBParser* parser = [self.libraryController addCustomRootNodeForFolder:path];
			self.selectedNodeIdentifier = [parser identifierForPath:path];
		}	
		
		[self.libraryController reload];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Custom root nodes that are not currently being loaded can be removed...

- (BOOL) canRemoveNode
{
	IMBNode* node = [self selectedNode];
	return node.isRootNode && node.parser.isCustom && !node.isLoading;
}


- (IBAction) removeNode:(id)inSender
{
	IMBNode* node = [self selectedNode];
	[self.libraryController removeCustomRootNode:node];
}


//----------------------------------------------------------------------------------------------------------------------


// A node can be reloaded if it is not already being loaded, expanded, or populated in a background operation...

- (BOOL) canReloadNode
{
	IMBNode* node = [self selectedNode];
	return node!=nil && !node.isGroup && !node.isLoading;
}


- (IBAction) reloadNode:(id)inSender
{
	IMBNode* node = [self selectedNode];
	[self.libraryController reloadNode:node];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Context Menu

- (NSMenu*) menuForNode:(IMBNode*)inNode
{
	NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"contextMenu"] autorelease];
	NSMenuItem* item = nil;
	NSString* title = nil;
	
	// First we'll add standard menu items...
	
	if (inNode==nil || inNode.isGroup && inNode.groupType==kIMBGroupTypeFolder)
	{
		title = NSLocalizedStringWithDefaultValue(
			@"IMBNodeViewController.menuItem.add",
			nil,IMBBundle(),
			@"Add…",
			@"Menu item in context menu of outline view");

		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(addNode:) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
		[item release];
	}
	
	if (inNode!=nil && inNode.parser.isCustom && !inNode.isLoading)
	{
		title = NSLocalizedStringWithDefaultValue(
			@"IMBNodeViewController.menuItem.remove",
			nil,IMBBundle(),
			@"Remove",
			@"Menu item in context menu of outline view");

		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(removeNode:) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
		[item release];
	}
	
	if (inNode!=nil && !inNode.isGroup && !inNode.isLoading)
	{
		title = NSLocalizedStringWithDefaultValue(
			@"IMBNodeViewController.menuItem.reload",
			nil,IMBBundle(),
			@"Reload",
			@"Menu item in context menu of outline view");

		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(reloadNode:) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
		[item release];
	}
	
	// Then the parser can add custom menu items...
	
	if ([inNode.parser respondsToSelector:@selector(willShowContextMenu:forNode:)])
	{
		[inNode.parser willShowContextMenu:menu forNode:inNode];
	}
	
	// Finally give the delegate a chance to add menu items...
	
	id delegate = self.libraryController.delegate;
	
	if (delegate!=nil && [delegate respondsToSelector:@selector(controller:willShowContextMenu:forNode:)])
	{
		[delegate controller:self.libraryController willShowContextMenu:menu forNode:inNode];
	}
	
	return menu;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) validateMenuItem:(NSMenuItem*)inMenuItem
{
	if (inMenuItem.action == @selector(setSelectedNodeFromPopup:))
	{
		return YES;
	}

	if (inMenuItem.action == @selector(addNode:))
	{
		return self.canAddNode;
	}

	if (inMenuItem.action == @selector(removeNode:))
	{
		return self.canRemoveNode;
	}

	if (inMenuItem.action == @selector(reloadNode:))
	{
		return self.canReloadNode;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Object Views


// Install the standard object view and remember it for later...

- (void) installStandardObjectView:(NSView*)inObjectView
{
	NSView* containerView = [self objectContainerView];
	[inObjectView setFrame:[containerView bounds]];
	[containerView addSubview:inObjectView];
	self.standardObjectView = inObjectView;
}


// Install a custom object view (and replace an old custom view or the standard view)...

- (void) installCustomObjectView:(NSView*)inObjectView
{
	NSView* objectView = nil;
	
	// We want a custom view...
	
	if (inObjectView)
	{
		// so get hide the stadard view (but keep it retained for later)...
		
		[_standardObjectView removeFromSuperview];

		// and use the new custom view...
		
		if (_customObjectView != inObjectView)
		{
			[_customObjectView removeFromSuperview];
			self.customObjectView = inObjectView;
			objectView = inObjectView;
		}
	}
	
	// We want the standard view, so get rid of an existing custom view...
	
	else
	{
		[_customObjectView removeFromSuperview];
		self.customObjectView = nil;
		objectView = self.standardObjectView;
	}
	
	// Finally install the chosen view...
	
	if (objectView)
	{
		NSView* containerView = [self objectContainerView];
		[objectView setFrame:containerView.bounds];
		[objectView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
		[containerView addSubview:objectView];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end

