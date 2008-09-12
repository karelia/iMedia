//
//  iMBParserController.m
//  iMediaBrowse
//
//  Created by Chris Meyer on 7/7/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "iMBParserController.h"
#import "iMediaConfiguration.h"
#import "iMediaBrowserProtocol.h"
#import "iMBLibraryNode.h"
#import "NSWorkspace+iMedia.h"
#import "UKKQueue.h"

//#define DEBUG 0

@implementation iMBParserController

- (id)initWithMediaType:(NSString *)mediaType
{
    self = [super init];
    if (self != NULL)
    {
        myMediaType = [mediaType copy];
        myLibraryNodes = [[NSMutableArray alloc] init];
        myCustomFolderInfo = [[NSMutableArray alloc] init];
 		[[UKKQueue sharedFileWatcher] setDelegate:self];
		myChangedPathLock = [[NSRecursiveLock alloc] init];
		myChangedPathQueue = [[NSMutableArray alloc] init];
   }
    return self;
}

- (void)dealloc
{
	[myCustomFolderInfo release]; myCustomFolderInfo = NULL;
    [myLibraryNodes release]; myLibraryNodes = NULL;
    [myMediaType release]; myMediaType = NULL;
	[myChangedPathLock release]; myChangedPathLock = NULL;
	[myChangedPathQueue release]; myChangedPathQueue = NULL;
    [super dealloc];
}

// WARNING: MAIN THREAD ONLY
- (void)doSetLibraryNodes:(NSArray *)libraryNodes
{
	[self stopWatchingPathsForNodes:myLibraryNodes];
    [[self mutableLibraryNodes] setArray:libraryNodes];
	[self startWatchingPathsForNodes:libraryNodes];
}

- (void)doAddLibraryNodes:(NSArray *)libraryNodes
{
    [[self mutableLibraryNodes] addObjectsFromArray:libraryNodes];
	[self startWatchingPathsForNodes:libraryNodes];
}

- (void)doRemoveLibraryNodes:(NSArray *)libraryNodes
{
	[self stopWatchingPathsForNodes:libraryNodes];
    [[self mutableLibraryNodes] removeObjectsInArray:libraryNodes];
}

- (void)buildLibraryNodesWithCustomFolders:(NSArray *)customFolders
{
    NSMutableArray *libraryNodes = NULL;
    
    NSLock *gate = [[[NSLock alloc] init] autorelease];
    
    [gate lock];
    
    @synchronized (self)
    {
        if (myIsBuilt)
            return;
        
        myIsBuilt = YES;

        // NOTE: It is not legal to add items on a thread; so we do it on the main thread.
        // [self doSetLibraryNodes:libraryNodes];
        [self performSelectorOnMainThread:@selector(doSetLibraryNodes:) withObject:[NSArray array] waitUntilDone:YES];
        
        libraryNodes = [NSMutableArray array];
        
        NSArray *parsers = [[[iMediaConfiguration sharedConfiguration] parsers] objectForKey:myMediaType];
        
        NSMutableDictionary *loadedParsers = [NSMutableDictionary dictionary];
        
        NSEnumerator *e = [parsers objectEnumerator];
        NSString *cur;
        
        while (cur = [e nextObject])
        {
            Class parserClass = NSClassFromString(cur);
            if (![parserClass conformsToProtocol:@protocol(iMBParser)])
            {
                NSLog(@"Media Parser %@ does not conform to the iMBParser protocol. Skipping parser.");
                continue;
            }
            
			// Special case -- old del.icio.us parser (note the odd class spelling) breaks now.
			if ([cur isEqualToString:@"LHDeliciosParser"])
			{
				NSLog(@"Disabling obsolete '%@'", cur);
				continue;
			}

            id delegate = [[iMediaConfiguration sharedConfiguration] delegate];
            
            if ([delegate respondsToSelector:@selector(iMediaConfiguration:willUseMediaParser:forMediaType:)])
            {
                if (![delegate iMediaConfiguration:[iMediaConfiguration sharedConfiguration] willUseMediaParser:cur forMediaType:myMediaType])
                {
                    continue;
                }
            }
            
            id <iMBParser>parser = [loadedParsers objectForKey:cur];
            if (!parser)
            {
                parser = [[parserClass alloc] init];
                if (parser == nil)
                {
                    continue;
                }
                [loadedParsers setObject:parser forKey:cur];
                [parser release];
            }
            
#ifdef DEBUG
            //		NSDate *timer = [NSDate date];
#endif
            NSArray *libraries = [parser nodesFromParsingDatabase:gate];
#ifdef DEBUG
            //		NSLog(@"Time to load parser (%@): %.3f", NSStringFromClass(parserClass), fabs([timer timeIntervalSinceNow]));
#endif
            if (libraries)
            {
                [libraryNodes addObjectsFromArray:libraries];
            }
            
            if ([delegate respondsToSelector:@selector(iMediaConfiguration:didUseMediaParser:forMediaType:)])
            {
                [delegate iMediaConfiguration:[iMediaConfiguration sharedConfiguration] didUseMediaParser:cur forMediaType:myMediaType];
            }
        }
        
        NSSortDescriptor *priorityOrderSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"prioritySortOrder" 
                                                                                     ascending:NO] autorelease];
        NSSortDescriptor *nameSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"name" 
                                                                            ascending:YES 
                                                                             selector:@selector(caseInsensitiveCompare:)] autorelease];
        NSArray *librarySortDescriptor = [NSArray arrayWithObjects:priorityOrderSortDescriptor, nameSortDescriptor, nil];
        
        [libraryNodes sortUsingDescriptors:librarySortDescriptor];
    }
    
    // NOTE: It is not legal to add items on a thread; so we do it on the main thread.
    // [self doAddLibraryNodes:libraryNodes];
    [self performSelectorOnMainThread:@selector(doAddLibraryNodes:) withObject:libraryNodes waitUntilDone:YES];
    
    // release the hounds!
    [gate unlock];
    
    if ( customFolders != NULL )
    {
        NSEnumerator *enumerator = [customFolders objectEnumerator];
        NSString *folderPath;
        
        while ((folderPath = [enumerator nextObject]))
        {
            [self addCustomFolderPath:folderPath];
        }
    }
}

