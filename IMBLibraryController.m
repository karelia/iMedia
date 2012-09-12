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
#import "IMBOperationQueue.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBCommon.h"
#import "IMBConfig.h"
#import "IMBKQueue.h"
#import "IMBFSEventsWatcher.h"
#import "IMBImageFolderParser.h"
#import "IMBAudioFolderParser.h"
#import "IMBMovieFolderParser.h"
#import "NSWorkspace+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBNodesWillReloadNotification = @"IMBNodesWillReloadNotification";
NSString* kIMBNodesWillChangeNotification = @"IMBNodesWillChangeNotification";
NSString* kIMBNodesDidChangeNotification = @"IMBNodesDidChangeNotification";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableDictionary* sLibraryControllers = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private subclasses of NSOperation. The controller uses these internally to get background work done, but
// we do not want to expose these operations to developers who use iMedia.framework in their applications...

@interface IMBLibraryOperation : NSOperation
{
  @private
	IMBLibraryController* _libraryController;
	IMBParser* _parser;
	IMBOptions _options;
	IMBNode* _oldNode;		
	IMBNode* _replacementNode;
	NSString* _parentNodeIdentifier;
}

@property (retain) IMBLibraryController* libraryController;
@property (retain) IMBParser* parser;
@property (assign) IMBOptions options;
@property (retain) IMBNode* oldNode;	
@property (copy) IMBNode* replacementNode;		// Copied so that background operation can modify the node
@property (copy) NSString* parentNodeIdentifier;		

@end


@interface IMBCreateNodeOperation : IMBLibraryOperation
@end


@interface IMBPopulateNodeOperation : IMBLibraryOperation
@end


//----------------------------------------------------------------------------------------------------------------------


// Private controller methods...

@interface IMBLibraryController ()
- (void) _didCreateNode:(IMBNode*)inNode;
- (void) _didPopulateNode:(IMBNode*)inNode;
- (void) _replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode parentNodeIdentifier:(NSString*)inParentNodeIdentifier;
- (void) _presentError:(NSError*)inError;
- (void) _coalescedUKKQueueCallback;
- (void) _coalescedFSEventsCallback;
- (void) _reloadNodesWithWatchedPath:(NSString*)inPath;
- (void) _reloadNodesWithWatchedPath:(NSString*)inPath nodes:(NSArray*)inNodes;
- (void) _unmountNodes:(NSArray*)inNodes onVolume:(NSString*)inVolume;
- (void) _registerNodeForFileSystemNotificationsIfNeeded:(IMBNode*)theNode;
- (void) _unregisterNodeForFileSystemNotificationsIfNeeded:(IMBNode*)theNode;
- (void) _unregisterAllFileSystemNotifications;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Pass the new nodes back to the main thread where the IMBLibraryController assumes ownership   
// of them and discards the old nodes. The dictionary contains the following key/value pairs:
//
//   IMBNode* newNode
//   IMBNode* oldNode (optional)
//   NSError* error (optional)
	
	
@implementation IMBLibraryOperation

@synthesize libraryController = _libraryController;
@synthesize parser = _parser;
@synthesize options = _options;
@synthesize oldNode = _oldNode;
@synthesize replacementNode = _replacementNode;
@synthesize parentNodeIdentifier = _parentNodeIdentifier;


// General purpose method to send back results to controller in the main thread...

- (void) performSelectorOnMainThread:(SEL)inSelector withObject:(id)inObject
{
	[self.libraryController 
		performSelectorOnMainThread:inSelector
		withObject:inObject 
		waitUntilDone:NO 
		modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];	
}


// Specialized method that bundles old and new node, as well as potential error...

