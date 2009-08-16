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

#import "IMBLibraryController.h"
#import "IMBParserController.h"
#import "IMBOperationQueue.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBCommon.h"
#import "IMBKQueue.h"
#import "IMBFSEventsWatcher.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

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
	IMBLibraryController* _libraryController;
	IMBParser* _parser;
	IMBOptions _options;
	IMBNode* _oldNode;						
	IMBNode* _newNode;						
}

@property (retain) IMBLibraryController* libraryController;
@property (retain) IMBParser* parser;
@property (assign) IMBOptions options;
@property (retain) IMBNode* oldNode;	
@property (copy) IMBNode* newNode;		// Copied so that background operation can modify the node

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
- (void) _replaceNode:(NSDictionary*)inOldAndNewNode;
- (void) _presentError:(NSError*)inError;
- (void) _fileWatcherDidFireForPath:(NSString*)inPath;
- (void) _reloadNodesWithWatchedPath:(NSString*)inPath;
- (void) _reloadNodesWithWatchedPath:(NSString*)inPath nodes:(NSArray*)inNodes;
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
@synthesize newNode = _newNode;


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

- (void) replaceNode:(IMBNode*)inOldNode withNode:(IMBNode*)inNewNode
{
	NSMutableDictionary* result = [NSMutableDictionary dictionary];
	if (inNewNode) [result setObject:inNewNode forKey:@"newNode"];
	if (inOldNode) [result setObject:inOldNode forKey:@"oldNode"];

	[self performSelectorOnMainThread:@selector(_replaceNode:) withObject:result];
}


// Cleanup...

- (void) dealloc
{
	IMBRelease(_libraryController);
	IMBRelease(_parser);
	IMBRelease(_oldNode);
	IMBRelease(_newNode);
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
	[_parser willUseParser];
	IMBNode* newNode = [_parser nodeWithOldNode:self.oldNode options:self.options error:&error];
	
	if (error == nil)
	{
		[self performSelectorOnMainThread:@selector(_didCreateNode:) withObject:newNode];
		[self replaceNode:self.oldNode withNode:newNode];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(_presentError:) withObject:error];
	}
}


@end


//----------------------------------------------------------------------------------------------------------------------


// Tell the parser to popuplate the node in this background operation. When done, pass back the result to the 
// libraryController in the main thread...
	
@implementation IMBPopulateNodeOperation

- (void) main
{
	NSError* error = nil;
	[_parser willUseParser];
	[_parser populateNode:self.newNode options:self.options error:&error];
	
	if (error == nil)
	{
		[self performSelectorOnMainThread:@selector(_didPopulateNode:) withObject:self.newNode];
		[self replaceNode:self.oldNode withNode:self.newNode];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(_presentError:) withObject:error];
	}
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLibraryController

@synthesize mediaType = _mediaType;
@synthesize rootNodes = _rootNodes;
@synthesize options = _options;
@synthesize delegate = _delegate;
@synthesize watcherKQueue = _watcherKQueue;
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
		
		self.watcherKQueue = [[[IMBKQueue alloc] init] autorelease];
		self.watcherKQueue.delegate = self;
		
		self.watcherFSEvents = [[[IMBFSEventsWatcher alloc] init] autorelease];
		self.watcherFSEvents.delegate = self;
		
		_isReplacingNode = NO;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_mediaType);
	IMBRelease(_rootNodes);
	IMBRelease(_watcherKQueue);
	IMBRelease(_watcherFSEvents);

	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Creating Nodes


// This method triggers a full reload of all nodes. First remove all existing nodes. Then iterate over all 
// loaded parsers (for our media type) and tell them to load nodes in a background operation...

- (void) reload
{
	NSMutableArray* parsers = [[IMBParserController sharedParserController] loadedParsersForMediaType:self.mediaType];
	
	[self willChangeValueForKey:@"rootNodes"];
	[self.rootNodes removeAllObjects];
	[self didChangeValueForKey:@"rootNodes"];
	
	for (IMBParser* parser in parsers)
	{
		BOOL shouldCreateNode = YES;

		if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:shouldCreateNodeWithParser:)])
		{
			shouldCreateNode = [_delegate controller:self shouldCreateNodeWithParser:parser];
		}
		
		if (shouldCreateNode)
		{
			if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:willCreateNodeWithParser:)])
			{
				[_delegate controller:self willCreateNodeWithParser:parser];
			}

			IMBCreateNodeOperation* operation = [[IMBCreateNodeOperation alloc] init];
			operation.libraryController = self;
			operation.parser = parser;
			operation.options = self.options;
			operation.oldNode = nil;
			
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
	BOOL shouldCreateNode = _isReplacingNode==NO;

	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:shouldCreateNodeWithParser:)])
	{
		shouldCreateNode = [_delegate controller:self shouldCreateNodeWithParser:inNode.parser];
	}
	
	if (shouldCreateNode)
	{
		if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:willCreateNodeWithParser:)])
		{
			[_delegate controller:self willCreateNodeWithParser:inNode.parser];
		}

		inNode.loading = YES;
		inNode.badgeTypeNormal = kIMBBadgeTypeLoading;
		
		IMBCreateNodeOperation* operation = [[IMBCreateNodeOperation alloc] init];
		operation.libraryController = self;
		operation.parser = inNode.parser;
		operation.options = self.options;
		operation.oldNode = inNode;
		
		[[IMBOperationQueue sharedQueue] addOperation:operation];
		[operation release];
	}	
}