- (void)rebuildLibrary
{
    NSArray *oldCustomFolderInfo = [[myCustomFolderInfo copy] autorelease];
    
    NSMutableArray *customFolders = [NSMutableArray array];
    
    [myCustomFolderInfo removeAllObjects];
    
    NSEnumerator *enumerator = [oldCustomFolderInfo objectEnumerator];
    NSDictionary *info;
    while ( (info = [enumerator nextObject]) != NULL )
    {
        NSString *folderPath = [info objectForKey:@"folderPath"];
        [customFolders addObject:folderPath];
    }
    
    myIsBuilt = NO;
    
    [self buildLibraryNodesWithCustomFolders:customFolders];
}

// BEGIN KVC FOR libraryNodes

- (unsigned)countOfLibraryNodes
{
    return [myLibraryNodes count];
}

- (iMBLibraryNode *)objectInLibraryNodesAtIndex:(unsigned)index
{
    return [myLibraryNodes objectAtIndex:index];
}

- (void)insertObject:(iMBLibraryNode *)libraryNode inLibraryNodesAtIndex:(unsigned)index
{
    [myLibraryNodes insertObject:libraryNode atIndex:index];
}

- (void)removeObjectFromLibraryNodesAtIndex:(unsigned)index
{
    [myLibraryNodes removeObjectAtIndex:index];
}

- (NSMutableArray *)mutableLibraryNodes
{
    return [self mutableArrayValueForKey:@"libraryNodes"];
}

// END KVC FOR items

- (NSArray *)addCustomFolderPath:(NSString *)folderPath
{
    NSMutableArray *results = [NSMutableArray array];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
    if ([fileManager fileExistsAtPath:folderPath isDirectory:&isDirectory] && isDirectory)
    {
        iMBAbstractParser *parser = [[iMediaConfiguration sharedConfiguration] createCustomFolderParserForMediaType:myMediaType folderPath:folderPath];
        NSArray *libraryNodes = [parser nodesFromParsingDatabase:NULL /*gate*/];
        
        NSEnumerator *enumerator = [libraryNodes objectEnumerator];
        iMBLibraryNode *libraryNode;
        
        while (libraryNode = [enumerator nextObject])
        {
            [libraryNode setName:[[NSFileManager defaultManager] displayNameAtPath:folderPath]];
			[libraryNode setIcon:[[NSWorkspace sharedWorkspace] iconForFile:folderPath size:NSMakeSize(16,16)]];
            // NOTE: It is not legal to add items on a thread; so we do it on the main thread.
            // [self doAddLibraryNodes:[NSArray arrayWithObject:libraryNode]];
            [self performSelectorOnMainThread:@selector(doAddLibraryNodes:) withObject:[NSArray arrayWithObject:libraryNode] waitUntilDone:YES];
            [results addObject:libraryNode];
            [myCustomFolderInfo addObject:[NSDictionary dictionaryWithObjectsAndKeys:libraryNode, @"libraryNode", folderPath, @"folderPath", NULL]];
        }
    }
    
    return results;
}

