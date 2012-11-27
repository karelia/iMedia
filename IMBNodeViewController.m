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

#import "IMBNodeViewController.h"
#import "IMBObjectViewController.h"
#import "IMBLibraryController.h"
#import "IMBAccessRightsViewController.h"
#import "IMBParserMessenger.h"
#import "IMBOutlineView.h"
#import "IMBConfig.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBNodeCell.h"
#import "IMBFlickrNode.h"
#import "NSView+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSCell+iMedia.h"
#import "IMBTableViewAppearance+iMediaPrivate.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kSelectionKey = @"selection";

static NSString* kIMBRevealNodeWithIdentifierNotification = @"IMBRevealNodeWithIdentifier";
static NSString* kIMBSelectNodeWithIdentifierNotification = @"IMBSelectNodeWithIdentifier";
NSString* kIMBExpandAndSelectNodeWithIdentifierNotification = @"IMBExpandAndSelectNodeNodeWithIdentifier";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableDictionary* sRegisteredNodeViewControllerClasses = nil;


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
@synthesize delegate = _delegate;
@synthesize selectedNodeIdentifier = _selectedNodeIdentifier;
@synthesize expandedNodeIdentifiers = _expandedNodeIdentifiers;

@synthesize nodeOutlineView = ibNodeOutlineView;
@synthesize nodePopupButton = ibNodePopupButton;
@synthesize headerContainerView = ibHeaderContainerView;
@synthesize objectContainerView = ibObjectContainerView;
@synthesize footerContainerView = ibFooterContainerView;

@synthesize standardHeaderViewController = _standardHeaderViewController;
@synthesize standardObjectViewController = _standardObjectViewController;
@synthesize standardFooterViewController = _standardFooterViewController;
@synthesize headerViewController = _headerViewController;
@synthesize objectViewController = _objectViewController;
@synthesize footerViewController = _footerViewController;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

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

	NSMutableDictionary* classDict = [NSMutableDictionary dictionaryWithDictionary:[IMBConfig prefsForClass:self.class]];
	[classDict setObject:stateDict forKey:kIMBMediaTypeImage];
	[classDict setObject:stateDict forKey:kIMBMediaTypeAudio];
	[classDict setObject:stateDict forKey:kIMBMediaTypeMovie];
	[classDict setObject:stateDict forKey:kIMBMediaTypeLink];
	[classDict setObject:stateDict forKey:kIMBMediaTypeContact];

	[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	
	[pool drain];
}


