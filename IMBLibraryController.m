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

#import "IMBLibraryController.h"
#import "IMBParserController.h"
#import "IMBAccessRightsController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBParserMessenger.h"
#import "IMBAccessRightsViewController.h"
#import "IMBImageFolderParserMessenger.h"
#import "IMBAudioFolderParserMessenger.h"
#import "IMBMovieFolderParserMessenger.h"
#import "IMBConfig.h"
#import "IMBFileSystemObserver.h"
#import "NSWorkspace+iMedia.h"
#import "NSImage+iMedia.h"
#import "SBUtilities.h"
#import "IMBPopover.h"
#import <XPCKit/XPCKit.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBNodesWillReloadNotification = @"IMBNodesWillReloadNotification";
NSString* kIMBNodesWillChangeNotification = @"IMBNodesWillChangeNotification";
NSString* kIMBNodesDidChangeNotification = @"IMBNodesDidChangeNotification";
NSString* kIMBDidCreateTopLevelNodeNotification = @"IMBDidCreateTopLevelNodeNotification";

#ifndef RESPONDS
#define RESPONDS(delegate,selector) (delegate!=nil && [delegate respondsToSelector:selector])
#endif 


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableDictionary* sLibraryControllers = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Private controller methods...

@interface IMBLibraryController ()

@property (retain,readwrite) NSMutableArray* subnodes;			
- (NSMutableArray*) mutableArrayForPopulatingSubnodes;

- (void) _setParserMessenger:(IMBParserMessenger*)inMessenger nodeTree:(IMBNode*)inNode;
- (IMBNode*) _groupNodeForTopLevelNode:(IMBNode*)inNewNode;
- (void) _reloadTopLevelNodes;
- (void) _reloadTopLevelNode:(IMBNode*)inNode;
- (void) _replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode parentNodeIdentifier:(NSString*)inParentNodeIdentifier;

- (void) _reloadNodesWithWatchedPath:(NSString*)inPath;
- (void) _reloadNodesWithWatchedPath:(NSString*)inPath nodes:(NSArray*)inNodes;
- (void) _unmountNodes:(NSArray*)inNodes onVolume:(NSString*)inVolume;

//- (void) _attachAccessRightsBookmarksToParserMessenger:(IMBParserMessenger*)inParserMessenger;

@end

// Define __dummyAction: just to quiet the compiler

@interface NSObject ()

- (IBAction) __dummyAction:(id)sender;

@end

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLibraryController

@synthesize mediaType = _mediaType;
@synthesize subnodes = _subnodes;
@synthesize delegate = _delegate;
@synthesize isReplacingNode = _isReplacingNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Create a singleton instance per media type and store it in a global dictionary so that we can access it by type...