- (BOOL)canRemoveLibraryNode:(iMBLibraryNode *)libraryNode
{
    NSEnumerator *info_enum = [[[myCustomFolderInfo copy] autorelease] objectEnumerator];
    NSDictionary *info;
    while ( (info = [info_enum nextObject]) != NULL )
    {
        if ([[info objectForKey:@"libraryNode"] isEqual:libraryNode])
            return YES;
    }
    return NO;
}

- (NSArray *)removeLibraryNodes:(NSArray *)libraryNodes
{
    NSMutableArray *folderPathsRemoved = [NSMutableArray array];
    NSEnumerator *enumerator = [libraryNodes objectEnumerator];
    iMBLibraryNode *libraryNode;
    while ( (libraryNode = [enumerator nextObject]) != NULL )
    {
        NSEnumerator *info_enum = [[[myCustomFolderInfo copy] autorelease] objectEnumerator];
        NSDictionary *info;
        while ( (info = [info_enum nextObject]) != NULL )
        {
            if ([[info objectForKey:@"libraryNode"] isEqual:libraryNode])
            {
                // NOTE: It is not legal to modify library nodes array on a thread; so we do it on the main thread.
                // [[self mutableLibraryNodes] removeObject:libraryNode];
                [self performSelectorOnMainThread:@selector(doRemoveLibraryNodes:) withObject:[NSArray arrayWithObject:libraryNode] waitUntilDone:YES];
                [myCustomFolderInfo removeObject:info];
                [folderPathsRemoved addObject:[info objectForKey:@"folderPath"]];
            }
        }
    }
    return folderPathsRemoved;
}

- (void)recursiveLogNode:(iMBLibraryNode *)inNode
{
	NSLog(@"%@",[inNode recursiveIdentifier]);
	
	NSEnumerator* e = [[inNode allItems] objectEnumerator];
	iMBLibraryNode *node;
	
	while (node =[e nextObject])
	{
		[self recursiveLogNode:node];
	}
}


- (void)logNodes
{
	NSEnumerator* e = [myLibraryNodes objectEnumerator];
	iMBLibraryNode *node;
	
	while (node =[e nextObject])
	{
		[self recursiveLogNode:node];
	}
}


- (iMBLibraryNode*) libraryNodeWithIdentifier:(NSString*)inIdentifier inParentNode:(iMBLibraryNode*)inParentNode
{
	// Find the node with the specified identifier...
	
	NSArray* nodes = inParentNode ? [inParentNode allItems] : myLibraryNodes;
	NSEnumerator* list = [nodes objectEnumerator];
	iMBLibraryNode* node;
	
	while (node = [list nextObject])
	{
		if ([[node recursiveIdentifier] isEqualToString:inIdentifier])
		{
			return node;
		}
		else
		{
			iMBLibraryNode* match = [self libraryNodeWithIdentifier:inIdentifier inParentNode:node];
			if (match) return match;
		}
	}
	
	return nil;
}

- (iMBLibraryNode*) libraryNodeWithIdentifier:(NSString*)inIdentifier
{
//	return [self libraryNodeWithIdentifier:inIdentifier inParentNode:nil];

	iMBLibraryNode* node = nil;
	int tries = 0;
	
	// First try to get the specified node, falling back to the next best ancestor if that node doesn't exist...
	
	NSString* identifier = [inIdentifier copy];
	
	do
	{
		node = [self libraryNodeWithIdentifier:identifier inParentNode:nil];
		if (node) break;
		
		tries++;
		
		NSRange range = [identifier rangeOfString:@"/" options:NSBackwardsSearch];
		if (range.location != NSNotFound)
			identifier = [identifier substringToIndex:range.location];
	}
	while (![identifier hasSuffix:@":/"] && tries<10);
	
	// If that fails, then simply return the first top-level node...
	
	if (node == nil)
	{
		if ([self countOfLibraryNodes])
		{
			node = [self objectInLibraryNodesAtIndex:0];
		}
	}
	
	return node;
}


#pragma mark File watching