- (void) doReplacement
{
    if ([NSThread isMainThread])
    {
        [self.libraryController 
			_replaceNode:self.oldNode 
			withNode:self.replacementNode 
			parentNodeIdentifier:self.parentNodeIdentifier];
    }
    else
    {
		[self 
			performSelectorOnMainThread:_cmd
			withObject:nil 
			waitUntilDone:NO 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    }
}


// Cleanup...

- (void) dealloc
{
	IMBRelease(_libraryController);
	IMBRelease(_parser);
	IMBRelease(_oldNode);
	IMBRelease(_replacementNode);
	IMBRelease(_parentNodeIdentifier);
	
	[super dealloc];
}

@end


//----------------------------------------------------------------------------------------------------------------------


// Create a new node here in this background operation. When done, pass back the result to the libraryController 
// in the main thread...
	
	
@implementation IMBCreateNodeOperation

- (void) main
{
	NSError* error = nil;
    
    // This was using _parser ivar directly before with indication given as to it being necessary, so I'm switching to the proper accessor to see if it fixes my crash - Mike Abdullah
    IMBParser *parser = [self parser];
	[parser willUseParser];
	IMBNode* newNode = [parser nodeWithOldNode:self.oldNode options:self.options error:&error];
    self.replacementNode = newNode;
	
	if (newNode)
	{
		[self performSelectorOnMainThread:@selector(_didCreateNode:) withObject:newNode];
		[self doReplacement];
	}
	else
	{
		// Quick work-around for issue raised in https://github.com/karelia/iMedia/issues/61
		// Because the behavior before was to quietly ignore errors that didn't generate an actual error
		// object, let's perpetuate that for now to avoid the troublesome repeat error dialogs 
		// that occur when e.g. a customer has deleted a custom image folder source without removing
		// it first in iMedia...
		if (error != nil)
		{
			[self performSelectorOnMainThread:@selector(_presentError:) withObject:error];

			// If we failed then the _oldNode is still good but needs to have its status updated 
			self.oldNode.badgeTypeNormal = kIMBBadgeTypeNone;
		}
	}
}

@end


//----------------------------------------------------------------------------------------------------------------------


// Tell the parser to popuplate the node in this background operation. When done, pass back the result to  
// the libraryController in the main thread. If nodes are collapsed or deselected in the user interface, a 
// appropriate notification is sent out. Listen to these notifications and cancel any queued operations
// that are now obsolete...
	
	
@implementation IMBPopulateNodeOperation


- (void) main
{
	if (self.isCancelled == NO)
	{
		// This was using _paser ivar directly before with indication given as to it being necessary, so I'm switching to the proper accessor to see if it fixes my crash - Mike Abdullah
    IMBParser *parser = [self parser];
    [parser willUseParser];

    NSURL* securityScopedURL = nil;
    if (parser.bookmark != nil)
    {
      NSError* error = nil;
      securityScopedURL = [NSURL URLByResolvingBookmarkData:[parser bookmark]
                                                    options: NSURLBookmarkResolutionWithSecurityScope
                                              relativeToURL: nil
                                        bookmarkDataIsStale:NULL
                                                      error: &error];
      if (error != nil)
        securityScopedURL = nil;      
      if (securityScopedURL != nil)
      {
        if (![securityScopedURL imb_startAccessingSecurityScopedResource])
          securityScopedURL = nil;
      }
    }

    NSError* error = nil;
    if ([parser populateNode:self.replacementNode options:self.options error:&error])
		{
			[self performSelectorOnMainThread:@selector(_didPopulateNode:) withObject:self.replacementNode];
			[self doReplacement];
		}
		else
		{
			[self performSelectorOnMainThread:@selector(_presentError:) withObject:error];
			
			// If we failed then the _oldNode is still good but needs to have its status updated 
			self.oldNode.badgeTypeNormal = kIMBBadgeTypeNone;
		}
    
    [securityScopedURL imb_stopAccessingSecurityScopedResource];
	}
}


// When a populating is cancelled we need to revert the node to its original state, so that it can be populated
// again at a later time. This requires resetting the loading state and the badgeType...

- (void) cancel
{
	[super cancel];
	
	self.oldNode.loading = NO;
	self.oldNode.badgeTypeNormal = kIMBBadgeTypeNone;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLibraryController

@synthesize mediaType = _mediaType;
@synthesize rootNodes = _rootNodes;
@synthesize options = _options;
@synthesize delegate = _delegate;
@synthesize watcherUKKQueue = _watcherUKKQueue;
@synthesize watcherFSEvents = _watcherFSEvents;
@synthesize isReplacingNode = _isReplacingNode;


//----------------------------------------------------------------------------------------------------------------------


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
		self.rootNodes = [NSMutableArray array];
		self.options = kIMBOptionNone;
		
		// Initialize file system watching...
		
		self.watcherUKKQueue = [[[IMBKQueue alloc] init] autorelease];
		self.watcherUKKQueue.delegate = self;
		
		self.watcherFSEvents = [[[IMBFSEventsWatcher alloc] init] autorelease];
		self.watcherFSEvents.delegate = self;
		
		_isReplacingNode = NO;
		_watcherLock = [[NSRecursiveLock alloc] init];
		_watcherUKKQueuePaths = [[NSMutableArray alloc] init];
		_watcherFSEventsPaths = [[NSMutableArray alloc] init];
		
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
	IMBRelease(_rootNodes);
	IMBRelease(_watcherUKKQueue);
	IMBRelease(_watcherFSEvents);
	IMBRelease(_watcherLock);
	IMBRelease(_watcherUKKQueuePaths);
	IMBRelease(_watcherFSEventsPaths);

	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Creating Nodes

// This method triggers a full reload of all nodes. First remove all existing nodes. Then iterate over all 
// loaded parsers (for our media type) and tell them to load nodes in a background operation...

- (void) reload
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillReloadNotification object:self];

	NSArray* parsers = [[IMBParserController sharedParserController] parsersForMediaType:self.mediaType];

	// Unregister for any existing file system notifications
	[self _unregisterAllFileSystemNotifications];

	[self willChangeValueForKey:@"rootNodes"];
	[self.rootNodes removeAllObjects];
	[self didChangeValueForKey:@"rootNodes"];
	
	for (IMBParser* parser in parsers)
	{
		BOOL shouldCreateNode = YES;

		if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:shouldCreateNodeWithParser:)])
		{
			shouldCreateNode = [_delegate libraryController:self shouldCreateNodeWithParser:parser];
		}
		
		if (shouldCreateNode)
		{
			if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:willCreateNodeWithParser:)])
			{
				[_delegate libraryController:self willCreateNodeWithParser:parser];
			}

			IMBCreateNodeOperation* operation = [[IMBCreateNodeOperation alloc] init];
			operation.libraryController = self;
			operation.parser = parser;
			operation.options = self.options;
			operation.oldNode = nil;
			operation.parentNodeIdentifier = nil;
			
			[[IMBOperationQueue sharedQueue] addOperation:operation];
			[operation release];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// If the delegate allows reloading, then create a background operation that causes the parser to create a new node. 
