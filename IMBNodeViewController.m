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


#pragma mark HEADERS

#import "IMBNodeViewController.h"
#import "IMBObjectViewController.h"
#import "IMBLibraryController.h"
#import "IMBNodeTreeController.h"
#import "IMBOutlineView.h"
#import "IMBConfig.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBNodeCell.h"
#import "IMBFlickrNode.h"
#import "NSView+iMedia.h"
#import "NSFileManager+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kSelectionKey = @"selection";

static NSString* kIMBRevealNodeWithIdentifierNotification = @"IMBRevealNodeWithIdentifierNotification";
static NSString* kIMBSelectNodeWithIdentifierNotification = @"IMBSelectNodeWithIdentifierNotification";


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

- (CGFloat) minimumNodeViewWidth;
- (CGFloat) minimumLibraryViewHeight;
- (CGFloat) minimumObjectViewHeight;
- (NSSize) minimumViewSize;

- (NSViewController*) _customHeaderViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) _customObjectViewControllerForNode:(IMBNode*)inNode;
- (NSViewController*) _customFooterViewControllerForNode:(IMBNode*)inNode;

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
@synthesize objectHeaderView = ibObjectHeaderView;
@synthesize objectContainerView = ibObjectContainerView;
@synthesize objectFooterView = ibObjectFooterView;
@synthesize standardObjectView = _standardObjectView;
@synthesize customObjectView = _customObjectView;


//----------------------------------------------------------------------------------------------------------------------


// Set default preferences to make sure that group nodes are initially expanded and the user sees all root nodes...