+ (IMBLibraryController*) sharedLibraryControllerWithMediaType:(NSString*)inMediaType
{
	IMBLibraryController* controller = nil;
	
	@synchronized(self)
	{
		if (sLibraryControllers == nil)
		{
			sLibraryControllers = [[NSMutableDictionary alloc] init];
		}

		controller = [sLibraryControllers objectForKey:inMediaType];
		
		if (controller == nil)
		{
			controller = [[IMBLibraryController alloc] initWithMediaType:inMediaType];
			[sLibraryControllers setObject:controller forKey:inMediaType];
			[controller release];
		}
	}
	
	return controller;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super init])
	{
		self.mediaType = inMediaType;
		self.subnodes = nil; //[NSMutableArray array];
		_isReplacingNode = NO;
		
        // Ensure that app-scoped bookmarks are loaded from prefs
        // if we are running sandboxed with GCD instead of XPC services
        
        [IMBAccessRightsController sharedAccessRightsController];

		// Listen to changes on the file system...
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self 
			selector:@selector(pathDidChange:)
			name:kIMBPathDidChangeNotification 
			object:nil];
			
		// When volume are unmounted we would like to be notified so that we can stop listening for those paths...
		
		[[[NSWorkspace sharedWorkspace] notificationCenter]
			addObserver:self 
			selector:@selector(_willUnmountVolume:)
			name:NSWorkspaceWillUnmountNotification 
			object:nil];
			
		[[[NSWorkspace sharedWorkspace] notificationCenter]
			addObserver:self
			selector:@selector(_volumesDidChange)
			name:NSWorkspaceDidMountNotification
			object:nil];

		[[[NSWorkspace sharedWorkspace] notificationCenter]
			addObserver:self
			selector:@selector(_volumesDidChange)
			name:NSWorkspaceDidUnmountNotification
			object:nil];

		[[[NSWorkspace sharedWorkspace] notificationCenter]
			addObserver:self
			selector:@selector(_volumesDidChange)
			name:NSWorkspaceDidRenameVolumeNotification
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

	IMBRelease(_mediaType);
	IMBRelease(_subnodes);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Loading Nodes


// Reload behaves differently on first call and on subsequent calls. The first time around, we'll just create
// empty (unpopulated) toplevel nodes. On subsequent calls, we will reload the existing nodes and populate 
// them to the same level as before...

- (void) reload
{
	NSArray* messengers = [[IMBParserController sharedParserController] loadedParserMessengersForMediaType:self.mediaType];

	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillReloadNotification object:self];

	// First call: create unpopulated top level nodes...
	
	if (self.subnodes == nil)
	{
		for (IMBParserMessenger* messenger in messengers)
		{
			[self createTopLevelNodesWithParserMessenger:messenger];
		}
	}
	
	// Subsequent calls: reload existing nodes. This requires several steps. Reload the existing toplevel nodes.
	// This will also get rid of existing top-level nodes that should no longer be there. Then we need to create
	// and insert any new top-level nodes that haven't existed before. ...
	
	else 
	{
		[self _reloadTopLevelNodes];
	
		for (IMBParserMessenger* messenger in messengers)
		{
			[self createTopLevelNodesWithParserMessenger:messenger];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) createTopLevelNodesWithParserMessenger:(IMBParserMessenger*)inParserMessenger
{
	// Ask delegate whether we should create nodes with this IMBParserMessenger...
	
	if (RESPONDS(_delegate,@selector(libraryController:shouldCreateNodeWithParserMessenger:)))
	{
		if (![_delegate libraryController:self shouldCreateNodeWithParserMessenger:inParserMessenger])
		{
			return;
		}
	}
	
	// Create top-level nodes...
	
	if (RESPONDS(_delegate,@selector(libraryController:willCreateNodeWithParserMessenger:)))
	{
		[_delegate libraryController:self willCreateNodeWithParserMessenger:inParserMessenger];
	}
	
	SBPerformSelectorAsync(inParserMessenger.connection,inParserMessenger,@selector(unpopulatedTopLevelNodes:),nil, dispatch_get_main_queue(),
	
		^(NSArray* inNodes,NSError* inError)
		{
			// Got a new node. Do some consistency checks (was it populated correctly)...
			
			if (inError)
			{
				NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
			}
			else
			{
				for (IMBNode* node in inNodes)
				{
					if (node.isPopulated)
					{
						NSString* title = @"Programmer Error";
						NSString* description = [NSString stringWithFormat:
							@"The node '%@' returned by the parser %@ should not be populated, yet.\n\nEither subnodes or objects is already set!",
							node.name,
							node.parserIdentifier];
							
						NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
							title,@"title",
							description,NSLocalizedDescriptionKey,
							nil];
							
						node.error = [NSError errorWithDomain:kIMBErrorDomain code:paramErr userInfo:info];
						if (node.error) NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,node.error);
					}
				}
			}
			
			// Insert the new top-level nodes into our data model...
			
			if (inNodes)
			{
				for (IMBNode* node in inNodes)
				{
					if ([self nodeWithIdentifier:node.identifier] == nil)
					{
						node.parserMessenger = inParserMessenger;
						[self _replaceNode:nil withNode:node parentNodeIdentifier:nil];
					}
					
					if (RESPONDS(_delegate,@selector(libraryController:didCreateNode:withParserMessenger:)))
					{
						[_delegate libraryController:self didCreateNode:node withParserMessenger:inParserMessenger];
					}
					
					[[NSNotificationCenter defaultCenter] postNotificationName:kIMBDidCreateTopLevelNodeNotification object:node];
				}
			}
		});		
}


//----------------------------------------------------------------------------------------------------------------------


// Populate the specified node. This is done by a XPC service on our behalf. Once the service is done, 
// it will send back a reply with the new node as a result and call the completion block...