// Please note that this method causes the node (and all its subnodes) to be replaced at a later time in the main 
// thread (once the background operation has concluded). Afterwards we have a different node instance! That way
// we can handle various different cases, like subnodes appearing/dissappearing, or objects appearing/disappearing.

- (void) reloadNode:(IMBNode*)inNode
{
	[self reloadNode:inNode parser:inNode.parser];
}


- (void) reloadNode:(IMBNode*)inNode parser:(IMBParser*)inParser
{
	BOOL shouldCreateNode = _isReplacingNode==NO;

	if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:shouldCreateNodeWithParser:)])
	{
		shouldCreateNode = [_delegate libraryController:self shouldCreateNodeWithParser:inNode.parser];
	}
	
	if (shouldCreateNode)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillReloadNotification object:self];

		if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:willCreateNodeWithParser:)])
		{
			[_delegate libraryController:self willCreateNodeWithParser:inNode.parser];
		}

		inNode.loading = YES;
		inNode.badgeTypeNormal = kIMBBadgeTypeLoading;
		
		IMBCreateNodeOperation* operation = [[IMBCreateNodeOperation alloc] init];
		operation.libraryController = self;
		operation.parser = inParser;
		operation.options = self.options;
		operation.oldNode = inNode;
		operation.parentNodeIdentifier = inNode.parentNode.identifier;
		
		[[IMBOperationQueue sharedQueue] addOperation:operation];
		[operation release];
	}	
}


//----------------------------------------------------------------------------------------------------------------------


// Check if the desired group node is already present. If yes return it, otherwise create and add it...

- (IMBNode*) _groupNodeForNewNode:(IMBNode*)inNewNode
{
	NSUInteger groupType = inNewNode.groupType;
	if (groupType ==  kIMBGroupTypeNone) return nil;
	
	for (IMBNode* node in _rootNodes)
	{
		if (node.groupType == groupType)
		{
			return node;
		}
	}
		
	IMBNode* groupNode = [[[IMBNode alloc] init] autorelease];
	groupNode.group = YES;
	groupNode.leaf = NO;
	groupNode.parser = nil;
	groupNode.subNodes = [NSMutableArray array];
	groupNode.objects = [NSMutableArray array];
	
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
	
	groupNode.parser = inNewNode.parser;	// Important to make lookup in -[IMBNode indexPath] work correctly!

	NSMutableArray* rootNodes = [NSMutableArray arrayWithArray:_rootNodes];
	[rootNodes addObject:groupNode];
	[rootNodes sortUsingSelector:@selector(compare:)];
	self.rootNodes = rootNodes;

	return groupNode;
}


