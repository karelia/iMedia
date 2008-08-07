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

@implementation iMBParserController

- (id)initWithMediaType:(NSString *)mediaType
{
    self = [super init];
    if (self != NULL)
    {
        myMediaType = [mediaType copy];
        myLibraryNodes = [[NSMutableArray alloc] init];
        myCustomFolderInfo = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
	[myCustomFolderInfo release]; myCustomFolderInfo = NULL;
    [myLibraryNodes release]; myLibraryNodes = NULL;
    [myMediaType release]; myMediaType = NULL;
    [super dealloc];
}

// WARNING: MAIN THREAD ONLY
- (void)doSetLibraryNodes:(NSArray *)libraryNodes
{
    [[self mutableLibraryNodes] setArray:libraryNodes];
}

- (void)doAddLibraryNodes:(NSArray *)libraryNodes
{
    [[self mutableLibraryNodes] addObjectsFromArray:libraryNodes];
}

- (void)doRemoveLibraryNodes:(NSArray *)libraryNodes
{
    [[self mutableLibraryNodes] removeObjectsInArray:libraryNodes];
}

- (void)buildLibraryNodesWithCustomFolders:(NSArray *)customFolders
{
    NSMutableArray *libraryNodes = NULL;
    
    NSLock *gate = [[NSLock alloc] init];
    
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

@end