- (void)startWatchingPathsForNodes:(NSArray *)libraryNodes
{
	NSEnumerator *nodes = [libraryNodes objectEnumerator];
	iMBLibraryNode *node;
	while (node = [nodes nextObject])
	{
		if ([node watchedPath])
			[[UKKQueue sharedFileWatcher] addPath:[node watchedPath]];
		
		[self startWatchingPathsForNodes:[node allItems]];
	}	
}

- (void)stopWatchingPathsForNodes:(NSArray *)libraryNodes
{
	NSEnumerator *nodes = [libraryNodes objectEnumerator];
	iMBLibraryNode *node;
	while (node = [nodes nextObject])
	{
		if ([node watchedPath])
			[[UKKQueue sharedFileWatcher] removePath:[node watchedPath]];
			
		[self stopWatchingPathsForNodes:[node allItems]];
	}	
}

-(void) watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString*)nm forPath:(NSString*)path
{
	// Called multiple times. Simply put the path in the queue (is not already in the queue), but coalesce 
	// into a single delayed perform request every few seconds, so that we avoid heavy CPU load due to 
	// reparsing too often...

	[myChangedPathLock lock];
	if ([myChangedPathQueue indexOfObject:path] == NSNotFound)
		[myChangedPathQueue addObject:path];
	[myChangedPathLock unlock];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(rebuildNodeWithWatchedPath:) object:path];
	[self performSelector:@selector(rebuildChangedNodes) withObject:nil afterDelay:5.0 inModes:[NSArray arrayWithObject:(NSString*)kCFRunLoopCommonModes]];
}


-(void) recursiveAddNodes:(iMBLibraryNode*)inRoot withWatchedPath:(NSString*)inPath toChangedNodes:(NSMutableDictionary*)inChangedNodes
{	
	// If we found a node with the correct watched path, then add it to the list, grouped by parserClassName and watchedPath...
	
	if ([[inRoot watchedPath] isEqualToString:inPath])
	{
		NSMutableDictionary* watchedPathList = [inChangedNodes objectForKey:[inRoot parserClassName]];
		if (watchedPathList == nil)
		{
			watchedPathList = [NSMutableDictionary dictionary];
			[inChangedNodes setObject:watchedPathList forKey:[inRoot parserClassName]];
		}
		
		NSMutableDictionary* nodesList = [watchedPathList objectForKey:inPath];
		if (nodesList == nil)
		{
			nodesList = [NSMutableDictionary dictionary];
			[watchedPathList setObject:nodesList forKey:inPath];
		}
		
		NSMutableArray* oldNodes = [nodesList objectForKey:@"oldNodes"];
		if (oldNodes == nil)
		{
			oldNodes = [NSMutableArray array];
			[nodesList setObject:oldNodes forKey:@"oldNodes"];
		}
		
		[oldNodes addObject:inRoot];
	}
	
	// If not, then keep searching subnodes...
	
	else
	{
		NSEnumerator *subnodes = [[inRoot allItems] objectEnumerator];
		iMBLibraryNode *node;
		while (node = [subnodes nextObject])
		{
			[self recursiveAddNodes:node withWatchedPath:inPath toChangedNodes:inChangedNodes];
		}	
	}
}


-(NSMutableDictionary*) changedNodes
{	
	NSMutableDictionary* changedNodes = [NSMutableDictionary dictionary];

	[myChangedPathLock lock];
	NSEnumerator *paths = [myChangedPathQueue objectEnumerator];
	NSString *path;
	
	while (path = [paths nextObject])
	{
		NSEnumerator *nodes = [[self mutableLibraryNodes] objectEnumerator];
		iMBLibraryNode *node;
		while (node = [nodes nextObject])
		{
			[self recursiveAddNodes:node withWatchedPath:path toChangedNodes:changedNodes];
		}	
	}	
	
	[myChangedPathQueue removeAllObjects];
	[myChangedPathLock unlock];
	
	return changedNodes;
}


-(void) rebuildChangedNodes
{	
	NSMutableDictionary* nodes = [self changedNodes];
	#if DEBUG
	NSLog(@"%s %@",__FUNCTION__,nodes);
	#endif
	[NSThread detachNewThreadSelector:@selector(doRebuildChangedNodes:) toTarget:self withObject:nodes];
}


- (NSMutableArray*) filterNodes:(NSArray*)inNodes forWatchedPath:(NSString*)inWatchedPath
{
	NSMutableArray* filteredNodes = [NSMutableArray array];
	
	NSEnumerator* e = [inNodes objectEnumerator];
	iMBLibraryNode* node;
	while (node = [e nextObject])
	{
		if ([[node watchedPath] isEqualToString:inWatchedPath])
		{
			[filteredNodes addObject:node];
		}
	}
	
	return filteredNodes;
}


