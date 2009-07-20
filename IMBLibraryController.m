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

#import "IMBLibraryController.h"
#import "IMBParserController.h"
#import "IMBOperationQueue.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBCommon.h"


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

//- (void) replaceNode:(NSDictionary*)inOldAndNewNode;

@end


@interface IMBCreateNodeOperation : IMBLibraryOperation
@end


@interface IMBExpandNodeOperation : IMBLibraryOperation
@end


@interface IMBSelectNodeOperation : IMBLibraryOperation
@end


// Private controller methods...

@interface IMBLibraryController ()
- (void) _didCreateNode:(IMBNode*)inNode;
- (void) _didExpandNode:(IMBNode*)inNode;
- (void) _didSelectNode:(IMBNode*)inNode;
- (void) _replaceNode:(NSDictionary*)inOldAndNewNode;
- (void) _presentError:(NSError*)inError;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Pass the new nodes back to the main thread where the IMBLibraryController assumes ownership   
// of them and discards the old nodes. The dictionary contains the following key/value pairs:
//
//   NSArray* newNodes
//   NSArray* oldNodes (optional)
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
// in the main thread and notify the delegate...
	
@implementation IMBCreateNodeOperation

- (void) main
{
	NSError* error = nil;
	IMBNode* newNode = [_parser createNode:self.oldNode options:self.options error:&error];
	
	if (error == nil)
	{
		[self replaceNode:self.oldNode withNode:newNode];
		[self performSelectorOnMainThread:@selector(_didCreateNode:) withObject:newNode];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(_presentError:) withObject:error];
	}
}


@end


//----------------------------------------------------------------------------------------------------------------------


// Tell the parser to popuplate the node in this background operation. When done, pass back the result to the 
// libraryController in the main thread and notify the delegate...
	
@implementation IMBExpandNodeOperation

- (void) main
{
	NSError* error = nil;
	[_parser expandNode:self.newNode options:self.options error:&error];
	
	if (error == nil)
	{
		[self replaceNode:self.oldNode withNode:self.newNode];
		[self performSelectorOnMainThread:@selector(_didExpandNode:) withObject:self.newNode];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(_presentError:) withObject:error];
	}
}

@end


//----------------------------------------------------------------------------------------------------------------------


// Tell parser to popuplate the node here in this background operation. When done, pass back the result to the 
// libraryController in the main thread and notify the delegate...
	
@implementation IMBSelectNodeOperation

- (void) main
{
	NSError* error = nil;
	[_parser populatedNode:self.newNode options:self.options error:&error];
	
	if (error == nil)
	{
		[self replaceNode:self.oldNode withNode:self.newNode];
		[self performSelectorOnMainThread:@selector(_didSelectNode:) withObject:self.newNode];
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
@synthesize nodes = _nodes;
@synthesize options = _options;
@synthesize delegate = _delegate;


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
		self.nodes = [NSMutableArray array];
		self.options = kIMBOptionNone;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_mediaType);
	IMBRelease(_nodes);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// This method triggers a full reload of all nodes. First remove all existing nodes. Then iterate over all 
// loaded parsers (for our media type) and tell them to load nodes in a background operation...

- (void) reload
{
	NSMutableArray* parsers = [[IMBParserController sharedParserController] loadedParsersForMediaType:self.mediaType];
	[self.nodes removeAllObjects];
	
	for (IMBParser* parser in parsers)
	{
		BOOL shouldCreateNode = YES;

		if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:willCreateNodeWithParser:)])
		{
			shouldCreateNode = [_delegate controller:self willCreateNodeWithParser:parser];
		}
		
		if (shouldCreateNode)
		{
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


// For each node in the list, change its state to loading (so that the spinning activity indicator appears), 
// then create a background operation that causes the parser to create a new node...

- (void) reloadNode:(IMBNode*)inNode
{
	BOOL shouldCreateNode = YES;

	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:willCreateNodeWithParser:)])
	{
		shouldCreateNode = [_delegate controller:self willCreateNodeWithParser:inNode.parser];
	}
	
	if (shouldCreateNode)
	{
		IMBCreateNodeOperation* operation = [[IMBCreateNodeOperation alloc] init];
		operation.libraryController = self;
		operation.parser = inNode.parser;
		operation.options = self.options;
		operation.oldNode = inNode;
		
		[[IMBOperationQueue sharedQueue] addOperation:operation];
		[operation release];
	}	
}



// This method is called on the main thread as a result of any IMBLibraryOperation. We are given both the old  
// and the new node. Replace the old with the new node...