//----------------------------------------------------------------------------------------------------------------------


// Check if the desired group node is already present. If yes return it, otherwise create and add it...

- (IMBNode*) _groupNodeForNewNode:(IMBNode*)inNewNode
{
	NSString* groupType = inNewNode.groupType;
	if (groupType ==  nil) return nil;
	
	for (IMBNode* node in _rootNodes)
	{
		if ([node.groupType isEqualToString:groupType])
		{
			return node;
		}
	}
		
	IMBNode* groupNode = [[[IMBNode alloc] init] autorelease];
	groupNode.group = YES;
	groupNode.leaf = NO;
	groupNode.parentNode = nil;
	groupNode.parser = nil;
	groupNode.subNodes = [NSMutableArray array];
	groupNode.objects = [NSMutableArray array];
	
	if ([groupType isEqualToString:kIMBGroupTypeLibrary])
	{
		groupNode.groupType = kIMBGroupTypeLibrary;
		groupNode.identifier = @"group://LIBRARY";
		groupNode.name = @"LIBRARIES";
	}
	else if ([groupType isEqualToString:kIMBGroupTypeFolder])
	{
		groupNode.groupType = kIMBGroupTypeFolder;
		groupNode.identifier = @"group://FOLDER";
		groupNode.name = @"FOLDERS";
	}
	else if ([groupType isEqualToString:kIMBGroupTypeDevice])
	{
		groupNode.groupType = kIMBGroupTypeDevice;
		groupNode.identifier = @"group://DEVICE";
		groupNode.name = @"DEVICES";
	}
	else if ([groupType isEqualToString:kIMBGroupTypeCustom])
	{
		groupNode.groupType = kIMBGroupTypeCustom;
		groupNode.identifier = @"group://CUSTOM";
		groupNode.name = @"CUSTOM";
	}
	
	groupNode.parser = inNewNode.parser;	// Important to make lookup in -[IMBNode indexPath] work correctly!

	[self willChangeValueForKey:@"rootNodes"];
	[_rootNodes addObject:groupNode];
	[_rootNodes sortUsingSelector:@selector(compare:)];
	[self didChangeValueForKey:@"rootNodes"];

	return groupNode;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the main thread as a result of any IMBLibraryOperation. We are given both the old  
// and the new node. Replace the old with the new node. The node we are given here can be a root node or a node
// somewhere deep inside the tree. So we need to find the correct place where to put the new node. Note that the 
// new node is registered with a file watcher (if desired) and the old node is unregistered...

- (void) _replaceNode:(NSDictionary*)inOldAndNewNode
{
	NSString* watchedPath = nil;
	
	_isReplacingNode = YES;
	
	// Tell IMBUserInterfaceController that we are going to modify the data model...
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesWillChangeNotification object:self];
	
	// If we were given both old and new nodes, then the parentNode must be the same. If not log an error. 
	// Maybe we should also throw an exception because this is a programmer error...
	
	IMBNode* oldNode = [inOldAndNewNode objectForKey:@"oldNode"];
	IMBNode* newNode = [inOldAndNewNode objectForKey:@"newNode"];
	
	if (oldNode!=nil && newNode!=nil && oldNode.parentNode!=oldNode.parentNode)
	{
		NSLog(@"%s Error parent of oldNode and newNode must be the same...");
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error parent of oldNode and newNode must be the same" userInfo:nil] raise];
	}
	
	// The parentNode property of the node tells us where we are supposed to replace the old with the 
	// new node. If parentNode is nil then we are going to use the root level array...

	IMBNode* groupNode = [self _groupNodeForNewNode:newNode];

	IMBNode* parent = nil;
	if (newNode) parent = newNode.parentNode;
	else if (oldNode) parent = oldNode.parentNode;
	
	if (parent==nil && groupNode!=nil)
	{
		parent = groupNode;
		newNode.parentNode = groupNode;
	}
	
	NSMutableArray* siblings = nil;
	if (parent) siblings = [parent mutableArrayValueForKey:@"subNodes"];
	else siblings = [self mutableArrayValueForKey:@"rootNodes"];

	// Remove the old node from the correct place (but remember its index). Also unregister from file watching...
	
	if (parent) [parent willChangeValueForKey:@"subNodes"];
	else [self willChangeValueForKey:@"rootNodes"];

	NSUInteger index = NSNotFound;
	
	if (oldNode)
	{
		if (watchedPath = oldNode.watchedPath)
		{
			if (oldNode.watcherType == kIMBWatcherTypeKQueue)
				[self.watcherKQueue removePath:watchedPath];
			else if (oldNode.watcherType == kIMBWatcherTypeFSEvent)
				[self.watcherFSEvents removePath:watchedPath];
		}
			
		index = [siblings indexOfObjectIdenticalTo:oldNode];
		[siblings removeObjectIdenticalTo:oldNode];
	}
	
	// Insert the new node in the same location. Optionally register the node for file watching...
		
	if (newNode)
	{
		if (index == NSNotFound) index = siblings.count;
		[siblings insertObject:newNode atIndex:index];
		
		if (watchedPath = newNode.watchedPath)
		{
			if (newNode.watcherType == kIMBWatcherTypeKQueue)
				[self.watcherKQueue addPath:watchedPath];
			else if (newNode.watcherType == kIMBWatcherTypeFSEvent)
				[self.watcherFSEvents addPath:watchedPath];
		}
	}
	
	// Sort the root nodes and first level of group nodes...
	
	if (newNode.parentNode == nil)
	{
		[self.rootNodes sortUsingSelector:@selector(compare:)];
	}
	
	for (IMBNode* node in self.rootNodes)
	{
		if (node.isGroup)
		{
			[(NSMutableArray*)node.subNodes sortUsingSelector:@selector(compare:)];
		}
	}
	
	// We are now done...
	
	if (parent) [parent didChangeValueForKey:@"subNodes"];
	else [self didChangeValueForKey:@"rootNodes"];
	_isReplacingNode = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesDidChangeNotification object:self];
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the main thread as a result of IMBCreateNodesOperation...