-(void) doRebuildChangedNodes:(NSMutableDictionary*)inNodesList parserClassName:(NSString*)inParserClassName watchedPath:(NSString*)inWatchedPath
{
	NSString *parserClassName = inParserClassName;
	NSString *watchedPath = inWatchedPath;
	Class parserClass = NSClassFromString(parserClassName);
    NSLock *gate = [[[NSLock alloc] init] autorelease];
    [gate lock];
	
	// Check if we are allowed to use this parser.
	
	if (![parserClass conformsToProtocol:@protocol(iMBParser)])
	{
		NSLog(@"Media Parser %@ does not conform to the iMBParser protocol. Skipping parser.");
		return;
	}
            
	id delegate = [[iMediaConfiguration sharedConfiguration] delegate];

	if ([delegate respondsToSelector:@selector(iMediaConfiguration:willUseMediaParser:forMediaType:)])
	{
		if (![delegate iMediaConfiguration:[iMediaConfiguration sharedConfiguration] willUseMediaParser:parserClassName forMediaType:myMediaType])
		{
			return;
		}
	}
       
	// Create the parser instance and get the nodes from the parser...
	
	id <iMBParser>parser = [[[parserClass alloc] initWithContentsOfFile:watchedPath] autorelease];
	NSArray *newNodes = [parser nodesFromParsingDatabase:gate];

	// Notify delegate that we are done with this parser...
	
	if ([delegate respondsToSelector:@selector(iMediaConfiguration:didUseMediaParser:forMediaType:)])
	{
		[delegate iMediaConfiguration:[iMediaConfiguration sharedConfiguration] didUseMediaParser:parserClassName forMediaType:myMediaType];
	}

	// Replace nodes in library tree...
	
	if (newNodes != nil && [newNodes count] > 0)
	{
		NSMutableArray* filteredNodes = [self filterNodes:newNodes forWatchedPath:(NSString*)inWatchedPath];
		[inNodesList setObject:filteredNodes forKey:@"newNodes"];
		[self performSelectorOnMainThread:@selector(doReplaceNodes:) withObject:inNodesList waitUntilDone:NO];
	}
	
	[gate unlock];
}


-(void) doRebuildChangedNodes:(NSMutableDictionary*)inChangedNodes 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSEnumerator *parserEnumerator = [[inChangedNodes allKeys] objectEnumerator];
	NSString *parserClassName;
	while (parserClassName = [parserEnumerator nextObject])
	{
		NSMutableDictionary* watchedPathList = [inChangedNodes objectForKey:parserClassName];
		
		NSEnumerator *watchedPathEnumerator = [[watchedPathList allKeys] objectEnumerator];
		NSString *watchedPath;
		while (watchedPath = [watchedPathEnumerator nextObject])
		{
			NSMutableDictionary* nodesList = [watchedPathList objectForKey:watchedPath];
			[self doRebuildChangedNodes:nodesList parserClassName:parserClassName watchedPath:watchedPath];
		}
	}

	[pool release];
}


-(void) doReplaceNodes:(NSMutableDictionary*)inNodesList inArray:(NSMutableArray *)array
{
	NSMutableArray* oldNodes = [inNodesList objectForKey:@"oldNodes"];
	if ([oldNodes count] < 1) return;

	NSMutableArray* newNodes = [inNodesList objectForKey:@"newNodes"];
	if ([newNodes count] < 1) return;
	
	unsigned int index = [array indexOfObjectIdenticalTo:[oldNodes objectAtIndex:0]];

	if (index != NSNotFound)
	{
		// FIXME: KVO notification should probably be done in a smarter way here
		[self willChangeValueForKey:@"libraryNodes"];
		[self stopWatchingPathsForNodes:oldNodes];
		[array removeObjectsInArray:oldNodes];
		[array insertObjects:newNodes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index,[newNodes count])]];
		[self startWatchingPathsForNodes:newNodes];
		[self didChangeValueForKey:@"libraryNodes"];
	}
	else
	{
		NSString *node;
		NSEnumerator *e = [array objectEnumerator];
		while (node = [e nextObject])
		{
			[self doReplaceNodes:inNodesList inArray:(NSMutableArray*)[node valueForKey:@"mutableItems"]];
		}	
	}
}


-(void) doReplaceNodes:(NSMutableDictionary*)inNodesList
{
	[self doReplaceNodes:inNodesList inArray:myLibraryNodes];
}

@end