+ (void) initialize
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSArray* expandedNodeIdentifiers = [NSArray arrayWithObjects:
		@"group://LIBRARIES",
		@"group://FOLDERS",
		@"group://SEARCHES",
		@"group://INTERNET",
		@"group://DEVICES",
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
	
	[pool drain];
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
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_revealNodeWithIdentifier:) 
		name:kIMBRevealNodeWithIdentifierNotification 
		object:nil];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_selectNodeWithIdentifier:) 
		name:kIMBSelectNodeWithIdentifierNotification 
		object:nil];

	// Observe changes to the libary node tree...
	
	[ibNodeTreeController retain];
	[ibNodeTreeController addObserver:self forKeyPath:kArrangedObjectsKey options:0 context:(void*)kArrangedObjectsKey];
	[ibNodeTreeController addObserver:self forKeyPath:kSelectionKey options:0 context:(void*)kSelectionKey];

	// Set the cell class on the outline view...
	
	NSArray* columns = [ibNodeOutlineView tableColumns];
	
	if ([columns count] > 0)
	{
		NSTableColumn* column = [[ibNodeOutlineView tableColumns] objectAtIndex:0];
		IMBNodeCell* cell = [[[IMBNodeCell alloc] init] autorelease];	
		[column setDataCell:cell];	
	}
		
	// Build the initial contents of the node popup...
	
	[ibNodePopupButton removeAllItems];
	[self __updatePopupMenu];
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
	IMBRelease(_customHeaderViewControllers);
	IMBRelease(_customObjectViewControllers);
	IMBRelease(_customFooterViewControllers);
	
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
	
	// Register the the outline view as a dragging destination if we want to accept new folders
	if ([[_libraryController delegate] respondsToSelector:@selector(allowsFolderDropForMediaType:)]) {
		// This method returns a BOOL, and seeing as the delegate doesn't have a protocol and we don't
		// have one to cast to, we can't use performSelector.., so will use an invocation.
		BOOL allowsDrop;
		NSString *mediaType = _libraryController.mediaType;
		NSMethodSignature *methodSignature = [[_libraryController delegate] methodSignatureForSelector:@selector(allowsFolderDropForMediaType:)]; 
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		[invocation setSelector:@selector(allowsFolderDropForMediaType:)];
		[invocation setArgument:&mediaType atIndex:2]; // First actual arg
		
		[invocation invokeWithTarget:[_libraryController delegate]];
		
		[invocation getReturnValue:&allowsDrop];
		
		if (allowsDrop) {
			[ibNodeOutlineView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
		}
	} else {
		[ibNodeOutlineView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	}
	
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
	
	self.expandedNodeIdentifiers = [NSMutableArray arrayWithArray:[stateDict objectForKey:@"expandedNodeIdentifiers"]];
	self.selectedNodeIdentifier = [stateDict objectForKey:@"selectedNodeIdentifier"];
	
	float splitviewPosition = [[stateDict objectForKey:@"splitviewPosition"] floatValue];
	if (splitviewPosition > 0.0) [ibSplitView setPosition:splitviewPosition ofDividerAtIndex:0];
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
		double minPos = [self minimumLibraryViewHeight];
		double maxPos = inSplitView.frame.size.height - [self minimumObjectViewHeight];
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
	if ([inSplitView.subviews count] >= 2)
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
		if (bottomFrame.size.height < [self minimumObjectViewHeight])
		{
			CGFloat bottomOverflow = [self minimumObjectViewHeight] - bottomFrame.size.height;
			bottomFrame.size.height = [self minimumObjectViewHeight];
			bottomFrame.origin.y -= bottomOverflow;
			topFrame.size.height -= bottomOverflow;
		}
	 
		[topView setFrame:topFrame];
		[bottomView setFrame:bottomFrame];
	}
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
		
		if ([delegate respondsToSelector:@selector(libraryController:shouldPopulateNode:)])
		{
			IMBNode* node = [inItem representedObject];
			shouldExpand = [delegate libraryController:self.libraryController shouldPopulateNode:node];
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
		
		if ([delegate respondsToSelector:@selector(libraryController:shouldPopulateNode:)])
		{
			shouldSelect = [delegate libraryController:self.libraryController shouldPopulateNode:node];
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
		
		[self installObjectViewForNode:newNode];
		
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


//----------------------------------------------------------------------------------------------------------------------


// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) outlineView:(NSOutlineView*)inOutlineView willDisplayCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inTableColumn item:(id)inItem
{	
	IMBNode* node = [inItem representedObject];
	IMBNodeCell* cell = (IMBNodeCell*)inCell;

	[cell setImage:node.icon];
	[cell setBadgeType:node.badgeTypeNormal];
	
	if ([node respondsToSelector:@selector(license)])
	{
		IMBFlickrNodeLicense license = [((IMBFlickrNode *)node) license];
		if (license < IMBFlickrNodeLicense_Undefined) license = IMBFlickrNodeLicense_Undefined;
		if (license > IMBFlickrNodeLicense_CommercialUse) license = IMBFlickrNodeLicense_CommercialUse;
		// These are file names.  Ideally we should put localized AX Descriptions on them.
		NSArray *names = [NSArray arrayWithObjects:@"any", @"CC", @"remix", @"commercial", nil];
		NSString *fileName = [names objectAtIndex:license];
		
		if (license)
		{
			NSImage *image = [[[NSImage alloc] initByReferencingFile:[IMBBundle() pathForResource:fileName ofType:@"pdf"]] autorelease];
			[image setScalesWhenResized:YES];
			[image setSize:NSMakeSize(16.0,16.0)];
			[cell setExtraImage:image];
		}
		else
		{
			[cell setExtraImage:nil];
		}
	}
	else
	{
		[cell setExtraImage:nil];
	}
}


//----------------------------------------------------------------------------------------------------------------------


-(BOOL) outlineView:(NSOutlineView*)inOutlineView isGroupItem:(id)inItem
{
	IMBNode* node = [inItem representedObject];
	return node.isGroup;
}


#pragma mark NSOutlineViewDataSource

//----------------------------------------------------------------------------------------------------------------------


// Check if we have any folder paths in the dragging pasteboard...

- (NSDragOperation) outlineView:(NSOutlineView*)inOutlineView validateDrop:(id<NSDraggingInfo>)inInfo proposedItem:(id)inItem proposedChildIndex:(NSInteger)inIndex
{
	NSArray* paths = [[inInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	BOOL exists,directory;
	
	for (NSString* path in paths)
	{
		exists = [[NSFileManager imb_threadSafeManager] fileExistsAtPath:path isDirectory:&directory];
		
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
	BOOL result = NO;
    NSArray* paths = [[inInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	BOOL exists,directory;
	
	for (NSString* path in paths)
	{
		exists = [[NSFileManager imb_threadSafeManager] fileExistsAtPath:path isDirectory:&directory];
		
		if (exists && directory)
		{
			if (![IMBConfig isLibraryPath:path])
			{
				IMBParser* parser = [self.libraryController addCustomRootNodeForFolder:path];
				self.selectedNodeIdentifier = [parser identifierForPath:path];
				result = YES;
			}
		}	
	}		
	
	[inOutlineView.window makeFirstResponder:inOutlineView];
	[self.libraryController reload];
	return result;
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
// And it will allow us to save any state information that might be unintentionally changed through the
// replacements of nodes (remember that the libary controller has a binding with the outline view)

- (void) _nodesWillChange
{
    // Due to an error in NSTreeController a node to be replaced by another node will not be released
    // by NSTreeController if it was currently selected. As a workaround we can safely unselect it here
    // before nodes are exchanged by the library controller because the node identifier
    // of the currently selected node is saved in _selectedNodeIdentifiers anyways.
    
    [ibNodeTreeController setSelectionIndexPath:nil];
    
    // Since the replacing of nodes in the library controller will lead to side effects
    // regarding the current scroll position of the outline view we have to save it here
    // for later restauration
    
    _nodeOutlineViewSavedVisibleRectOrigin = [ibNodeOutlineView visibleRect].origin;
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
	
	// Update the internal data structures...
	
	[ibNodeOutlineView reloadData];
	
	// Temporarily disable storing of saved state (we only want that when the user actuall clicks in the UI...
	
	_isRestoringState = YES;
	
	// Restore the expanded nodes...
	
	NSMutableArray* expandedNodeIdentifiers = [NSMutableArray arrayWithArray:self.expandedNodeIdentifiers];
	
	while ((count = [expandedNodeIdentifiers count]))
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
	
	// Restore the selected node. Walk through all visible nodes. If we find the correct one then select it.
	// Please note the special case where we do not have a selection yet. In this case we use the first available
	// node (that is not a group) to make sure that the user sees something immediately...
	
	NSString* selectedNodeIdentifier = self.selectedNodeIdentifier;
	
	rows = [ibNodeOutlineView numberOfRows];
	BOOL found = NO;
	
	for (i=0; i<rows; i++)
	{
		node = [self _nodeAtRow:i];
		identifier = node.identifier;
		
		if (selectedNodeIdentifier == nil && node.isGroup == NO)
		{
			selectedNodeIdentifier = identifier;
		}
	
		if ([identifier isEqualToString:selectedNodeIdentifier])
		{
			[self selectNode:node];
			found = YES;
			break;
		}
	}
	
	if (!found)
	{
		[self selectNode:nil];
		[self installObjectViewForNode:nil];
	}
	
	// Rebuild the popup menu manually. Please note that the popup menu does not currently use bindings...
	
	[self __updatePopupMenu];
	[self __syncPopupMenuSelection];

    // Restore scroll position of outline view (see _nodesWillChange for further explanation)
    
    [ibNodeOutlineView scrollPoint:_nodeOutlineViewSavedVisibleRectOrigin];

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
//			[self installCustomObjectView:[inNode customObjectView]];
			[self installObjectViewForNode:inNode];
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
	return node == nil || (node.isGroup && node.groupType == kIMBGroupTypeFolder);
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
	return node.isTopLevelNode && node.parser.isCustom && !node.isLoading;
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
	
	if (inNode==nil || (inNode.isGroup && inNode.groupType==kIMBGroupTypeFolder))
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
	
	if (delegate!=nil && [delegate respondsToSelector:@selector(libraryController:willShowContextMenu:forNode:)])
	{
		[delegate libraryController:self.libraryController willShowContextMenu:menu forNode:inNode];
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


- (void) installObjectViewForNode:(IMBNode*)inNode
{
	NSViewController* headerViewController = [self _customHeaderViewControllerForNode:inNode];
	NSViewController* objectViewController = [self _customObjectViewControllerForNode:inNode];
	NSViewController* footerViewController = [self _customFooterViewControllerForNode:inNode];
	
	NSView* headerView = nil;
	NSView* objectView = nil;
	NSView* footerView = nil;
	
	CGFloat totalHeight = ibObjectContainerView.superview.frame.size.height;
	CGFloat headerHeight = 0.0;
	CGFloat footerHeight = 0.0;
	
	// First remove all currently installed object views...
	
	[ibObjectHeaderView imb_removeAllSubviews];
	[ibObjectContainerView imb_removeAllSubviews];
	[ibObjectFooterView imb_removeAllSubviews];
	
	// Install optional header view...
	
	if (headerViewController != nil)
	{
		headerView = [headerViewController view];
		headerHeight = headerView.frame.size.height;
	}

	NSRect headerFrame = ibObjectHeaderView.frame;
	headerFrame.origin.y = NSMaxY(headerFrame) - headerHeight;
	headerFrame.size.height = headerHeight;
	ibObjectHeaderView.frame = headerFrame;

	if (headerView)
	{		
		[headerView setFrameSize:headerFrame.size];
		[ibObjectHeaderView addSubview:headerView];
	}
			
	// Install optional footer view...
	
	if (footerViewController != nil)
	{
		NSView* footerView = [footerViewController view];
		footerHeight = footerView.frame.size.height;
	}
	
	NSRect footerFrame = ibObjectFooterView.frame;
	footerFrame.origin.y = NSMaxY(footerFrame) - footerHeight;
	footerFrame.size.height = footerHeight;
	ibObjectFooterView.frame = footerFrame;

	if (footerView)
	{
		[footerView setFrameSize:footerFrame.size];
		[footerView addSubview:footerView];
	}

	// Finally install the object view itself (unless told not to)...
	
	BOOL shouldDisplayObjectView = YES;
	if (inNode) shouldDisplayObjectView = inNode.shouldDisplayObjectView;
	
	if (shouldDisplayObjectView)
	{
		if (objectViewController != nil)
		{
			objectView = [objectViewController view];
		}
		else
		{
			objectView = self.standardObjectView;
		}
			
		NSRect objectFrame = ibObjectContainerView.frame;
		objectFrame.size.height = totalHeight - headerHeight - footerHeight;
		objectFrame.origin.y = footerHeight;
		ibObjectContainerView.frame = objectFrame;

		if (objectView)
		{
			[objectView setFrame:[ibObjectContainerView bounds]];
			[ibObjectContainerView addSubview:objectView];
		}
		
		[ibObjectContainerView setHidden:NO];
	}
	else
	{
		[ibObjectContainerView setHidden:YES];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// First check if we already have a customViewController for the given node. If not then ask the  
// parser to create one for us. We will store it here for later use...


- (NSViewController*) _customHeaderViewControllerForNode:(IMBNode*)inNode
{
	NSViewController* viewController = nil;
	NSString* identifier = inNode.identifier;
	id delegate = self.libraryController.delegate;
	
	if (identifier)
	{
		viewController = [_customHeaderViewControllers objectForKey:identifier];
		
		if (viewController == nil)
		{
			if (delegate != nil && [delegate respondsToSelector:@selector(customHeaderViewControllerForNode:)])
			{
				viewController = [(id<IMBNodeViewControllerDelegate>)delegate customHeaderViewControllerForNode:inNode];
			}

			if (viewController == nil)
			{
				viewController = [inNode.parser customHeaderViewControllerForNode:inNode];
			}
			
			if (_customHeaderViewControllers == nil && viewController != nil)
			{
				_customHeaderViewControllers = [[NSMutableDictionary alloc] init];
			}

			if (viewController) [_customHeaderViewControllers setObject:viewController forKey:identifier];
			else [_customHeaderViewControllers removeObjectForKey:identifier];
		}
	}
	
	if (viewController)
	{
		if ([viewController isKindOfClass:[IMBObjectViewController class]])
		{	
			[(IMBObjectViewController*)viewController setNodeViewController:self];
			[(IMBObjectViewController*)viewController setLibraryController:self.libraryController];
		}
	}
	
	return viewController;
}


- (NSViewController*) _customObjectViewControllerForNode:(IMBNode*)inNode
{
	NSViewController* viewController = nil;
	NSString* identifier = inNode.identifier;
	id delegate = self.libraryController.delegate;
	
	if (identifier)
	{
		viewController = [_customObjectViewControllers objectForKey:identifier];
	
		if (viewController == nil)
		{
			if (delegate != nil && [delegate respondsToSelector:@selector(customObjectViewControllerForNode:)])
			{
				viewController = [(id<IMBNodeViewControllerDelegate>)delegate customObjectViewControllerForNode:inNode];
			}
			
			if (viewController == nil)
			{
				viewController = [inNode.parser customObjectViewControllerForNode:inNode];
			}

			if (_customObjectViewControllers == nil && viewController != nil)
			{
				_customObjectViewControllers = [[NSMutableDictionary alloc] init];
			}

			if (viewController)
			{
				if ([viewController isKindOfClass:[IMBObjectViewController class]])
				{	
					[(IMBObjectViewController*)viewController setNodeViewController:self];
					[(IMBObjectViewController*)viewController setLibraryController:self.libraryController];
				}
				[_customObjectViewControllers setObject:viewController forKey:identifier];
			}
			else [_customObjectViewControllers removeObjectForKey:identifier];
		}
	}
	
	return viewController;
}


- (NSViewController*) _customFooterViewControllerForNode:(IMBNode*)inNode
{
	NSViewController* viewController = nil;
	NSString* identifier = inNode.identifier;
	id delegate = self.libraryController.delegate;
	
	if (identifier)
	{
		viewController = [_customFooterViewControllers objectForKey:identifier];
	
		if (viewController == nil)
		{
			if (delegate != nil && [delegate respondsToSelector:@selector(customFooterViewControllerForNode:)])
			{
				viewController = [(id<IMBNodeViewControllerDelegate>)delegate customFooterViewControllerForNode:inNode];
			}
			
			if (viewController == nil)
			{
				viewController = [inNode.parser customFooterViewControllerForNode:inNode];
			}

			if (_customFooterViewControllers == nil && viewController != nil)
			{
				_customFooterViewControllers = [[NSMutableDictionary alloc] init];
			}

			if (viewController) [_customFooterViewControllers setObject:viewController forKey:identifier];
			else [_customFooterViewControllers removeObjectForKey:identifier];
		}
	}
	
	if (viewController)
	{
		if ([viewController isKindOfClass:[IMBObjectViewController class]])
		{	
			[(IMBObjectViewController*)viewController setNodeViewController:self];
			[(IMBObjectViewController*)viewController setLibraryController:self.libraryController];
		}
	}

	return viewController;
}


// Use this method in your host app to tell the current object view (icon, list, or combo view)
// that it needs to re-display itself (e.g. when a badge on an image needs to be updated)

- (void) setObjectContainerViewNeedsDisplay:(BOOL)inFlag
{
	[ibObjectContainerView setNeedsDisplay:inFlag];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Presentation constraints


- (CGFloat) minimumNodeViewWidth
{
	return 300.0;
}


- (CGFloat) minimumLibraryViewHeight
{
	return 36.0;
}


- (CGFloat) minimumObjectViewHeight
{
	return 144.0;
}


- (NSSize) minimumViewSize
{
	CGFloat minimumHeight = [self minimumLibraryViewHeight] + [self minimumObjectViewHeight] + [ibSplitView dividerThickness];
	return NSMakeSize([self minimumNodeViewWidth], minimumHeight);
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Saving/Restoring state...


// This method can be called by document based apps to setup the inital state of the UI. 
// It is necessary to fake a _nodesDidChange event in the absence of real changes, or
// the UI won't be populated with the current content of our data model...

- (void) restoreState
{
	[self _loadStateFromPreferences];
	[self _nodesWillChange];
	[self _nodesDidChange];
}


// Called when the window is about to be closed. At this time the controllers are still
// alive and can save their state to the prefs...

- (void) saveState
{
	[self _saveStateToPreferences];
}


//----------------------------------------------------------------------------------------------------------------------

		
// Send a notification so that all IMBNodeViewController will reveal the node with the given identifier...

+ (void) revealNodeWithIdentifier:(NSString*)inIdentifier
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName:kIMBRevealNodeWithIdentifierNotification 
		object:inIdentifier];
}


- (NSInteger) _revealNode:(IMBNode*)inNode
{
	// Recursively expand and reveal the parent node, so that we can be sure that inNode is visible and can be 
	// revealed too...
	
	IMBNode* parentNode = [inNode parentNode];
	
	if (parentNode)
	{
		[self _revealNode:parentNode];
	}
	
	// Now find the row of our node. Expand it and return it row number...
	
	NSInteger n = [ibNodeOutlineView numberOfRows];
		
	for (NSInteger i=0; i<n; i++)
	{
		IMBNode* node = [self _nodeAtRow:i];
		
		if (node == inNode)
		{
			[ibNodeOutlineView expandItem:[ibNodeOutlineView itemAtRow:i]];
			return i;
		}
	}
	
	return NSNotFound;
}


- (void) _revealNodeWithIdentifier:(NSNotification*)inNotification
{
	NSString* identifier = (NSString*) [inNotification object];
	
	if (identifier)
	{
		IMBNode* node = [_libraryController nodeWithIdentifier:identifier];
		NSInteger i = [self _revealNode:node];
		if (i != NSNotFound) [ibNodeOutlineView scrollRowToVisible:i];
		[self _setExpandedNodeIdentifiers];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Send a notification so that all IMBNodeViewController will select the node with the given identifier...

+ (void) selectNodeWithIdentifier:(NSString*)inIdentifier
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName:kIMBSelectNodeWithIdentifierNotification 
		object:inIdentifier];
}


// If the given node already exists, then select it immediately. If not, then we assume it will exist shortly
// (i.e. that it is currently being generated asynchronously). So we need to store its identifier so that it
// will selected once available...

- (void) _selectNodeWithIdentifier:(NSNotification*)inNotification
{
	NSString* identifier = (NSString*) [inNotification object];
	
	if (identifier)
	{
		[self expandSelectedNode];
		
		IMBNode* node = [_libraryController nodeWithIdentifier:identifier];
		
		if (node)
		{
			[self selectNode:node];
		}
		
		self.selectedNodeIdentifier = identifier;
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end