- (void) _didCreateNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:didCreateNode:withParser:)])
	{
		[_delegate controller:self didCreateNode:inNode withParser:inNode.parser];
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
// execute this job in the background...

- (void) populateNode:(IMBNode*)inNode
{
	BOOL shouldPopulateNode = 
	
		(inNode.subNodes==nil || inNode.objects==nil) && 
		inNode.isLoading==NO && 
		_isReplacingNode==NO;

	if (shouldPopulateNode)
	{
		if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:willPopulateNode:)])
		{
			[_delegate controller:self willPopulateNode:inNode];
		}

		inNode.loading = YES;
		inNode.badgeTypeNormal = kIMBBadgeTypeLoading;
		
		IMBPopulateNodeOperation* operation = [[IMBPopulateNodeOperation alloc] init];
		operation.libraryController = self;
		operation.parser = inNode.parser;
		operation.options = self.options;
		operation.oldNode = inNode;
		operation.newNode = inNode;		// This will automatically create a copy!
		
		[[IMBOperationQueue sharedQueue] addOperation:operation];
		[operation release];
	}	
}


// Called back in the main thread as a result of IMBExpandNodeOperation...

- (void) _didPopulateNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:didPopulateNode:)])
	{
		[_delegate controller:self didPopulateNode:inNode];
	}

	inNode.loading = NO;
	inNode.badgeTypeNormal = kIMBBadgeTypeNone;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark File Watching


// A file watcher has fired for one of the paths we have registered...

- (void) watcher:(id<IMBFileWatcher>)inWatcher receivedNotification:(NSString*)inNotificationName forPath:(NSString*)inPath
{
	if ([inNotificationName isEqualToString:IMBFileWatcherRenameNotification] ||
		[inNotificationName isEqualToString:IMBFileWatcherWriteNotification] ||
		[inNotificationName isEqualToString:IMBFileWatcherDeleteNotification] )
	{
		SEL method = @selector(_fileWatcherDidFireForPath:);
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:method object:inPath];
		[self performSelector:method withObject:inPath afterDelay:0.5 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
}


// Pass the message on to the main thread...

- (void) _fileWatcherDidFireForPath:(NSString*)inPath
{
	if ([NSThread isMainThread])
	{
		[self _reloadNodesWithWatchedPath:inPath];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(_reloadNodesWithWatchedPath:) withObject:inPath waitUntilDone:NO];
	}
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
		NSString* nodePath = [(NSString*)node.mediaSource stringByStandardizingPath];
		
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


#pragma mark 
#pragma mark Custom Nodes


- (void) addCustomRootNodeForFolder:(NSString*)inPath
{
	NSBeep();
}


- (BOOL) removeCustomRootNode:(IMBNode*)inNode
{
	if (inNode.parentNode==nil && inNode.parser.isCustom && !inNode.isLoading)
	{
		NSBeep();
		return YES;
	}
		
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Nodes Accessors


// Returns the root node for the specified parser...

- (IMBNode*) rootNodeForParser:(IMBParser*)inParser
{
	for (IMBNode* node in self.rootNodes)
	{
		if (node.parser == inParser)
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
		 indentation:(int)inIndentation 
		 selector:(SEL)inSelector 
		 target:(id)inTarget
{
	if (inNode)
	{
		// Create a menu item with the node name...
		
		NSString* name = inNode.name;
		if (name == nil) name = @"";

		NSImage* icon = inNode.icon;
		[icon setSize:NSMakeSize(16,16)];
		
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
			NSString* name = [node name];
			if (name == nil) name = @"";
			
			NSImage* icon = node.icon;
			[icon setSize:NSMakeSize(16,16)];

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
		int n = [menu numberOfItems];
		[menu removeItemAtIndex:n-1];
	}
	
	return [menu autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


@end