//----------------------------------------------------------------------------------------------------------------------

// Centralize the registration and deregistration of file system changes, so we 
// can be more accountable to making sure we properly deregister when reloading.
//
// Note: Are KQueue type watches even used anymore? Maybe we can eliminate that.

- (void) _registerNodeForFileSystemNotificationsIfNeeded:(IMBNode*)theNode
{
	NSString* watchedPath = theNode.watchedPath;
	if (watchedPath)
	{
		if (theNode.watcherType == kIMBWatcherTypeKQueue)
			[self.watcherUKKQueue addPath:watchedPath];
		else if (theNode.watcherType == kIMBWatcherTypeFSEvent)
			[self.watcherFSEvents addURL:[NSURL fileURLWithPath:watchedPath] error:NULL];
	}
}

- (void) _unregisterNodeForFileSystemNotificationsIfNeeded:(IMBNode*)theNode
{
	NSString* watchedPath = theNode.watchedPath;
	if (watchedPath)
	{
		if (theNode.watcherType == kIMBWatcherTypeKQueue)
			[self.watcherUKKQueue removePath:watchedPath];
		else if (theNode.watcherType == kIMBWatcherTypeFSEvent)
			[self.watcherFSEvents removePath:watchedPath];
	}
}

- (void) _unregisterAllFileSystemNotifications
{
	[self.watcherUKKQueue removeAllPaths];
	[self.watcherFSEvents removeAllPaths];
}

// This method is called on the main thread as a result of any IMBLibraryOperation. We are given both the old  
// and the new node. Replace the old with the new node. The node we are given here can be a root node or a node
// somewhere deep inside the tree. So we need to find the correct place where to put the new node. Note that the 
// new node is registered with a file watcher (if desired) and the old node is unregistered...

- (void) _replaceNode:(NSDictionary*)inOldAndNewNode
{
	IMBNode* oldNode = [inOldAndNewNode objectForKey:@"oldNode"];
	IMBNode* newNode = [inOldAndNewNode objectForKey:@"newNode"];
    NSString* parentNodeIdentifier = [inOldAndNewNode objectForKey:@"parentNodeIdentifier"];
	
    [self _replaceNode:oldNode withNode:newNode parentNodeIdentifier:parentNodeIdentifier];
}


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

			[self _unregisterNodeForFileSystemNotificationsIfNeeded:inOldNode];

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

			[self _registerNodeForFileSystemNotificationsIfNeeded:inNewNode];
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


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the main thread as a result of IMBCreateNodesOperation...

- (void) _didCreateNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:didCreateNode:withParser:)])
	{
		[_delegate libraryController:self didCreateNode:inNode withParser:inNode.parser];
	}
	
	inNode.loading = NO;
	inNode.badgeTypeNormal = kIMBBadgeTypeNone;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the main thread incase an error has occurred in an IMBLibraryOperation...

- (void) _presentError:(NSError*)inError
{
	[NSApp presentError:inError];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Populating Nodes

// If a node doesn't have any subnodes yet, we need to create the subnodes lazily when this node is expanded.
// Also ask the delegate whether we are allowed to do so. Create an operation and put it on the queue to
// execute this job in the background.

// Please note the flag _isReplacingNode: It guards us from an unwanted recursion, as are being replaced in 
// _replaceNode:, the delegate method outlineViewItemWillExpand: is automatically called - i.e. without the 
// user actually clicking on a diclosure triangle. This seems to be some internal NSOutlineView behavior. 
// Obviously we need to suppress populating in this case or we'll cause an endless loop...

- (void) populateNode:(IMBNode*)inNode
{
	BOOL shouldPopulateNode = 
	
//		inNode.isPopulated==NO &&
		(inNode.subNodes==nil || inNode.objects==nil) && 
		inNode.isLoading==NO && 
		_isReplacingNode==NO;

	if (shouldPopulateNode)
	{
		if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:willPopulateNode:)])
		{
			[_delegate libraryController:self willPopulateNode:inNode];
		}

		inNode.loading = YES;
		inNode.badgeTypeNormal = kIMBBadgeTypeLoading;
		
		IMBPopulateNodeOperation* operation = [[IMBPopulateNodeOperation alloc] init];
		operation.libraryController = self;
		operation.parser = inNode.parser;
		operation.options = self.options;
		operation.oldNode = inNode;
		operation.replacementNode = inNode;		// This will automatically create a copy!
		operation.parentNodeIdentifier = inNode.parentNode.identifier;
		
		[[IMBOperationQueue sharedQueue] addOperation:operation];
		[operation release];
	}	
}


