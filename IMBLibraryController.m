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
//#import "IMBOperationQueue.h"
//#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBParserMessenger.h"
//#import "IMBCommon.h"
#import "IMBConfig.h"
//#import "IMBKQueue.h"
//#import "IMBFSEventsWatcher.h"
//#import "IMBImageFolderParser.h"
//#import "IMBAudioFolderParser.h"
//#import "IMBMovieFolderParser.h"
#import "NSWorkspace+iMedia.h"
#import <XPCKit/XPCKit.h>
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBNodesWillReloadNotification = @"IMBNodesWillReloadNotification";
NSString* kIMBNodesWillChangeNotification = @"IMBNodesWillChangeNotification";
NSString* kIMBNodesDidChangeNotification = @"IMBNodesDidChangeNotification";

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
- (void) _replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode parentNodeIdentifier:(NSString*)inParentNodeIdentifier;
- (IMBNode*) _groupNodeForTopLevelNode:(IMBNode*)inNewNode;
//- (void) _didCreateNode:(IMBNode*)inNode;
//- (void) _didPopulateNode:(IMBNode*)inNode;
//- (void) _presentError:(NSError*)inError;
//- (void) _coalescedUKKQueueCallback;
//- (void) _coalescedFSEventsCallback;
//- (void) _reloadNodesWithWatchedPath:(NSString*)inPath;
//- (void) _reloadNodesWithWatchedPath:(NSString*)inPath nodes:(NSArray*)inNodes;
//- (void) _unmountNodes:(NSArray*)inNodes onVolume:(NSString*)inVolume;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLibraryController

@synthesize mediaType = _mediaType;
@synthesize subnodes = _subnodes;
@synthesize delegate = _delegate;
//@synthesize watcherUKKQueue = _watcherUKKQueue;
//@synthesize watcherFSEvents = _watcherFSEvents;
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
		
		// Initialize file system watching...
		
//		self.watcherUKKQueue = [[[IMBKQueue alloc] init] autorelease];
//		self.watcherUKKQueue.delegate = self;
//		
//		self.watcherFSEvents = [[[IMBFSEventsWatcher alloc] init] autorelease];
//		self.watcherFSEvents.delegate = self;
		
//		_watcherLock = [[NSRecursiveLock alloc] init];
//		_watcherUKKQueuePaths = [[NSMutableArray alloc] init];
//		_watcherFSEventsPaths = [[NSMutableArray alloc] init];
		
		// When volume are unmounted we would like to be notified so that we can disable file watching for 
		// those paths...
		
		[[[NSWorkspace imb_threadSafeWorkspace] notificationCenter]
			addObserver:self 
			selector:@selector(_willUnmountVolume:)
			name:NSWorkspaceWillUnmountNotification 
			object:nil];
			
		[[[NSWorkspace imb_threadSafeWorkspace] notificationCenter]
			addObserver:self 
			selector:@selector(_didMountVolume:)
			name:NSWorkspaceDidMountNotification 
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[[NSWorkspace imb_threadSafeWorkspace] notificationCenter] removeObserver:self];

	IMBRelease(_mediaType);
	IMBRelease(_subnodes);