- (void) populateNode:(IMBNode*)inNode
{
	if ([inNode isGroupNode]) return;
	if ([inNode isPopulated]) return;
	if ([inNode error]) return;
	
	// Do not try to populate nodes if the backing library does not exist...
	
	else if (inNode.accessibility == kIMBResourceDoesNotExist)
	{
		return;
	}
			
	// Ask delegate whether we should populate this node...
			
	if (RESPONDS(_delegate,@selector(libraryController:shouldPopulateNode:)))
	{
		if (![_delegate libraryController:self shouldPopulateNode:inNode])
		{
			return;
		}
	}
	
	// Start populating this node...
	
	if (RESPONDS(_delegate,@selector(libraryController:willPopulateNode:)))
	{
		[_delegate libraryController:self willPopulateNode:inNode];
	}
			
	inNode.isLoading = YES;
	inNode.badgeTypeNormal = kIMBBadgeTypeLoading;

	NSString* parentNodeIdentifier = inNode.parentNode.identifier;
	IMBParserMessenger* messenger = inNode.parserMessenger;
	SBPerformSelectorAsync(messenger.connection,
                           messenger,
                           @selector(populateNode:error:),
                           inNode,
                           dispatch_get_main_queue(),
	
		^(IMBNode* inNewNode,NSError* inError)
		{
			// Got a new node. Do some consistency checks (was it populated correctly)...
			
			if (inError == nil)
			{
				if (inNewNode != nil && !inNewNode.isPopulated)
				{
					NSString* title = @"Programmer Error";
					NSString* description = [NSString stringWithFormat:
						@"The node '%@' returned by the parser %@ was not populated correctly.\n\nEither subnodes or objects is still nil.",
						inNode.name,
						inNewNode.parserIdentifier];
						
					NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
						title,@"title",
						description,NSLocalizedDescriptionKey,
						nil];
						
					inError = [NSError errorWithDomain:kIMBErrorDomain code:kIMBErrorInvalidState userInfo:info];
				}
			}
			
			if (inError) NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
			
			// If populating was successful we got a new node. Set the parserMessenger, and then  
			// replace the old with the new node...
			
			if (inNewNode)
			{
				inNewNode.error = inError;
				[self _setParserMessenger:messenger nodeTree:inNewNode];
				[self _replaceNode:inNode withNode:inNewNode parentNodeIdentifier:parentNodeIdentifier];
			
				if (RESPONDS(_delegate,@selector(libraryController:didPopulateNode:)))
				{
					[_delegate libraryController:self didPopulateNode:inNewNode];
				}
			}
			
			// If populating failed, then we'll have to keep the old node, but we'll clear the loading 
			// state and store an error instead (which is displayed as an alert badge)...
			
			else
			{
				inNode.isLoading = NO;
				inNode.badgeTypeNormal = kIMBBadgeTypeNone;
				inNode.error = inError;
			}
		});		
}


//----------------------------------------------------------------------------------------------------------------------


// Reload the specified node. This is done by a XPC service on our behalf. Once the service is done, it 
// will send back a reply with the new node as a result and call the completion block...

- (void) reloadNodeTree:(IMBNode*)inOldNode
{
	if ([inOldNode isGroupNode]) return;

	NSString* parentNodeIdentifier = inOldNode.parentNode.identifier;
	IMBParserMessenger* messenger = inOldNode.parserMessenger;
	
	// Ask delegate whether we should reload a node with this IMBParserMessenger...
			
	if (RESPONDS(_delegate,@selector(libraryController:shouldCreateNodeWithParserMessenger:)))
	{
		if (![_delegate libraryController:self shouldCreateNodeWithParserMessenger:messenger])
		{
			return;
		}
	}
	
	// Start reloading this node...
			
	if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:willCreateNodeWithParserMessenger:)])
	{
		[_delegate libraryController:self willCreateNodeWithParserMessenger:messenger];
	}
			
	inOldNode.isLoading = YES;
	inOldNode.badgeTypeNormal = kIMBBadgeTypeLoading;

	SBPerformSelectorAsync(messenger.connection,
                           messenger,
                           @selector(reloadNodeTree:error:),
                           inOldNode,
                           dispatch_get_main_queue(),
	
		^(IMBNode* inNewNode,NSError* inError)
		{
			// Display any errors that might have occurred...
					
			if (inError)
			{
				dispatch_async(dispatch_get_main_queue(),^()
				{
					NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
					inOldNode.isLoading = NO;
					inOldNode.badgeTypeNormal = kIMBBadgeTypeNone;
					inOldNode.error = inError;
				});
			}
			
			// Replace the old with the new node...
					
			else 
			{
				if (inNewNode)
				{
					[self _setParserMessenger:messenger nodeTree:inNewNode];
				}
				
				[self _replaceNode:inOldNode withNode:inNewNode parentNodeIdentifier:parentNodeIdentifier];

				if (inNewNode)
				{
					if (RESPONDS(_delegate,@selector(libraryController:didCreateNode:withParserMessenger:)))
					{
						[_delegate libraryController:self didCreateNode:inNewNode withParserMessenger:messenger];
					}
				}
			}
		});		
}


//----------------------------------------------------------------------------------------------------------------------


// Reload all of our top-level nodes. Please note that we may have to look one level deep, if the 
// nodes on the root level are group nodes...

- (void) _reloadTopLevelNodes
{
	NSArray* subnodes = [[self.subnodes copy] autorelease];
	
	for (IMBNode* node in subnodes)
	{
		if (node.isGroupNode)
		{
			NSArray* subnodes2 = [[node.subnodes copy] autorelease];
			
			for (IMBNode* node2 in subnodes2)
			{
				[self _reloadTopLevelNode:node2];
			}
		}
		else 
		{
			[self _reloadTopLevelNode:node];
		}
	}
}


