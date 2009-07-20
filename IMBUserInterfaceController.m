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
#import "IMBNode.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBUserInterfaceController ()
- (void) _startObservingLibraryController;
- (void) _stopObservingLibraryController;
- (void) _saveUserInterfaceState;
- (void) _restoreUserInterfaceState;
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
	}
	
	return self;
}


- (void) awakeFromNib
{
	[ibObjectArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:NULL];
}


- (void) dealloc
{
	[ibObjectArrayController removeObserver:self forKeyPath:@"arrangedObjects"];
	[self _stopObservingLibraryController];
	
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
}


- (void) _startObservingLibraryController
{
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_saveUserInterfaceState) 
		name:kIMBNodesWillChangeNotification 
		object:_libraryController];
		
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_restoreUserInterfaceState) 
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Actions


- (IBAction) selectNodeFromPopup:(id)inSender
{

}


// The user just tried to select a row in the IMBOutlineView. Notify the library controller. It will in turn populate 
// the node if necessary...

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldSelectItem:(id)inItem
{
	IMBNode* node = [inItem representedObject];
	[self.libraryController selectNode:node];
	return YES;	
}


// The user is going to expand an item in the IMBOutlineView. Notify the library controller. It will in turn add  
// subnodes to the node if necessary...

- (void) outlineViewItemWillExpand:(NSNotification*)inNotification
{
	id item = [[inNotification userInfo] objectForKey:@"NSObject"];
	IMBNode* node = [item representedObject];
	[self.libraryController expandNode:node];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Saving & Restoring State


// Called in response to a IMBNodesWillChangeNotification notification. Store the identifiers of all expanded 
// nodes an the identifier of the selected node. Since the node objects are about to be replaced (different 
// instances, but same contents) we won't be able to know them by their object pointers. That's why we need
// their identifiers...

- (void) _saveUserInterfaceState
{
	// Expanded nodes...
	
	self.expandedNodeIdentifiers = [NSMutableArray array];
	
	NSInteger n = [ibNodeOutlineView numberOfRows];
	
	for (NSInteger i=0; i<n; i++)
	{
		id item = [ibNodeOutlineView itemAtRow:i];
		
		if ([ibNodeOutlineView isItemExpanded:item])
		{
			IMBNode* node = [item representedObject];
			[self.expandedNodeIdentifiers addObject:node.identifier];
		}
	}

	// Selected node...
	
	NSInteger selectedRow = [ibNodeOutlineView selectedRow];
	id selectedItem = [ibNodeOutlineView itemAtRow:selectedRow];
	IMBNode* selectedNode = [selectedItem representedObject]; 
	if (selectedNode) self.selectedNodeIdentifier = selectedNode.identifier;
}


//----------------------------------------------------------------------------------------------------------------------


// Called in response to a IMBNodesDidChangeNotification notification. Restore expanded state from the saved info
// We now have new node instances, but we can use the identifiers to locate the correct ones. First expand nodes
// as needed, then select the correct node...

- (void) _restoreUserInterfaceState
{
	// Expanded nodes...
	
	while ([self.expandedNodeIdentifiers count] > 0)
	{
		NSInteger rows = [ibNodeOutlineView numberOfRows];
		
		for (NSInteger i=0; i<rows; i++)
		{
			id item = [ibNodeOutlineView itemAtRow:i];
			IMBNode* node = [item representedObject];
			NSString* identifier = node.identifier;
			
			if ([self.expandedNodeIdentifiers indexOfObject:identifier] != NSNotFound)
			{
				[ibNodeOutlineView expandItem:item];
				[self.expandedNodeIdentifiers removeObjectIdenticalTo:identifier];
			}
		}
	}
	
	self.expandedNodeIdentifiers = nil;
	
	// Selected node...
	
	[self selectNodeWithIdentifier:self.selectedNodeIdentifier];
	self.selectedNodeIdentifier = nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) selectNodeWithIdentifier:(NSString*)inIdentifier
{
	IMBNode* node = [self.libraryController nodeWithIdentifier:inIdentifier];
	[self selectNode:node];
}


- (void) selectNode:(IMBNode*)inNode
{
	if (inNode)
	{	
		NSIndexPath* indexPath = inNode.indexPath;
		[ibNodeTreeController setSelectionIndexPath:indexPath];
	}	
}


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
#pragma mark Adding & Removing


- (BOOL) canReload
{
	return YES;
}


- (IBAction) reload:(id)inSender
{

}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) canAddNode
{
	return YES;
}


- (IBAction) addNode:(id)inSender
{

}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) canRemoveNode
{
	return NO;
}


- (IBAction) removeNode:(id)inSender
{

}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)iChange context:(void*)inContext
{
	[self willChangeValueForKey:@"objectCountString"];
	[self didChangeValueForKey:@"objectCountString"];
}


- (NSString*) objectUnitSingular
{
	return @"image";
	return NSLocalizedString(@"objectUnitSingular",@"Name of object media type (singular)");
}	


- (NSString*) objectUnitPlural
{
	return @"images";
	return NSLocalizedString(@"objectUnitPlural",@"Name of object media type (singular)");
}


- (NSString*) objectCountString
{
	NSUInteger count = [[ibObjectArrayController arrangedObjects] count];
	NSString* unit = count==1 ? self.objectUnitSingular : self.objectUnitPlural;
	return [NSString stringWithFormat:@"%d %@",count,unit];
}


//----------------------------------------------------------------------------------------------------------------------


@end