//	IMBRelease(_watcherUKKQueue);
//	IMBRelease(_watcherFSEvents);
//	IMBRelease(_watcherLock);
//	IMBRelease(_watcherUKKQueuePaths);
//	IMBRelease(_watcherFSEventsPaths);

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
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillReloadNotification object:self];

	// First call: create unpopulated top level nodes...
	
	if (self.subnodes == nil)
	{
		NSArray* messengers = [[IMBParserController sharedParserController] loadedParserMessengersForMediaType:self.mediaType];

		for (IMBParserMessenger* messenger in messengers)
		{
			// Ask delegate whether we should create nodes with this IMBParserMessenger...
			
			if (RESPONDS(_delegate,@selector(libraryController:shouldCreateNodeWithParserMessenger:)))
			{
				if (![_delegate libraryController:self shouldCreateNodeWithParserMessenger:messenger])
				{
					continue;
				}
			}
			
			// Create top-level nodes...
			
			if (RESPONDS(_delegate,@selector(libraryController:willCreateNodeWithParserMessenger:)))
			{
				[_delegate libraryController:self willCreateNodeWithParserMessenger:messenger];
			}
			
			XPCPerformSelectorAsync(messenger.connection,messenger,@selector(unpopulatedTopLevelNodes:),nil,
			
				^(NSArray* inNodes,NSError* inError)
				{
					dispatch_async(dispatch_get_main_queue(),^() // JUST TEMP until XPCKit is fixed
					{
						// Display any errors that might have occurred...
						
						if (inError)
						{
							NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
							[NSApp presentError:inError];
						}
						
						// Insert the new top-level nodes into our data model...
						
						else if (inNodes)
						{
							for (IMBNode* node in inNodes)
							{
								node.parserMessenger = messenger;
								[self _replaceNode:nil withNode:node parentNodeIdentifier:nil];

								if (RESPONDS(_delegate,@selector(libraryController:didCreateNode:withParserMessenger:)))
								{
									[_delegate libraryController:self didCreateNode:node withParserMessenger:messenger];
								}

								// JUST TEMP:
								if (!node.isLeaf)
								{
									[self performSelector:@selector(populateSubnodesOfNode:) withObject:node afterDelay:0.1];
								}
							}
						}
					});
				});		
		}
	}
	
	// Subsequent calls: reload existing nodes...
	
	else 
	{
		for (IMBNode* oldNode in self.subnodes)
		{
			[self reloadNode:oldNode];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Reload the specified node. This is done by a XPC service on our behalf. Once the service is done, it 
// will send back a reply with the new node as a result and call the completion block...

- (void) reloadNode:(IMBNode*)inOldNode
{
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
			
	inOldNode.loading = YES;
	inOldNode.badgeTypeNormal = kIMBBadgeTypeLoading;

	XPCPerformSelectorAsync(messenger.connection,messenger,@selector(reloadNode:error:),inOldNode,
	
		^(IMBNode* inNewNode,NSError* inError)
		{
			dispatch_async(dispatch_get_main_queue(),^() // JUST TEMP until XPCKit is fixed
			{
				// Display any errors that might have occurred...
						
				if (inError)
				{
					NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
					[NSApp presentError:inError];
				}
				
				// Replace the old with the new node...
						
				else if (inNewNode)
				{
					inNewNode.parserMessenger = messenger;
					[self _replaceNode:inOldNode withNode:inNewNode parentNodeIdentifier:parentNodeIdentifier];

					if (RESPONDS(_delegate,@selector(libraryController:didCreateNode:withParserMessenger:)))
					{
						[_delegate libraryController:self didCreateNode:inNewNode withParserMessenger:messenger];
					}
				}
			});
		});		
}


//----------------------------------------------------------------------------------------------------------------------


// Populate the subnodes of the specified node. This is done by a XPC service on our behalf. Once the  
// service is done, it will send back a reply with the new node as a result and call the completion block...

- (void) populateSubnodesOfNode:(IMBNode*)inNode
{
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
			
	inNode.loading = YES;
	inNode.badgeTypeNormal = kIMBBadgeTypeLoading;

	NSString* parentNodeIdentifier = inNode.parentNode.identifier;
	IMBParserMessenger* messenger = inNode.parserMessenger;
	XPCPerformSelectorAsync(messenger.connection,messenger,@selector(populateSubnodesOfNode:error:),inNode,
	
		^(IMBNode* inNewNode,NSError* inError)
		{
			dispatch_async(dispatch_get_main_queue(),^() // JUST TEMP until XPCKit is fixed
			{
				// Display any errors that might have occurred...
						
				if (inError)
				{
					NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
					[NSApp presentError:inError];
				}
				
				// Replace the old with the new node...
						
				else if (inNewNode)
				{
					inNewNode.parserMessenger = messenger;
					[self _replaceNode:inNode withNode:inNewNode parentNodeIdentifier:parentNodeIdentifier];

					if (RESPONDS(_delegate,@selector(libraryController:didPopulateNode:)))
					{
						[_delegate libraryController:self didPopulateNode:inNewNode];
					}

					// JUST TEMP:
					for (IMBNode* node in inNewNode.subnodes)
					{
						if (!node.isLeaf)
						{
							[self performSelector:@selector(populateSubnodesOfNode:) withObject:node afterDelay:0.1];
						}
					}
				}
			});
		});		
}


//----------------------------------------------------------------------------------------------------------------------


// Populate the objects of the specified node. This is done by a XPC service on our behalf. Once the  
// service is done, it will send back a reply with the new node as a result and call the completion block...

- (void) populateObjectsOfNode:(IMBNode*)inNode
{
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
			
	inNode.loading = YES;
	inNode.badgeTypeNormal = kIMBBadgeTypeLoading;

	NSString* parentNodeIdentifier = inNode.parentNode.identifier;
	IMBParserMessenger* messenger = inNode.parserMessenger;
	XPCPerformSelectorAsync(messenger.connection,messenger,@selector(populateObjectsOfNode:error:),inNode,
	
		^(IMBNode* inNewNode,NSError* inError)
		{
			dispatch_async(dispatch_get_main_queue(),^() // JUST TEMP until XPCKit is fixed
			{
				// Display any errors that might have occurred...
						
				if (inError)
				{
					NSLog(@"%s ERROR:\n\n%@",__FUNCTION__,inError);
					[NSApp presentError:inError];
				}

				// Replace the old with the new node...
						
				else if (inNewNode)
				{
					inNewNode.parserMessenger = messenger;
					[self _replaceNode:inNode withNode:inNewNode parentNodeIdentifier:parentNodeIdentifier];

					if (RESPONDS(_delegate,@selector(libraryController:didPopulateNode:)))
					{
						[_delegate libraryController:self didPopulateNode:inNewNode];
					}
				}
			});
		});		
}


//----------------------------------------------------------------------------------------------------------------------


// This is the most important method in all of iMedia. All modifications of the node tree must go through
// here. This method is called asynchronously after one of the four methods above gets back its result 
// from an XPC service. The resulting node is then inserted in the node tree at the correct spot...

- (void) _replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode parentNodeIdentifier:(NSString*)inParentNodeIdentifier
{
	if (inOldNode == nil && inNewNode == nil) return;
	
	// If we were given both old and new nodes, then the identifiers must be the same. If not log an error 
	// and throw an exception because this is a programmer error...
	
	if (inOldNode != nil && inNewNode != nil && ![inOldNode.identifier isEqual:inNewNode.identifier])
	{
		NSLog(@"%s Error: parent of oldNode and newNode must have same identifiers...",__FUNCTION__);
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: parent of oldNode and newNode must have same identifiers" userInfo:nil] raise];
	}
	
	// Tell user interface that we are going to modify the data model...
	
	_isReplacingNode = YES;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillChangeNotification object:self];
    
	// To be safer, wrap everything in a try/catch block...
	
	@try      
    {
		// Update file watching...
		
		// TODO
		
		// Get the parent node. If the parent node for a top level node doesn't exist yet, 
		// then create an appropriate group node...
		
		IMBNode* parentNode = [self nodeWithIdentifier:inParentNodeIdentifier];
		
		if (parentNode == nil && [IMBConfig showsGroupNodes])
		{
			if (inOldNode) parentNode = [self _groupNodeForTopLevelNode:inOldNode];
			else if (inNewNode) parentNode = [self _groupNodeForTopLevelNode:inNewNode];
		}
		
		// Get the subnodes array...
		
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
			inNewNode.loading = NO;
			inNewNode.badgeTypeNormal = kIMBBadgeTypeNone;
		}
		
        // Remove empty group nodes (i.e. that do not have any subnodes). This may happen if we went 
		// through case 2 (removal of an existing node)...
        
		NSMutableArray* rootNodes = [self mutableArrayForPopulatingSubnodes];
		NSMutableArray* emptyGroupNodes = [NSMutableArray array];
		
		for (IMBNode* node in rootNodes)
		{
            if (node.isGroup && node.countOfSubnodes == 0)
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
		[self logNodes];
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
		if (node.groupType == groupType && node.group == YES)
		{
			return node;
		}
	}

	IMBNode* groupNode = [[[IMBNode alloc] init] autorelease];
	groupNode.mediaType = self.mediaType;
	groupNode.group = YES;
	groupNode.leaf = NO;
	groupNode.isUserAdded = NO;
	groupNode.includedInPopup = YES;
	groupNode.parserIdentifier = nil;
	groupNode.parserMessenger = nil;
//	groupNode.parser = inNewNode.parser;	// Important to make lookup in -[IMBNode indexPath] work correctly!
	
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


// This method is called on the main thread as a result of any IMBLibraryOperation. We are given both the old  
// and the new node. Replace the old with the new node. The node we are given here can be a root node or a node
// somewhere deep inside the tree. So we need to find the correct place where to put the new node. Note that the 
// new node is registered with a file watcher (if desired) and the old node is unregistered...

/*
- (void) _replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode parentNodeIdentifier:(NSString*)inParentNodeIdentifier
{
	if (inOldNode == nil && inNewNode == nil) return;

	// If we were given both old and new nodes, then the parentNode and identifiers must be the same. 
	// If not log an error and throw an exception because this is a programmer error...

//	if (oldNode != nil && newNode != nil && oldNode.parentNode != newNode.parentNode && newNode.parentNode != nil)
//	{
//		NSLog(@"%s Error: parent of oldNode and newNode must be the same...",__FUNCTION__);
//		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: parent of oldNode and newNode must be the same" userInfo:nil] raise];
//	}

	if (inOldNode != nil && inNewNode != nil && ! [inOldNode.identifier isEqual:inNewNode.identifier])
	{
		NSLog(@"%s Error: parent of oldNode and newNode must have same identifiers...",__FUNCTION__);
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: parent of oldNode and newNode must have same identifiers" userInfo:nil] raise];
	}

	// Workaround for special behavior of IMBImageCaptureParser, which replaces root nodes several times  
	// as devices get hotplugged. We should probably remove this once IMBImageCaptureParser gets rewritten...
	
	if (inOldNode == nil && inNewNode != nil)	 
	{										
		IMBNode* node = [self nodeWithIdentifier:inNewNode.identifier];
		if (node) inOldNode = node;
	}

	// Tell IMBUserInterfaceController that we are going to modify the data model...

	_isReplacingNode = YES;

	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillChangeNotification object:self];

	@try      
    {
        // Find out where we are supposed to replace the old with the new node. We have three different cases:
        //   1) Both old and new node are supplied, so we need to replace. 
        //   2) Only old node is supplied, so it needs to be removed. 
        //   3) Only new node is supplied so it needs to be inserted.
        // We also have to distinguish between root of the tree and somewhere in the middle of the tree. Things 
        // are further complicated by the "group nodes" which are created dynamically in this method...

		IMBNode* parentNode = [self nodeWithIdentifier:inParentNodeIdentifier];
		BOOL shouldSortNodes = parentNode.isGroup;

		if (parentNode == nil)
		{
			if ([IMBConfig showsGroupNodes])
			{
				if (inOldNode) parentNode = [self _groupNodeForNewNode:inOldNode];
				else if (inNewNode) parentNode = [self _groupNodeForNewNode:inNewNode];
			}
			
			shouldSortNodes = YES;
		}

		NSMutableArray* nodes = parentNode!=nil ?
        [NSMutableArray arrayWithArray:parentNode.subNodes] :
        [NSMutableArray arrayWithArray:self.rootNodes];

        // Remove the old node from the correct place (but remember its index). Also unregister from file watching...

        NSUInteger index = NSNotFound;
        NSString* watchedPath = nil;

        if (inOldNode)
        {
            inOldNode.objects = nil;

            // It may well be that inOldNode is already replaced by some other node (see issue #33).
            // Make sure to treat that one to be the old node (nodes are equal but not necessarily identical).
            
            index = [nodes indexOfObject:inOldNode];

            if (index != NSNotFound)
            {
                inOldNode = [nodes objectAtIndex:index];
            }

            if ((watchedPath = inOldNode.watchedPath))
            {
                if (inOldNode.watcherType == kIMBWatcherTypeKQueue)
                    [self.watcherUKKQueue removePath:watchedPath];
                else if (inOldNode.watcherType == kIMBWatcherTypeFSEvent)
                    [self.watcherFSEvents removePath:watchedPath];
            }

            if (index != NSNotFound)
            {
                [nodes removeObjectAtIndex:index];
            }
        }

        // Insert the new node at the same index. Optionally register the node for file watching...

        if (inNewNode)
        {
            if (index == NSNotFound) index = nodes.count;
            [nodes insertObject:inNewNode atIndex:index];

            if ((watchedPath = inNewNode.watchedPath))
            {
                if (inNewNode.watcherType == kIMBWatcherTypeKQueue)
                    [self.watcherUKKQueue addPath:watchedPath];
                else if (inNewNode.watcherType == kIMBWatcherTypeFSEvent)
                    [self.watcherFSEvents addPath:watchedPath];
            }
        }

        // Sort the nodes so that they always appear in the same (stable) order...

        if (shouldSortNodes)
        {
            [nodes sortUsingSelector:@selector(compare:)];
        }

		// Do an "atomic" replace of the changed nodes array, thus only causing a single KVO notification. 
		// Please note the strange line setSubNodes:nil, which is a workaround for an nasty crashing bug deep  
		// inside NSTreeController, where we get a zombie NSTreeControllerTreeNode is some cases. Apparently 
		// the NSTreeController is very particular about us replacing the whole array in one go (maybe that 
		// isn't entirely KVO compliant), and it gets confused with its NSTreeControllerTreeNode objects.
		// The extra line (setting the array to nil) seems to clear out all NSTreeControllerTreeNodes and
		// then they get rebuilt with the next line. Until we rework our own stuff, we'll stick with this 
		// workaround...

		if (parentNode)
		{
			[parentNode setSubNodes:nil];		// Important workaround. Do not remove!
			[parentNode setSubNodes:nodes];
		}
		else
		{
			[self setRootNodes:nodes];
		}

        // Hide empty group nodes that do not have any subnodes We are not using fast enumeration here because
        // we may need to mutate the array. Iteration backwards avoids index adjustment problems as we 
        // remove nodes...

        NSMutableArray* rootNodes = [NSMutableArray arrayWithArray:self.rootNodes];
        NSUInteger n = [rootNodes count];

        for (NSInteger i=n-1; i>=0; i--)
        {
            IMBNode* node = [rootNodes objectAtIndex:i];
            
            if (node.isGroup && node.subNodes.count==0)
            {
                [rootNodes removeObjectIdenticalTo:node];
            }
        }

        NSUInteger m = [rootNodes count];

        if (n != m)
        {
            [self setRootNodes:rootNodes];
        }

		// Since setSubNodes: is a copy setter we need to get a pointer to the new instance before turning
		// off the loading state...

		IMBNode* node = [self nodeWithIdentifier:inNewNode.identifier];
		node.loading = NO;
		node.badgeTypeNormal = kIMBBadgeTypeNone;
	}

	// We are now done...

    @finally
    {
        _isReplacingNode = NO;

		[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesDidChangeNotification object:self];
    }
}
*/

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
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: trying to insert node at illegal index" userInfo:nil] raise];
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
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: trying to remove node at illegal index" userInfo:nil] raise];
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
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: trying to replace node at illegal index" userInfo:nil] raise];
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
		if (node.isGroup)
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
	if (inNode!=nil && inNode.includedInPopup)
	{
		// Create a menu item with the node name...
		
		NSImage* icon = inNode.icon;
		NSString* name = inNode.name;
		if (name == nil) name = @"";
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""];

		if (inNode.isGroup) 
		{
			[item setTarget:inTarget];						// Group nodes get a dummy action that will be disabled
			[item setAction:@selector(__dummyAction:)];		// in - [IMBNodeViewController validateMenuItem:]
		}
		else
		{
			[item setTarget:inTarget];						// Normal nodes get the desired target/action
			[item setAction:inSelector];
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
#pragma mark File Watching


// A file watcher has fired for one of the paths we have registered. Since file watchers (especially UKKQueue can 
// fire multiple times for a single change) we need to coalesce the calls. Please note that the parameter inPath  
// is a different NSString instance every single time, so we cannot pass it as a param to the coalesced message 
// (canceling wouldn't work). Instead we'll put it in an array, which is iterated in _coalescedFileWatcherCallback...
/*
- (void) watcher:(id<IMBFileWatcher>)inWatcher receivedNotification:(NSString*)inNotificationName forPath:(NSString*)inPath
{
//	NSLog(@"%s path=%@",__FUNCTION__,inPath);
	
	if ([inNotificationName isEqualToString:IMBFileWatcherWriteNotification])
	{
		if (inWatcher == _watcherUKKQueue)
		{
			[_watcherLock lock];
			if ([_watcherUKKQueuePaths indexOfObject:inPath] == NSNotFound) [_watcherUKKQueuePaths addObject:inPath];
			[_watcherLock unlock];
			
			SEL method = @selector(_coalescedUKKQueueCallback);
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:method object:nil];
			[self performSelector:method withObject:nil afterDelay:1.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		}
		else if (inWatcher == _watcherFSEvents)
		{
			[_watcherLock lock];
			if ([_watcherFSEventsPaths indexOfObject:inPath] == NSNotFound) [_watcherFSEventsPaths addObject:inPath];
			[_watcherLock unlock];

			SEL method = @selector(_coalescedFSEventsCallback);
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:method object:nil];
			[self performSelector:method withObject:nil afterDelay:1.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		}
	}
}
*/

// Given an array of paths, filter out all paths that are subpaths of others in the array.
// In other words only return the unique roots of a bunch of file system paths...
/*
+ (NSArray*) _rootPathsForPaths:(NSArray*)inAllPaths
{
	NSMutableArray* rootPaths = [NSMutableArray array];
	
	for (NSString* newPath in inAllPaths)
	{
		// First eliminate any existing rootPaths that are subpaths of a new path...
		
		NSInteger n = [rootPaths count];
		
		for (NSInteger i=n-1; i>=0; i--)
		{
			NSString* rootPath = [rootPaths objectAtIndex:i];
			
			if ([rootPath hasPrefix:newPath])
			{
				[rootPaths removeObjectAtIndex:i];
			}
		}
		
		// Add a new path if it is not a subpath (or equal) of another existing path...
		
		BOOL shouldAdd = YES;

		for (NSString* rootPath in rootPaths)
		{
			if ([newPath hasPrefix:rootPath])
			{
				shouldAdd = NO;
				break;
			}
		}
		
		if (shouldAdd) [rootPaths addObject:newPath];
	}
	
	return (NSArray*) rootPaths;
}
*/

// Pass the message on to the main thread...
/*
- (void) _coalescedUKKQueueCallback
{
	BOOL isMainThread = [NSThread isMainThread];
	
	[_watcherLock lock];
	
	for (NSString* path in _watcherUKKQueuePaths)
	{
		if (isMainThread) [self _reloadNodesWithWatchedPath:path];
		else [self performSelectorOnMainThread:@selector(_reloadNodesWithWatchedPath:) withObject:path waitUntilDone:NO];
	}
	
	[_watcherUKKQueuePaths removeAllObjects];
	[_watcherLock unlock];
}	


- (void) _coalescedFSEventsCallback
{
	BOOL isMainThread = [NSThread isMainThread];
	
	[_watcherLock lock];
	
	for (NSString* path in _watcherFSEventsPaths)
	{
		if (isMainThread) [self _reloadNodesWithWatchedPath:path];
		else [self performSelectorOnMainThread:@selector(_reloadNodesWithWatchedPath:) withObject:path waitUntilDone:NO];
	}
	
	[_watcherFSEventsPaths removeAllObjects];
	[_watcherLock unlock];
}	


// Now look for all nodes that are interested in that path and reload them...

- (void) _reloadNodesWithWatchedPath:(NSString*)inPath
{
	[self _reloadNodesWithWatchedPath:inPath nodes:self.rootNodes];
}	


- (void) _reloadNodesWithWatchedPath:(NSString*)inPath nodes:(NSArray*)inNodes
{
	NSString* watchedPath = [inPath stringByStandardizingPath];
	
	for (IMBNode* node in inNodes)
	{
		NSString* nodePath = [(NSString*)node.watchedPath stringByStandardizingPath];
		
		if ([nodePath isEqualToString:watchedPath])
		{
			if ([node.parser respondsToSelector:@selector(watchedPathDidChange:)])
			{
				[node.parser watchedPathDidChange:watchedPath];
			}
				
			[self reloadNode:node];
		}
		else
		{
			[self _reloadNodesWithWatchedPath:inPath nodes:node.subNodes];
		}
	}
}
*/

//----------------------------------------------------------------------------------------------------------------------


// When unmounting a volume, we need to stop the file watcher, or unmounting will fail. In this case we have to walk
// throughte node tree and check which nodes are affected. These nodes are removed from the tree. This will also
// take care of removing the offending file watcher...

/*
- (void) _willUnmountVolume:(NSNotification*)inNotification 
{
	NSString* volume = [[inNotification userInfo] objectForKey:@"NSDevicePath"];
	[self _unmountNodes: self.rootNodes onVolume:volume];
}


- (void) _unmountNodes:(NSArray*)inNodes onVolume:(NSString*)inVolume 
{
	for (IMBNode* node in inNodes)
	{
		NSString* path = node.watchedPath;
		IMBWatcherType type =  node.watcherType;
		
		if ((type == kIMBWatcherTypeKQueue || type == kIMBWatcherTypeFSEvent) && [path hasPrefix:inVolume])
		{
			NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:node,@"oldNode",nil];
			[self _replaceNode:info];
		}
		else
		{
			[self _unmountNodes:node.subNodes onVolume:inVolume];
		}
	}
}


// When a new volume is mounted, we have to assume that it contains a folder or library that we are interested in.
// Currently we are simply reloading everything, but in the future we could possibly be more intelligent about it 
// and reload just those nodes that are required and keep everything else intact...

- (void) _didMountVolume:(NSNotification*)inNotification 
{
	[self reload];
}

*/
//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Custom Nodes

/*
- (IMBParser*) addCustomRootNodeForFolder:(NSString*)inPath
{
	IMBParser* parser = nil;

	if (inPath)
	{
		// Create an IMBFolderParser for our media type...
		
		NSString* mediaType = self.mediaType;
		
		if ([mediaType isEqualToString:kIMBMediaTypeImage])
		{
			parser = [[[IMBImageFolderParser alloc] initWithMediaType:mediaType] autorelease];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeAudio])
		{
			parser = [[[IMBAudioFolderParser alloc] initWithMediaType:mediaType] autorelease];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeMovie])
		{
			parser = [[[IMBMovieFolderParser alloc] initWithMediaType:mediaType] autorelease];
		}

		parser.mediaSource = inPath;
		
		// Register it with the IMBParserController...
		
		if (parser)
		{
			[[IMBParserController sharedParserController] addCustomParser:parser forMediaType:mediaType];
		}
	}
	
	return parser;
}


// If we were given a root node with a custom parser, then this node is eligible for removal. Remove the parser
// from the registered list and reload everything. After that the node will be gone...

- (BOOL) removeCustomRootNode:(IMBNode*)inNode
{
	if (inNode.isTopLevelNode && inNode.parser.isCustom && !inNode.isLoading)
	{
		[[IMBParserController sharedParserController] removeCustomParser:inNode.parser];
		[self reload];
		return YES;
	}
		
	return NO;
}
*/

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