// Check all pending operation if there is a populate operation concerning the node in question. If yes, then
// cancel that one. Please note that this will probably have no effect if the operation is already executing - 
// i.e. unless the parser class is cancel-aware and exits its inner loop early...

- (void) stopPopulatingNodeWithIdentifier:(NSString*)inNodeIdentifier
{
	NSArray* operations = [[IMBOperationQueue sharedQueue] operations];
	
	for (NSOperation* operation in operations)
	{
		if ([operation isKindOfClass:[IMBPopulateNodeOperation class]])
		{
			IMBPopulateNodeOperation* populateOperation = (IMBPopulateNodeOperation*)operation;
			
			if ([populateOperation.oldNode.identifier isEqualToString:inNodeIdentifier])
			{
				[populateOperation cancel];
			}
		}
	}
}


// Called back in the main thread as a result of IMBExpandNodeOperation...

- (void) _didPopulateNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(libraryController:didPopulateNode:)])
	{
		[_delegate libraryController:self didPopulateNode:inNode];
	}

	inNode.loading = NO;
	inNode.badgeTypeNormal = kIMBBadgeTypeNone;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark File Watching

// A file watcher has fired for one of the paths we have registered. Since file watchers (especially UKKQueue can 
// fire multiple times for a single change) we need to coalesce the calls. Please note that the parameter inPath  
// is a different NSString instance every single time, so we cannot pass it as a param to the coalesced message 
// (canceling wouldn't work). Instead we'll put it in an array, which is iterated in _coalescedFileWatcherCallback...

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


// Given an array of paths, filter out all paths that are subpaths of others in the array.
// In other words only return the unique roots of a bunch of file system paths...

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


// Pass the message on to the main thread...

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


//----------------------------------------------------------------------------------------------------------------------


// When unmounting a volume, we need to stop the file watcher, or unmounting will fail. In this case we have to walk
// throughte node tree and check which nodes are affected. These nodes are removed from the tree. This will also
// take care of removing the offending file watcher...


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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Custom Nodes


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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Nodes Accessors

// Returns the root node for the specified parser. Please note that group nodes (LIBRARIES,FOLDERS,INTERNET,etc)
// are at the root level, so if we encounter one of those, we need to dig one level deeper...

- (IMBNode*) topLevelNodeForParser:(IMBParser*)inParser
{
	for (IMBNode* node in self.rootNodes)
	{
		if (node.isGroup)
		{
			for (IMBNode* subnode in node.subNodes)
			{
				if (subnode.parser == inParser)
				{
					return subnode;
				}
			}	
		}
		else if (node.parser == inParser)
		{
			return node;
		}
	}

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Find the node with the specified identifier...
	
- (IMBNode*) _nodeWithIdentifier:(NSString*)inIdentifier inParentNode:(IMBNode*)inParentNode
{
	NSArray* nodes = inParentNode ? inParentNode.subNodes : self.rootNodes;
	
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


- (void) logNodes
{
	NSMutableString* text = [NSMutableString string];
	
	if (_rootNodes)
	{
		for (IMBNode* node in _rootNodes)
		{
			[text appendFormat:@"%@\n",[node description]];
		}
	}
		
	NSLog(@"%s\n\n%@\n",__FUNCTION__,text);
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
		
		for (IMBNode* subnode in inNode.subNodes)
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
	
	for (IMBNode* node in _rootNodes)
	{
		didAddSeparator = NO;
		
		// For regular nodes add recursively indented menu items, with separators...
		
		if (node.parser.isCustom == NO)
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


@end