- (void) _replaceNode:(NSDictionary*)inOldAndNewNode
{
	// Tell IMBUserInterfaceController that we are goind to modify the data model...
	
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

	IMBNode* parent = nil;
	
	if (newNode)
		parent = newNode.parentNode;
	else if (oldNode)
		parent = oldNode.parentNode;
	
	NSMutableArray* siblings = nil;
//	siblings = parent ? (NSMutableArray*)parent.subNodes : self.nodes;

	if (parent)
		siblings = [parent mutableArrayValueForKey:@"subNodes"];
	else
		siblings = [self mutableArrayValueForKey:@"nodes"];

	// Remove the old node from the correct place (but remember its index)...
	
	if (parent) [parent willChangeValueForKey:@"subNodes"];
	else [self willChangeValueForKey:@"nodes"];

	NSUInteger index = NSNotFound;
	
	if (oldNode)
	{
		index = [siblings indexOfObjectIdenticalTo:oldNode];
//		NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:index];
//
//		if (parent) [parent willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"subNodes"];
//		else [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"nodes"];

		[siblings removeObjectIdenticalTo:oldNode];
		
//		if (parent) [parent didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"subNodes"];
//		else [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"nodes"];
	}
	
	// Insert the new node in the same location...
		
	if (newNode)
	{
		if (index == NSNotFound) index = siblings.count;
//		NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:index];
//
//		if (parent) [parent willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"subNodes"];
//		else [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"nodes"];

		[siblings insertObject:newNode atIndex:index];
		
//		if (parent) [parent willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"subNodes"];
//		else [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"nodes"];
	}
	
	if (parent) [parent didChangeValueForKey:@"subNodes"];
	else [self didChangeValueForKey:@"nodes"];
	
	// Tell IMBUserInterfaceController that we are done modifying the data model...
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBNodesDidChangeNotification object:self];
}


// This method is called on the main thread as a result of IMBCreateNodesOperation...

- (void) _didCreateNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:didCreateNode:withParser:)])
	{
		[_delegate controller:self didCreateNode:inNode withParser:inNode.parser];
	}
}

// This method is called on the main thread incase an error has occurred in an IMBLibraryOperation...

- (void) _presentError:(NSError*)inError
{
	[NSApp presentError:inError];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// If a node doesn't have any subnodes yet, we need to create the subnodes lazily when this node is expanded.
// Also ask the delegate whether we are allowed to do so. Create an operation and put it on the queue to
// execute this job in the background...

- (void) expandNode:(IMBNode*)inNode
{
	BOOL shouldExpandNode = inNode.subNodes == nil;

	if (shouldExpandNode && _delegate != nil && [_delegate respondsToSelector:@selector(controller:willExpandNode:)])
	{
		shouldExpandNode = [_delegate controller:self willExpandNode:inNode];
	}
	
	if (shouldExpandNode)
	{
		IMBExpandNodeOperation* operation = [[IMBExpandNodeOperation alloc] init];
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

- (void) _didExpandNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:didExpandNode:)])
	{
		[_delegate controller:self didExpandNode:inNode];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// If a node wasn't populated with objects yet, we need to populated it lazily when this node is selected.
// Also ask the delegate whether we are allowed to do so. Create an operation and put it on the queue to
// execute this job in the background...

- (void) selectNode:(IMBNode*)inNode
{
	BOOL shouldSelectNode = inNode.objects == nil;

	if (shouldSelectNode && _delegate != nil && [_delegate respondsToSelector:@selector(controller:willSelectNode:)])
	{
		shouldSelectNode = [_delegate controller:self willSelectNode:inNode];
	}
	
	if (shouldSelectNode)
	{
		IMBSelectNodeOperation* operation = [[IMBSelectNodeOperation alloc] init];
		operation.libraryController = self;
		operation.parser = inNode.parser;
		operation.options = self.options;
		operation.oldNode = inNode;
		operation.newNode = inNode;		// This will automatically create a copy!
		
		[[IMBOperationQueue sharedQueue] addOperation:operation];
		[operation release];
	}	
}


// Called back in the main thread as a result of IMBSelectNodeOperation...

- (void) _didSelectNode:(IMBNode*)inNode
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(controller:didSelectNode:)])
	{
		[_delegate controller:self didSelectNode:inNode];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (void) addNodeForFolder:(NSString*)inPath
{
}


- (BOOL) removeNode:(IMBNode*)inNode
{
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSArray*) nodesForParser:(IMBParser*)inParser
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBNode*) _nodeWithIdentifier:(NSString*)inIdentifier inParentNode:(IMBNode*)inParentNode
{
	// Find the node with the specified identifier...
	
	NSArray* nodes = inParentNode ? inParentNode.subNodes : self.nodes;
	
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
	
//	IMBNode* node = nil;
//	int tries = 0;
//	
//	// First try to get the specified node, falling back to the next best ancestor if that node doesn't exist...
//	
//	NSString* identifier = [[inIdentifier copy] autorelease];
//	
//	do
//	{
//		node = [self libraryNodeWithIdentifier:identifier inParentNode:nil];
//		if (node) break;
//		
//		tries++;
//		
//		NSRange range = [identifier rangeOfString:@"/" options:NSBackwardsSearch];
//		if (range.location != NSNotFound)
//			identifier = [identifier substringToIndex:range.location];
//	}
//	while (![identifier hasSuffix:@":/"] && tries<10);
//	
//	// If that fails, then simply return the first top-level node...
//	
//	if (node == nil)
//	{
//		if ([self countOfLibraryNodes])
//		{
//			node = [self objectInLibraryNodesAtIndex:0];
//		}
//	}
//	
//	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) logNodes
{
	NSMutableString* text = [NSMutableString string];
	
	if (_nodes)
	{
		for (IMBNode* node in _nodes)
		{
			[text appendFormat:@"%@\n",[node description]];
		}
	}
		
	NSLog(@"%s\n\n%@\n",__FUNCTION__,text);
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


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

		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:name action:inSelector keyEquivalent:@""];
		[item setImage:icon];
		[item setTarget:inTarget];
		[item setRepresentedObject:inNode];
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
	
	for (IMBNode* node in _nodes)
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
			[item setTarget:inTarget];
			[item setRepresentedObject:node];
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