// If the node still has a right right to exist then reload it. Otherwise remove from our data model...

- (void) _reloadTopLevelNode:(IMBNode*)inNode
{
	if (inNode.isTopLevelNode)
	{
		BOOL shouldReload = YES;
		
		if (RESPONDS(_delegate,@selector(libraryController:shouldCreateNodeWithParserMessenger:)))
		{
			shouldReload = [_delegate libraryController:self shouldCreateNodeWithParserMessenger:inNode.parserMessenger];
		}
		
		if (shouldReload)
		{
			[self reloadNodeTree:inNode];
		}
		else
		{
			[self _replaceNode:inNode withNode:nil parentNodeIdentifier:inNode.parentNode.identifier];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Recursively set the parserMessenger on all nodes and objects in this subtree. Without the pointer to
// the IMBParserMessenger these object would be pretty much unusable in the future...

- (void) _setParserMessenger:(IMBParserMessenger*)inMessenger nodeTree:(IMBNode*)inNode
{
	inNode.parserMessenger = inMessenger;
	
	for (IMBObject* object in inNode.objects)
	{
		object.parserMessenger = inMessenger;
	}
	
	for (IMBNode* subnode in inNode.subnodes)
	{
		[self _setParserMessenger:inMessenger nodeTree:subnode];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the correct group node for a given top-level node. Return nil if we did not provide a top-level
// node or if its groupType wasn't specified. If the group node doesn't exist yet, it will be newly created...

- (IMBNode*) _groupNodeForTopLevelNode:(IMBNode*)inNewNode
{
	NSUInteger groupType = inNewNode.groupType;
	if (groupType ==  kIMBGroupTypeNone) return nil;
	if (inNewNode.isTopLevelNode == NO) return nil;
	
	for (IMBNode* node in _subnodes)
	{
		if (node.groupType == groupType && node.isGroupNode == YES)
		{
			return node;
		}
	}

	IMBNode* groupNode = [[[IMBNode alloc] init] autorelease];
	groupNode.mediaType = self.mediaType;
	groupNode.isGroupNode = YES;
	groupNode.isTopLevelNode = NO;
	groupNode.isLeafNode = NO;
	groupNode.isUserAdded = NO;
	groupNode.isIncludedInPopup = YES;
	groupNode.parserIdentifier = nil;
	groupNode.parserMessenger = nil;
	groupNode.isLoading = NO;
	groupNode.badgeTypeNormal = kIMBBadgeTypeNone;
	
	if (groupType == kIMBGroupTypeLibrary)
	{
		groupNode.groupType = kIMBGroupTypeLibrary;
		groupNode.identifier = @"group://LIBRARIES";
		groupNode.name =  NSLocalizedStringWithDefaultValue(
			@"IMBLibraryController.groupnode.libraries",
			nil,IMBBundle(),
			@"LIBRARIES",
			@"group node display name");
	}
	else if (groupType == kIMBGroupTypeFolder)
	{
		groupNode.groupType = kIMBGroupTypeFolder;
		groupNode.identifier = @"group://FOLDERS";
		groupNode.name = NSLocalizedStringWithDefaultValue(
			@"IMBLibraryController.groupnode.folders",
			nil,IMBBundle(),
			@"FOLDERS",
			@"group node display name");
	}
	else if (groupType == kIMBGroupTypeSearches)
	{
		groupNode.groupType = kIMBGroupTypeSearches;
		groupNode.identifier = @"group://SEARCHES";
		groupNode.name = NSLocalizedStringWithDefaultValue(
			@"IMBLibraryController.groupnode.searches",
			nil,IMBBundle(),
			@"SEARCHES",
			@"group node display name");
	}
	else if (groupType == kIMBGroupTypeInternet)
	{
		groupNode.groupType = kIMBGroupTypeInternet;
		groupNode.identifier = @"group://INTERNET";
		groupNode.name = NSLocalizedStringWithDefaultValue(
			@"IMBLibraryController.groupnode.internet",
			nil,IMBBundle(),
			@"INTERNET",
			@"group node display name");
	}
	
	// Mark the newly created group node as populated...
	
	[groupNode mutableArrayForPopulatingSubnodes];
	groupNode.objects = [NSMutableArray array];

	// Insert the new group node at the correct location (so that we get a stable sort order)...
	
	NSMutableArray* subnodes = [self mutableArrayForPopulatingSubnodes];
	NSUInteger index = [IMBNode insertionIndexForNode:groupNode inSubnodes:subnodes];
	[subnodes insertObject:groupNode atIndex:index];

	return groupNode;
}


//----------------------------------------------------------------------------------------------------------------------


// This is the most important method in all of iMedia. All modifications of the node tree must go through
// here. This method is called asynchronously after one of the four methods above gets back its result 
// from an XPC service. The resulting node is then inserted in the node tree at the correct spot...

- (void) _replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode parentNodeIdentifier:(NSString*)inParentNodeIdentifier
{
	if (inOldNode == nil && inNewNode == nil) return;
	
	// Log an error if we are supposed to remove an old node, but it already removed from the tree...
	
	if (inOldNode != nil && inOldNode.parentNode == nil)
	{
		NSLog(@"%s inOldNode has already been removed. This was problably a race condition...",__FUNCTION__);
		return;
	}
	
	if (inOldNode != nil && inOldNode.parentNode == nil)
	{
		NSLog(@"%s inOldNode has already been removed. This was problably a race condition...",__FUNCTION__);
		return;
	}
	
	// Tell user interface that we are going to modify the data model...
	
	_isReplacingNode = YES;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillChangeNotification object:self];
    
	// To be safer, wrap everything in a try/catch block...
	
	@try      
    {
		// Update file system observing...
		
		NSString* oldWatchedPath = inOldNode.watchedPath;
		NSString* newWatchedPath = inNewNode.watchedPath;
		
		if (![oldWatchedPath isEqualToString:newWatchedPath])
		{
			if (oldWatchedPath != nil && inOldNode.watcherType == kIMBWatcherTypeFSEvent)
			{
				[[IMBFileSystemObserver sharedObserver] removePath:oldWatchedPath];
			}
			
			if (newWatchedPath != nil && inNewNode.watcherType == kIMBWatcherTypeFSEvent)
			{
				[[IMBFileSystemObserver sharedObserver] addPath:newWatchedPath];
			}
		}
		
		// Get the parent node. If the parent node for a top level node doesn't exist yet, 
		// then create an appropriate group node. Once we have the parent node, get its
		// subnodes array. This is where we need to do our work...
		
		IMBNode* parentNode = [self nodeWithIdentifier:inParentNodeIdentifier];
		
		if (parentNode == nil && [IMBConfig showsGroupNodes])
		{
			if (inOldNode) parentNode = [self _groupNodeForTopLevelNode:inOldNode];
			else if (inNewNode) parentNode = [self _groupNodeForTopLevelNode:inNewNode];
		}
		
		NSMutableArray* subnodes = nil;
		if (parentNode) subnodes = [parentNode mutableArrayForPopulatingSubnodes];
		else subnodes = [self mutableArrayForPopulatingSubnodes];

        // CASE 1: Replace a old with a new node...
        
		NSUInteger index = NSNotFound;

		if (inOldNode != nil && inNewNode != nil)
        {
			index = [subnodes indexOfObject:inOldNode];
			[subnodes replaceObjectAtIndex:index withObject:inNewNode];
		}
		
        // CASE 2: Remove the old node from the correct place...
        
		else if (inOldNode != nil)
        {
			index = [subnodes indexOfObject:inOldNode];
			[subnodes removeObjectAtIndex:index];
        }

        // CASE 3: Insert the new node at the correct (sorted) location...
            
        else if (inNewNode != nil)
        {
			index = [IMBNode insertionIndexForNode:inNewNode inSubnodes:subnodes];
			[subnodes insertObject:inNewNode atIndex:index];
        }

		// Remove loading badge from new node...
		
		if (inNewNode)
		{
			inNewNode.isLoading = NO;
			inNewNode.badgeTypeNormal = kIMBBadgeTypeNone;
		}
		
        // Remove empty group nodes (i.e. that do not have any subnodes). This may happen if we went 
		// through case 2 (removal of an existing node)...
        
		NSMutableArray* rootNodes = [self mutableArrayForPopulatingSubnodes];
		NSMutableArray* emptyGroupNodes = [NSMutableArray array];
		
		for (IMBNode* node in rootNodes)
		{
            if (node.isGroupNode && node.countOfSubnodes == 0)
            {
				[emptyGroupNodes addObject:node];
			}
		}
		
		[rootNodes removeObjectsInArray:emptyGroupNodes];
	}
	
	// We are now done...

    @finally
    {
        _isReplacingNode = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesDidChangeNotification object:self];
		
		// JUST TEMP:

//		if (inNewNode)
//		{
//			NSString* description = [inNewNode description];
//			NSLog(@"-------------------------------------------------------------------------------\n\n%@\n\n",description);
//		}	
	}
}


// Check if we have an access right book for this parserMessenger, and if so attach it...
	
//- (void) _attachAccessRightsBookmarksToParserMessenger:(IMBParserMessenger*)inParserMessenger
//{
//	NSArray* bookmarks = [[IMBAccessRightsController sharedAccessRightsController] bookmarks];
//	inParserMessenger.accessRightBookmarks = bookmarks;
//}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Node Accessors


// Node accessors. Use these for bindings the NSTreeController...

- (NSUInteger) countOfSubnodes
{
	return [_subnodes count];
}


- (IMBNode*) objectInSubnodesAtIndex:(NSUInteger)inIndex
{
	return [_subnodes objectAtIndex:inIndex];
}


- (void) insertObject:(IMBNode*)inNode inSubnodesAtIndex:(NSUInteger)inIndex
{
	if (_subnodes == nil)
	{
		self.subnodes = [NSMutableArray arrayWithCapacity:1];
	}
	
	if (inIndex <= _subnodes.count)
	{
		[_subnodes insertObject:inNode atIndex:inIndex];
	}
	else 
	{
		NSLog(@"%s ERROR trying to insert node at illegal index!",__FUNCTION__);
	}
}


- (void) removeObjectFromSubnodesAtIndex:(NSUInteger)inIndex
{
	if (inIndex < _subnodes.count)
	{
		[_subnodes removeObjectAtIndex:inIndex];
	}
	else 
	{
		NSLog(@"%s ERROR trying to remove node at illegal index!",__FUNCTION__);
	}
}


- (void) replaceObject:(IMBNode*)inNode inSubnodesAtIndex:(NSUInteger)inIndex
{
	if (inIndex < _subnodes.count)
	{
		[_subnodes replaceObjectAtIndex:inIndex withObject:inNode];
	}
	else 
	{
		NSLog(@"%s ERROR trying to replace node at illegal index!",__FUNCTION__);
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This accessor is only to be used by parser classes and IMBLibraryController, i.e. those participants that
// are offically allowed to mutate IMBNodes...

- (NSMutableArray*) mutableArrayForPopulatingSubnodes
{
	if (_subnodes == nil)
	{
		self.subnodes = [NSMutableArray arrayWithCapacity:1];
	}
	
	return [self mutableArrayValueForKey:@"subnodes"];
}


//----------------------------------------------------------------------------------------------------------------------


// Find all toplevel nodes that are not readable (because of sandbox access rights)...

- (void) _addNodesWithoutAccessRights:(NSArray*)inNodes toList:(NSMutableArray*)inList
{
	for (IMBNode* node in inNodes)
	{
		if (node.isGroupNode)
		{
			[self _addNodesWithoutAccessRights:node.subnodes toList:inList];
		}
		else if (node.accessibility == kIMBResourceNoPermission)
		{
			[inList addObject:node];
		}
	}
}

- (NSArray*) topLevelNodesWithoutAccessRights
{
	NSMutableArray* list = [NSMutableArray array];
	[self _addNodesWithoutAccessRights:_subnodes toList:list];
	return list;
}


- (NSArray*) libraryRootURLsForNodes:(NSArray*)inNodes
{
	NSMutableArray* urls = [NSMutableArray array];
	
	for (IMBNode* node in inNodes)
	{
        NSURL* libraryRootURL = [node libraryRootURL];
		if (libraryRootURL)
		{
			[urls addObject:libraryRootURL];
		}
	}

	return urls;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Find the node with the specified identifier...
	
- (IMBNode*) _nodeWithIdentifier:(NSString*)inIdentifier inParentNode:(IMBNode*)inParentNode
{
	NSArray* nodes = inParentNode ? inParentNode.subnodes : self.subnodes;
	
	for (IMBNode* node in nodes)
	{
		if ([node.identifier isEqualToString:inIdentifier])
		{
			return node;
		}
		else
		{
			IMBNode* match = [self _nodeWithIdentifier:inIdentifier inParentNode:node];
			if (match) return match;
		}
	}
	
	return nil;
}


- (IMBNode*) nodeWithIdentifier:(NSString*)inIdentifier
{
	if (inIdentifier)
	{
		return [self _nodeWithIdentifier:inIdentifier inParentNode:nil];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the root node for the specified parser. Please note that group nodes (LIBRARIES,FOLDERS,INTERNET,etc)
// are at the root level, so if we encounter one of those, we need to dig one level deeper...

- (IMBNode*) topLevelNodeForParserIdentifier:(NSString*)inParserIdentifier
{
	for (IMBNode* node in self.subnodes)
	{
		if (node.isGroupNode)
		{
			for (IMBNode* subnode in node.subnodes)
			{
				if ([subnode.parserIdentifier isEqualToString:inParserIdentifier])
				{
					return subnode;
				}
			}	
		}
		else if ([node.parserIdentifier isEqualToString:inParserIdentifier])
		{
			return node;
		}
	}

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Popup Menu


- (void) _recursivelyAddItemsToMenu:(NSMenu*)inMenu 
		 withNode:(IMBNode*)inNode 
		 indentation:(NSInteger)inIndentation 
		 selector:(SEL)inSelector 
		 target:(id)inTarget
{
	if (inNode!=nil && inNode.isIncludedInPopup)
	{
		// Create a menu item with the node name...
		
		NSImage* icon = inNode.icon;
		NSString* name = inNode.name;
		if (name == nil) name = @"";
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""];

		if (inNode.isGroupNode) 
		{
			[item setTarget:inTarget];						// Group nodes get a dummy action that will be disabled
			[item setAction:@selector(__dummyAction:)];		// in - [IMBNodeViewController validateMenuItem:]

			NSFont* font = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
			NSColor* color = [NSColor disabledControlTextColor];
			NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				font,NSFontAttributeName,
				color,NSForegroundColorAttributeName,
				nil];
				
			NSAttributedString* title = [[[NSAttributedString alloc] initWithString:name attributes:attributes] autorelease];
			[item setAttributedTitle:title];
		}
		else
		{
			[item setTarget:inTarget];						// Normal nodes get the desired target/action
			[item setAction:inSelector];
			
			if (!(inNode.accessibility == kIMBResourceIsAccessible)) // Inaccessible nodes also get a warning icon appended
			{
				NSFont* font = [NSFont menuFontOfSize:[NSFont systemFontSize]];
				NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					font,NSFontAttributeName,
					nil];
				
                NSString* iconName = nil;
                switch (inNode.accessibility)
                {
                    case kIMBResourceDoesNotExist:
                        iconName = @"IMBStopIcon.icns";
                        break;
                    case kIMBResourceNoPermission:
                        iconName = @"warning.tiff";
                        break;
                        
                    default:
                        iconName = @"warning.tiff";
                        break;
                }
				NSImage* icon = [[NSImage imb_imageNamed:iconName] copy];
				[icon setSize:NSMakeSize(16.0,16.0)];
				
				NSMutableAttributedString* title = [[[NSMutableAttributedString alloc] initWithString:name attributes:attributes] autorelease];
				NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:@" " attributes:attributes] autorelease];
				NSMutableAttributedString* warning = [[[NSMutableAttributedString alloc] initWithAttributedString:[icon attributedString]] autorelease];
				[warning addAttribute:NSBaselineOffsetAttributeName value:[NSNumber numberWithFloat:-3.0] range:NSMakeRange(0,1)];
				
				[title appendAttributedString:space];
				[title appendAttributedString:warning];
				[item setAttributedTitle:title];
				
				[icon release];
			}
		}
		
		[item setImage:icon];
		[item setRepresentedObject:inNode.identifier];
		[item setIndentationLevel:inIndentation];
		[inMenu addItem:item];
		[item release];
		
		// Add all subnodes indented by one...
		
		for (IMBNode* subnode in inNode.subnodes)
		{
			[self _recursivelyAddItemsToMenu:inMenu withNode:subnode indentation:inIndentation+1 selector:inSelector target:inTarget];
		}
	}
}


- (NSMenu*) menuWithSelector:(SEL)inSelector target:(id)inTarget addSeparators:(BOOL)inAddSeparator
{
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Library"];
	BOOL didAddSeparator = NO;
	
	// Walk through all nodes...
	
	for (IMBNode* node in _subnodes)
	{
		didAddSeparator = NO;
		
		// For regular nodes add recursively indented menu items, with separators...
		
		if (node.isUserAdded == NO)
		{
			[self _recursivelyAddItemsToMenu:menu withNode:node indentation:0 selector:inSelector target:inTarget];
			
			if (inAddSeparator)
			{
				[menu addItem:[NSMenuItem separatorItem]];
				didAddSeparator = YES;
			}	
		}
		
		// For custom folders, just add the top level nodes, all grouped together...
		
		else
		{
			NSImage* icon = node.icon;
			NSString* name = [node name];
			if (name == nil) name = @"";
			
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:name action:inSelector keyEquivalent:@""];
			[item setImage:icon];
			[item setRepresentedObject:node.identifier];
			[item setTarget:inTarget];
			[item setIndentationLevel:0];
			
			[menu addItem:item];
			[item release];
		}
	}
	
	// Get rid of any separator at the end of the menu...
	
	if (didAddSeparator) 
	{
		NSInteger n = [menu numberOfItems];
		[menu removeItemAtIndex:n-1];
	}
	
	return [menu autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark User Added Nodes


- (IMBParserMessenger*) addUserAddedNodeForFolder:(NSURL*)inFolderURL
{
	IMBParserMessenger* parserMessenger = nil;

	if (inFolderURL)
	{
		// Create an IMBFolderParser for our media type...
		
		NSString* mediaType = self.mediaType;
		
		if ([mediaType isEqualToString:kIMBMediaTypeImage])
		{
			parserMessenger = [[[IMBImageFolderParserMessenger alloc] init] autorelease];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeAudio])
		{
			parserMessenger = [[[IMBAudioFolderParserMessenger alloc] init] autorelease];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeMovie])
		{
			parserMessenger = [[[IMBMovieFolderParserMessenger alloc] init] autorelease];
		}

		parserMessenger.mediaSource = inFolderURL;
		parserMessenger.isUserAdded = YES;
		
		// Register it with the IMBParserController and reload...
		
		if (parserMessenger)
		{
            [IMBAccessRightsViewController grantAccessRightsForFolder:parserMessenger completionHandler:^()
            {
                [[IMBParserController sharedParserController] addUserAddedParserMessenger:parserMessenger];
                [self createTopLevelNodesWithParserMessenger:parserMessenger];
            }];
		}
	}
	
	return parserMessenger;
}


// If we were given a root node with a custom parser, then this node is eligible for removal. Remove the parser
// from the registered list and reload everything. After that the node will be gone...

- (BOOL) removeUserAddedNode:(IMBNode*)inNode
{
	if (inNode.isTopLevelNode && inNode.isUserAdded && !inNode.isLoading)
	{
		[[IMBParserController sharedParserController] removeUserAddedParserMessenger:inNode.parserMessenger];
		[self _replaceNode:inNode withNode:nil parentNodeIdentifier:inNode.parentNode.identifier];
		return YES;
	}
		
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Observe File System Changes


// Something on the file system has changed. Reload all nodes that are concerned by this event...

- (void) pathDidChange:(NSNotification*)inNotification 
{
	NSString* path = [inNotification object];
	[self _reloadNodesWithWatchedPath:path];
}


// Now look for all nodes that are interested in that path and reload them...

- (void) _reloadNodesWithWatchedPath:(NSString*)inPath
{
	[self _reloadNodesWithWatchedPath:inPath nodes:self.subnodes];
}	


- (void) _reloadNodesWithWatchedPath:(NSString*)inPath nodes:(NSArray*)inNodes
{
	NSString* watchedPath = [inPath stringByStandardizingPath];
	
	for (IMBNode* node in inNodes)
	{
		NSString* nodePath = [(NSString*)node.watchedPath stringByStandardizingPath];
		
		if ([nodePath isEqualToString:watchedPath])
		{
//			if ([node.parser respondsToSelector:@selector(watchedPathDidChange:)])
//			{
//				[node.parser watchedPathDidChange:watchedPath];
//			}
				
			[self reloadNodeTree:node];
		}
		else
		{
			[self _reloadNodesWithWatchedPath:inPath nodes:node.subnodes];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// When unmounting a volume, we need to stop the file watcher, or unmounting will fail. In this case we have to walk
// through the node tree and check which nodes are affected...


- (void) _willUnmountVolume:(NSNotification*)inNotification 
{
	NSString* volume = [[inNotification userInfo] objectForKey:@"NSDevicePath"];
	[self _unmountNodes: self.subnodes onVolume:volume];
}


- (void) _unmountNodes:(NSArray*)inNodes onVolume:(NSString*)inVolume 
{
	for (IMBNode* node in inNodes)
	{
		if (node.isGroupNode)
		{
			[self _unmountNodes:node.subnodes onVolume:inVolume];
		}
		else
		{
			NSURL* url = node.mediaSource;
			NSString* path = [[url path] stringByStandardizingPath];
			
			if ([path hasPrefix:inVolume])
			{
				NSString* watchedPath = node.watchedPath;
				if (watchedPath != nil && node.watcherType == kIMBWatcherTypeFSEvent)
				{
					[[IMBFileSystemObserver sharedObserver] removePath:watchedPath];
				}
			}
		}
	}
}


// The list of volume has changes (mount, unmount, or rename). We should really reload everything...

- (void) _volumesDidChange
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__volumesDidChange) object:nil];
	[self performSelector:@selector(__volumesDidChange) withObject:nil afterDelay:2.0];
}


- (void) __volumesDidChange
{
    if (IMBRunningOnLionOrNewer()) {
        [IMBPopover closeAllPopovers];
    }
	[self reload];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


+ (NSArray*) knownMediaTypes
{
	return [NSArray arrayWithObjects:kIMBMediaTypeImage,kIMBMediaTypeMovie,kIMBMediaTypeAudio,kIMBMediaTypeLink,nil];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Debugging


- (NSString*) description
{
	NSMutableString* text = [NSMutableString string];
	
	if (_subnodes)
	{
		for (IMBNode* node in _subnodes)
		{
			[text appendFormat:@"%@\n",[node description]];
		}
	}
	
	return text;
}


- (void) logNodes
{
	NSLog(@"-------------------------------------------------------------------------------\n\n%@\n",self.description);
}


//----------------------------------------------------------------------------------------------------------------------


@end