+ (void) registerNodeViewControllerClass:(Class)inNodeViewControllerClass forMediaType:(NSString*)inMediaType
{
	@synchronized ([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		if (sRegisteredNodeViewControllerClasses == nil)
		{
			sRegisteredNodeViewControllerClasses = [[NSMutableDictionary alloc] init];
		}
		
		[sRegisteredNodeViewControllerClasses setObject:inNodeViewControllerClass forKey:inMediaType];
		
		[pool drain];
	}
}


+ (IMBNodeViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController delegate:(id<IMBNodeViewControllerDelegate>)inDelegate
{
	// Create a viewController of appropriate class type...
	
	NSString* mediaType = inLibraryController.mediaType;
	Class nodeViewControllerClass = [sRegisteredNodeViewControllerClasses objectForKey:mediaType];
	IMBNodeViewController* controller = [[[nodeViewControllerClass alloc] initWithNibName:[self nibName] bundle:[self bundle]] autorelease];
	controller.delegate = inDelegate;
	
	// Load the view *before* setting the libraryController, so that outlets are set before we load the preferences...

	[controller view];										
	controller.libraryController = inLibraryController;		
	return controller;
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
}


+ (NSString*) nibName
{
	return @"IMBNodeViewController";
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


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self _stopObservingLibraryController];
	
	IMBRelease(_libraryController);
	IMBRelease(_selectedNodeIdentifier);
	IMBRelease(_expandedNodeIdentifiers);
	IMBRelease(_standardHeaderViewController);
	IMBRelease(_standardObjectViewController);
	IMBRelease(_standardFooterViewController);
	IMBRelease(_headerViewController);
	IMBRelease(_objectViewController);
	IMBRelease(_footerViewController);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


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

	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_expandAndSelectNodeWithIdentifier:) 
		name:kIMBExpandAndSelectNodeWithIdentifierNotification 
		object:nil];

	// Set the cell class on the outline view...
	
	NSArray* columns = [ibNodeOutlineView tableColumns];
	
	if ([columns count] > 0)
	{
		NSTableColumn* column = [[ibNodeOutlineView tableColumns] objectAtIndex:0];
		IMBNodeCell* cell = [[[IMBNodeCell alloc] init] autorelease];	
		[column setDataCell:cell];	
	}

	[ibNodeOutlineView setTarget:self];
	[ibNodeOutlineView setAction:@selector(outlineViewWasClicked:)];
		
	// Build the initial contents of the node popup...
	
	[ibNodePopupButton removeAllItems];
	[self __updatePopupMenu];
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
	
	if ([[_libraryController delegate] respondsToSelector:@selector(allowsFolderDropForMediaType:)])
	{
		// This method returns a BOOL, and seeing as the delegate doesn't have a protocol and we don't
		// have one to cast to, we can't use performSelector.., so will use an invocation.
		
		BOOL allowsDrop;
		NSString* mediaType = self.mediaType;
		NSMethodSignature* methodSignature = [[_libraryController delegate] methodSignatureForSelector:@selector(allowsFolderDropForMediaType:)]; 
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		[invocation setSelector:@selector(allowsFolderDropForMediaType:)];
		[invocation setArgument:&mediaType atIndex:2]; // First actual arg
		[invocation invokeWithTarget:[_libraryController delegate]];
		[invocation getReturnValue:&allowsDrop];
		
		if (allowsDrop)
		{
			[ibNodeOutlineView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
		}
	} 
	else
	{
		[ibNodeOutlineView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	}
	
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


- (NSString*) mediaType
{
	return self.libraryController.mediaType;
}


+ (NSImage *)iconForAppWithBundleIdentifier:(NSString *)identifier fallbackFolder:(NSSearchPathDirectory)directory;
{
    // Use app's icon, falling back to the folder's icon, and finally generic folder
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *path = [workspace absolutePathForAppBundleWithIdentifier:identifier];
	NSImage *result = [workspace iconForFile:path];
    
    if (!result)
    {
        NSURL *picturesFolder = [[NSFileManager defaultManager] URLForDirectory:directory
                                                                       inDomain:NSUserDomainMask
                                                              appropriateForURL:nil
                                                                         create:NO
                                                                          error:NULL];
        
        picturesFolder = [picturesFolder URLByResolvingSymlinksInPath]; // tends to be a symlink when sandboxed
        
        if (![picturesFolder getResourceValue:&result forKey:NSURLEffectiveIconKey error:NULL] || result == nil)
        {
            result = [workspace iconForFileType:(NSString *)kUTTypeFolder];
        }
    }
    
	return result;
}


- (NSImage*) icon
{
	return nil;	// Must be overridden by subclass
}


- (NSString*) displayName
{
	return nil;	// Must be overridden by subclass
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Preferences


- (NSMutableDictionary*) _preferences
{
	NSDictionary* classDict = [IMBConfig prefsForClass:self.class];
	return [NSMutableDictionary dictionaryWithDictionary:[classDict objectForKey:self.mediaType]];
}


- (void) _setPreferences:(NSMutableDictionary*)inDict
{
	NSMutableDictionary* classDict = [NSMutableDictionary dictionaryWithDictionary:[IMBConfig prefsForClass:self.class]];
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
#pragma mark NSOutlineViewDataSource


- (NSInteger) outlineView:(NSOutlineView*)inOutlineView numberOfChildrenOfItem:(id)inItem
{
	if (inItem == nil)
	{
		return [_libraryController countOfSubnodes];
	}
	else
	{
		return [(IMBNode*)inItem countOfSubnodes];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (id) outlineView:(NSOutlineView*)inOutlineView child:(NSInteger)inIndex ofItem:(id)inItem
{
	if (inItem == nil)
	{
		return [_libraryController objectInSubnodesAtIndex:inIndex];
	}
	else
	{
		return [(IMBNode*)inItem objectInSubnodesAtIndex:inIndex];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) outlineView:(NSOutlineView*)inOutlineView isItemExpandable:(id)inItem
{
	if (inItem == nil)
	{
		return YES;
	}
	else
	{
		return ![(IMBNode*)inItem isLeafNode];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Check if we have any folder paths in the dragging pasteboard...

- (NSDragOperation) outlineView:(NSOutlineView*)inOutlineView validateDrop:(id<NSDraggingInfo>)inInfo proposedItem:(id)inItem proposedChildIndex:(NSInteger)inIndex
{
	NSArray* paths = [[inInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	
	for (NSString* path in paths)
	{
        NSURL *aURL = [NSURL fileURLWithPath:path isDirectory:YES];
        
        NSNumber *isDirectory;
        if ([aURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL] && [isDirectory boolValue])
		{
			[inOutlineView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex]; // Target the whole view
			return NSDragOperationCopy;
		}
	}

	return NSDragOperationNone;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is required since we switched from Cocoa bindings to data source protocol (otherwise will throw exception in 10.6).
// Note though that we use an IMBNodeCell (setup in -outlineView:willDisplayCell:forTableColumn:item:) to display nodes
// so this method is almost likely irrelevant.

- (id)outlineView:(NSOutlineView *)inOutlineView objectValueForTableColumn:(NSTableColumn *)inTableColumn byItem:(id)inItem
{
    return inItem;
}


//----------------------------------------------------------------------------------------------------------------------


// For each folder path that was dropped onto the outline view create a new custom parser
 
- (BOOL) outlineView:(NSOutlineView*)inOutlineView acceptDrop:(id<NSDraggingInfo>)inInfo item:(id)inItem childIndex:(NSInteger)inIndex
{
	BOOL result = NO;
    NSArray* paths = [[inInfo draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	
	for (NSString* path in paths)
	{
		NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
        
        NSNumber *isDirectory;
        if ([url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL] && [isDirectory boolValue])
		{
            if (![IMBConfig isLibraryAtURL:url])
			{
				[[NSNotificationCenter defaultCenter]
					addObserver:self
					selector:@selector(_didCreateTopLevelNode:) 
					name:kIMBDidCreateTopLevelNodeNotification 
					object:nil];

				[self.libraryController addUserAddedNodeForFolder:url];
				result = YES;
			}
		}	
	}		
	
	[inOutlineView.window makeFirstResponder:inOutlineView];
	return result;
}


// When the new node has arrived (asynchronous operation) then select it and stop listening...

- (void) _didCreateTopLevelNode:(NSNotification*)inNotification
{
	IMBNode* node = (IMBNode*)inNotification.object;
	self.selectedNodeIdentifier = node.identifier;
	[self selectNode:node];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kIMBDidCreateTopLevelNodeNotification object:nil];
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
	IMBNode* node = (IMBNode*)inItem;
	
    if (!_isRestoringState)
    {
        switch (node.accessibility)
        {
            case kIMBResourceDoesNotExist:
            {
                shouldExpand = NO;
                NSInteger row = [inOutlineView rowForItem:inItem];
                NSRect rect = [ibNodeOutlineView badgeRectForRow:row];
                [IMBAccessRightsViewController showMissingResourceAlertForNode:node view:ibNodeOutlineView relativeToRect:rect];
                break;
            }


            case kIMBResourceNoPermission:
            {
                shouldExpand = NO;
                [[IMBAccessRightsViewController sharedViewController] grantAccessRightsForNode:node];
                break;
            }
            
            case kIMBResourceIsAccessible:
            if (!_isRestoringState)
            {
                id delegate = self.libraryController.delegate;
                    
                if ([delegate respondsToSelector:@selector(libraryController:shouldPopulateNode:)])
                {
                    shouldExpand = [delegate libraryController:self.libraryController shouldPopulateNode:node];
                }
            }
            break;
                
            default:
            break;
        }
	}
    
	return shouldExpand;
}


// Expanding was allowed, so instruct the library controller to add subnodes to the node if necessary...

- (void) outlineViewItemWillExpand:(NSNotification*)inNotification
{
	id item = [[inNotification userInfo] objectForKey:@"NSObject"];
	IMBNode* node = (IMBNode*)item;
	
	if (node.accessibility == kIMBResourceIsAccessible)
	{
		[self.libraryController populateNode:node];
	}
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
}


//----------------------------------------------------------------------------------------------------------------------


// Ask the library delegate if we may change the selection.

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldSelectItem:(id)inItem
{
	BOOL shouldSelect = YES;

	if (!_isRestoringState)
	{
		IMBNode* node = (IMBNode*)inItem;
		id delegate = self.libraryController.delegate;
		
		if ([delegate respondsToSelector:@selector(libraryController:shouldPopulateNode:)])
		{
			shouldSelect = [delegate libraryController:self.libraryController shouldPopulateNode:node];
		}
		
		if (node.isGroupNode)
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
		IMBNode* newNode = row>=0 ? [ibNodeOutlineView nodeAtRow:row] : nil;

		if (newNode)
		{
			if (newNode.accessibility == kIMBResourceIsAccessible)
			{
				[self.libraryController populateNode:newNode];
				[ibNodeOutlineView showProgressWheels];
			}
			else if (newNode.accessibility == kIMBResourceDoesNotExist)
			{
				NSRect rect = [ibNodeOutlineView badgeRectForRow:row];
				[IMBAccessRightsViewController showMissingResourceAlertForNode:newNode view:ibNodeOutlineView relativeToRect:rect];
			}
			
			self.selectedNodeIdentifier = newNode.identifier;
		}

		// Install the object view controller...
		
		[self installObjectViewForNode:newNode];
        [(IMBObjectViewController*)self.objectViewController setCurrentNode:newNode];
		
//		// If a completely different parser was selected, then notify the previous parser, that it is most
//		// likely no longer needed any can get rid of its cached data...
//		
//		if (self.selectedParser != newNode.parser)
//		{
//			[self.selectedParser didStopUsingParser];
//			self.selectedParser = newNode.parser;
//		}
	}

	// Sync the selection of the popup menu...
	
	[self __syncPopupMenuSelection];
}


// If a row was clicked without changing the selection, also check for acces rights, and bring up the
// prompt to grant access right if needed...

- (IBAction) outlineViewWasClicked:(id)inSender
{
	NSInteger row = [ibNodeOutlineView clickedRow];
	NSRect rect = [ibNodeOutlineView badgeRectForRow:row];
	IMBNode* newNode = row>=0 ? [ibNodeOutlineView nodeAtRow:row] : nil;
		
    if (newNode != nil)
    {
        switch (newNode.accessibility)
		{
            case kIMBResourceNoPermission:
			[[IMBAccessRightsViewController sharedViewController] grantAccessRightsForNode:newNode];
			break;
                
            case kIMBResourceDoesNotExist:
			[IMBAccessRightsViewController showMissingResourceAlertForNode:newNode view:ibNodeOutlineView relativeToRect:rect];
			break;
                
            default:
			break;
        }
    }
}


//----------------------------------------------------------------------------------------------------------------------


// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) outlineView:(NSOutlineView*)inOutlineView willDisplayCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inTableColumn item:(id)inItem
{	
	IMBNode* node = (IMBNode*)inItem; 
	IMBNodeCell* cell = (IMBNodeCell*)inCell;

	cell.isGroupCell = node.isGroupNode;
	cell.node = node;
    cell.title = node.name ? node.name : @"–––";   // Safeguard against setting title to nil which would raise assertion failure
	cell.badgeType = node.badgeTypeNormal;
	
	if (node.accessibility == kIMBResourceDoesNotExist)
	{
		cell.badgeType = kIMBBadgeTypeResourceMissing;
		cell.badgeIcon = [NSImage imb_imageNamed:@"IMBStopIcon.icns"];
		cell.badgeError = nil;
	}
	else if (node.accessibility == kIMBResourceNoPermission)
	{
		cell.badgeType = kIMBBadgeTypeNoAccessRights;
		cell.badgeIcon = [NSImage imageNamed:NSImageNameCaution];
		cell.badgeError = nil;
	}
	else if (node.error)
	{
		cell.badgeType = kIMBBadgeTypeWarning;
		cell.badgeIcon = [NSImage imageNamed:NSImageNameCaution];
		cell.badgeError = node.error;
	}
	else if ([node respondsToSelector:@selector(license)])
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
			cell.badgeIcon = image;
		}
		else
		{
			cell.badgeIcon = nil;
		}
	}
	else
	{
		cell.badgeIcon = nil;
	}
}


// If we have a badge icon, clicking on that icon should be enabled...

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldTrackCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inTableColumn item:(id)inItem
{
	IMBNodeCell* cell = (IMBNodeCell*)inCell;
	return cell.badgeIcon != nil;
}


//----------------------------------------------------------------------------------------------------------------------


-(BOOL) outlineView:(NSOutlineView*)inOutlineView isGroupItem:(id)inItem
{
	IMBNode* node = (IMBNode*)inItem; 
	return node.isGroupNode;
}


// Change text attributes of outline cell so that Hide/Show buttons' appearance can be customized
// based on section header appearance

-(void)outlineView:(NSOutlineView *)inOutlineView willDisplayOutlineCell:(id)inCell
    forTableColumn:(NSTableColumn *)tableColumn
              item:(id)inItem
{    
    if ([inCell isKindOfClass:[NSButtonCell class]] &&
        [inOutlineView isKindOfClass:[IMBOutlineView class]])
    {
        // If header has a customized color then use it for Hide/Show buttons on right hand side of group row
        
        NSDictionary* textAttributes = ((IMBOutlineView*)inOutlineView).imb_Appearance.sectionHeaderTextAttributes;
        if (textAttributes)
        {
            NSMutableDictionary* effectiveTextAttributes = [NSMutableDictionary dictionaryWithDictionary:textAttributes];
            NSMutableParagraphStyle* paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
            [paragraphStyle setAlignment:NSRightTextAlignment];
            [effectiveTextAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
            
            // If we use default appearance don't mess with background style
            // (would otherwise void implicit highlight color of disclosure triangle)
            // But if we use some other appearance we want to apply another color to triangle.
            // For some reason we have to set the cell's background style for the color to have any effect.
            
            NSNumber* isDefaultAppearanceNumber = [textAttributes objectForKey:IMBIsDefaultAppearanceAttributeName];
            if ((!isDefaultAppearanceNumber || ![isDefaultAppearanceNumber boolValue]) &&
                [textAttributes objectForKey:NSForegroundColorAttributeName])
            {
                // This causes the foreground color of the attributed string to be used for triangle
                // (for whatever reason)
                
                [inCell setBackgroundStyle:0];
            }
            NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithString:[inCell title]
                                                                           attributes:effectiveTextAttributes] autorelease];
            [inCell setAttributedTitle:attrStr];
        }
    }
    
}

- (BOOL)respondsToSelector:(SEL)aSelector;
{
    // I found that (slightly weirdly), if you implement -outlineView:isGroupItem:, NSOutlineView assumes that you must have at least one group item somewhere in the tree, and so it automatically outdents all but the top-level nodes by 1. Thus if configured not to show group nodes, we need to pretend that method doesn't even exist so as to receive regular layout
    if (aSelector == @selector(outlineView:isGroupItem:))
    {
        return [IMBConfig showsGroupNodes];
    }
    else
    {
        return [super respondsToSelector:aSelector];
    }
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
			IMBNode* node = (IMBNode*)item; 
			[expandedNodeIdentifiers addObject:node.identifier];
		}
	}

	return expandedNodeIdentifiers;
}


// Get IMBNode at specified table row...

- (IMBNode*) _nodeAtRow:(NSInteger)inRow
{
	return [ibNodeOutlineView nodeAtRow:inRow];
}


//----------------------------------------------------------------------------------------------------------------------


// Called in response to a IMBNodesWillChangeNotification notification. Since the replacing of nodes in the 
// IMBLibraryController will lead to side effects regarding the current scroll position of the outline view  
// we have to save it here for later restoration...

- (void) _nodesWillChange
{
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
	
	// Temporarily disable storing of saved state (we only want that when the user actually clicks in the UI...
	
	_isRestoringState = YES;
	
	// Update the internal data structures...
	
	[ibNodeOutlineView reloadData];
	
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
		
		if (selectedNodeIdentifier == nil && node.isGroupNode == NO)
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


// Selecting a node requires several things. First the node needs to be selected in the NSOutlineView/NSPopupButton.
// It also needs to be populated (if it wasn't populated before). And third, the objec view needs to be installed
// and filled with objects...

- (void) selectNode:(IMBNode*)inNode
{
	if (inNode)
	{	
		if (inNode.isGroupNode)
		{
			[ibNodeOutlineView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
			[self installObjectViewForNode:nil];
		}
		else
		{
			NSInteger row = [ibNodeOutlineView rowForItem:inNode];
			[ibNodeOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			if (!inNode.isPopulated) [self.libraryController populateNode:inNode]; // Not redundant! Needed if selection doesn't change due to previous line!

			[self installObjectViewForNode:inNode];
			[(IMBObjectViewController*)self.objectViewController setCurrentNode:inNode];
		}
	}	
	else
	{
		[ibNodeOutlineView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        [self installObjectViewForNode:nil];
	}
}


// Return the selected node. Here we assume that the NSTreeController was configured to only allow single
// selection or no selection...

- (IMBNode*) selectedNode
{
	NSInteger row = [ibNodeOutlineView selectedRow];
	
	if (row != NSNotFound)
	{
		return [ibNodeOutlineView nodeAtRow:row];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Expand the selected node...
	
- (void) expandSelectedNode
{
	NSInteger row = [ibNodeOutlineView selectedRow];

	if (row != NSNotFound)
	{
		id item = [ibNodeOutlineView itemAtRow:row];
		[ibNodeOutlineView expandItem:item];
		[self _setExpandedNodeIdentifiers];
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
	
	if (node.accessibility == kIMBResourceNoPermission)
	{
		[[IMBAccessRightsViewController sharedViewController] grantAccessRightsForNode:node];
	}
	
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
	return node == nil || (node.isGroupNode && node.groupType == kIMBGroupTypeFolder);
}


// Choose a folder. Please note: due to a bug in NSOpenPanel when running in a sandbox, we cannot currently use
// beginSheetModalForWindow:. This results in a zero-size window being attached to our panel. Calling runModal
// seems to work fine, even if the user experience is diminished. Work for now. Also note that the entitlement 
// com.apple.security.files.user-selected.read-write is required for host app for the NSOpenPanel to show up...
	
- (IBAction) addNode:(id)inSender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setResolvesAliases:YES];

	NSInteger result = [panel runModal];

	if (result == NSFileHandlingPanelOKButton)
	{
		NSArray* urls = [panel URLs];
		for (NSURL* url in urls)
		{
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(_didCreateTopLevelNode:) 
				name:kIMBDidCreateTopLevelNodeNotification 
				object:nil];

			[self.libraryController addUserAddedNodeForFolder:url];
		}	
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Custom root nodes that are not currently being loaded can be removed...

- (BOOL) canRemoveNode
{
	IMBNode* node = [self selectedNode];
	return node.isTopLevelNode && node.isUserAdded && !node.isLoading;
}


- (IBAction) removeNode:(id)inSender
{
	IMBNode* node = [self selectedNode];
	[self.libraryController removeUserAddedNode:node];
}


//----------------------------------------------------------------------------------------------------------------------


// A node can be reloaded if it is not already being loaded, expanded, or populated in a background operation...

- (BOOL) canReloadNode
{
	IMBNode* node = [self selectedNode];
	return node!=nil && !node.isGroupNode && !node.isLoading;
}


- (IBAction) reloadNode:(id)inSender
{
	IMBNode* node = [self selectedNode];
	[self.libraryController reloadNodeTree:node];
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
	
	if (inNode==nil || (inNode.isGroupNode && inNode.groupType==kIMBGroupTypeFolder))
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
	
	if (inNode!=nil && inNode.isUserAdded && !inNode.isLoading)
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
	
	if (inNode!=nil && !inNode.isGroupNode && !inNode.isLoading)
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
	
	if ([inNode.parserMessenger respondsToSelector:@selector(willShowContextMenu:forNode:)])
	{
		[inNode.parserMessenger willShowContextMenu:menu forNode:inNode];
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
#pragma mark Object View


- (void) installObjectViewForNode:(IMBNode*)inNode
{
	// Remember current view type and icon size...
	
	BOOL shouldRestoreAppearance = self.objectViewController != nil;
	NSUInteger viewType = [(IMBObjectViewController*)self.objectViewController viewType];
	double iconSize = [(IMBObjectViewController*)self.objectViewController iconSize];
	
	// If necessary swap standard and custom view controllers. If nothing has changed we can bail out early 
	// and avoid the expensive work below...
	
	BOOL didSwapViewControllers = NO;
	
	NSViewController* oldHeaderViewController = self.headerViewController;
	NSViewController* newHeaderViewController = [self _customHeaderViewControllerForNode:(IMBNode*)inNode];
	if (newHeaderViewController == nil) newHeaderViewController = self.standardHeaderViewController;
	self.headerViewController = newHeaderViewController;
	if (oldHeaderViewController != newHeaderViewController) didSwapViewControllers = YES;
	
	NSViewController* oldObjectViewController = self.objectViewController;
	NSViewController* newObjectViewController = [self _customObjectViewControllerForNode:inNode];
	if (newObjectViewController == nil) newObjectViewController = self.standardObjectViewController;
	self.objectViewController = newObjectViewController;
	if (oldObjectViewController != newObjectViewController) didSwapViewControllers = YES;
	
	NSViewController* oldFooterViewController = self.footerViewController;
	NSViewController* newFooterViewController = [self _customFooterViewControllerForNode:inNode];
	if (newFooterViewController == nil) newFooterViewController = self.standardFooterViewController;
	self.footerViewController = newFooterViewController;
	if (oldFooterViewController != newFooterViewController) didSwapViewControllers = YES;

	id delegate = [(IMBObjectViewController*)self.standardObjectViewController delegate];
	[(IMBObjectViewController*)newObjectViewController setDelegate:delegate];
	
	if (!didSwapViewControllers)
	{
		return;
	}
	
	// Restore view type and icon size on the new objectViewController instance, thus guarranteeing that 
	// the visual appearance stays the same...
	
	if (shouldRestoreAppearance)
	{
		[(IMBObjectViewController*)self.objectViewController setViewType:viewType];
		[(IMBObjectViewController*)self.objectViewController setIconSize:iconSize];
	}
	
	// Remove all currently installed object views...
	
	[ibHeaderContainerView imb_removeAllSubviews];
	[ibObjectContainerView imb_removeAllSubviews];
	[ibFooterContainerView imb_removeAllSubviews];
	
	// Install optional header view...
	
	NSView* headerView = nil;
	NSView* objectView = nil;
	NSView* footerView = nil;
	
	CGFloat totalHeight = ibObjectContainerView.superview.frame.size.height;
	CGFloat headerHeight = 0.0;
	CGFloat footerHeight = 0.0;
	
	if (self.headerViewController != nil)
	{
		headerView = [self.headerViewController view];
		headerHeight = headerView.frame.size.height;
	}

	NSRect headerFrame = ibHeaderContainerView.frame;
	headerFrame.origin.y = NSMaxY(headerFrame) - headerHeight;
	headerFrame.size.height = headerHeight;
	ibHeaderContainerView.frame = headerFrame;

	if (headerView)
	{		
		[headerView setFrameSize:headerFrame.size];
		[ibHeaderContainerView addSubview:headerView];
	}
			
	// Install optional footer view...
	
	if (self.footerViewController != nil)
	{
		footerView = [self.footerViewController view];
		footerHeight = footerView.frame.size.height;
	}
	
	NSRect footerFrame = ibFooterContainerView.frame;
	footerFrame.origin.y = NSMaxY(footerFrame) - footerHeight;
	footerFrame.size.height = footerHeight;
	ibFooterContainerView.frame = footerFrame;

	if (footerView)
	{
		[footerView setFrameSize:footerFrame.size];
		[ibFooterContainerView addSubview:footerView];
	}

	// Finally install the object view itself (unless told not to)...
	
	BOOL shouldDisplayObjectView = YES;
	if (inNode) shouldDisplayObjectView = inNode.shouldDisplayObjectView;
	
	if (self.objectViewController != nil && shouldDisplayObjectView)
	{
		objectView = [self.objectViewController view];

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


- (NSViewController*) _customHeaderViewControllerForNode:(IMBNode*)inNode
{
	NSViewController* viewController = nil;
	IMBParserMessenger* parserMessenger = inNode.parserMessenger;
	
	if ([(id)_delegate respondsToSelector:@selector(nodeViewController:customHeaderViewControllerForNode:)])
	{
		viewController = [_delegate nodeViewController:self customHeaderViewControllerForNode:inNode];
	}
	
	if (viewController == nil)
	{
		viewController = [parserMessenger customHeaderViewControllerForNode:inNode];
	}

	return viewController;
}


- (NSViewController*) _customObjectViewControllerForNode:(IMBNode*)inNode
{
	NSViewController* viewController = nil;
	IMBParserMessenger* parserMessenger = inNode.parserMessenger;

	if ([(id)_delegate respondsToSelector:@selector(nodeViewController:customObjectViewControllerForNode:)])
	{
		viewController = [_delegate nodeViewController:self customObjectViewControllerForNode:inNode];
	}

	if (viewController == nil) 
	{
		viewController = [parserMessenger customObjectViewControllerForNode:inNode];
	}

	return viewController;
}


- (NSViewController*) _customFooterViewControllerForNode:(IMBNode*)inNode
{
	NSViewController* viewController = nil;
	IMBParserMessenger* parserMessenger = inNode.parserMessenger;
	
	if ([(id)_delegate respondsToSelector:@selector(nodeViewController:customFooterViewControllerForNode:)])
	{
		viewController = [_delegate nodeViewController:self customFooterViewControllerForNode:inNode];
	}

	if (viewController == nil) 
	{
		viewController = [parserMessenger customFooterViewControllerForNode:inNode];
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
	
	NSInteger row = [ibNodeOutlineView rowForItem:inNode];
	if (inNode) [ibNodeOutlineView expandItem:inNode];
	return row;
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
		if (node) [self selectNode:node];
		self.selectedNodeIdentifier = identifier;
	}
}


// Called when the user double clicks an IMBNodeObject. Since there is no direct connection from the 
// IMBObjectViewController to IMBNodeViewController, we'll use a notification and check here if it 
// really concern us...

- (void) _expandAndSelectNodeWithIdentifier:(NSNotification*)inNotification
{
	NSDictionary* userInfo = [inNotification userInfo];
	IMBNode* node = (IMBNode*)[userInfo objectForKey:@"node"];
	IMBObjectViewController* objectViewController = (IMBObjectViewController*)[userInfo objectForKey:@"objectViewController"];

	if (objectViewController == self.objectViewController && node != nil)
	{
		[self _revealNode:node];
		[self selectNode:node];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end

