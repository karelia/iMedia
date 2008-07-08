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

@implementation iMBParserController

- (id)initWithMediaType:(NSString *)mediaType
{
    self = [super init];
    if (self != NULL)
    {
        myMediaType = [mediaType copy];
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

- (void)buildLibraryNodesWithCustomFolders:(NSArray *)customFolders
{
    @synchronized (self)
    {
        if (myLibraryNodes != NULL)
            return;
        
        myLibraryNodes = [[NSMutableArray alloc] init];
        
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
            NSArray *libraries = [parser nodesFromParsingDatabase];
#ifdef DEBUG
            //		NSLog(@"Time to load parser (%@): %.3f", NSStringFromClass(parserClass), fabs([timer timeIntervalSinceNow]));
#endif
            if (libraries)
            {
                [myLibraryNodes addObjectsFromArray:libraries];
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
        
        [myLibraryNodes sortUsingDescriptors:librarySortDescriptor];
        
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
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"libraryNodes"];
    
    [myLibraryNodes insertObject:libraryNode atIndex:index];
    
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"libraryNodes"];
}

- (void)removeObjectFromLibraryNodesAtIndex:(unsigned)index
{
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"libraryNodes"];
    
    [myLibraryNodes removeObjectAtIndex:index];
    
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"libraryNodes"];
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
        NSArray *libraryNodes = [parser nodesFromParsingDatabase];
        
        NSEnumerator *enumerator = [libraryNodes objectEnumerator];
        iMBLibraryNode *libraryNode;
        
        while (libraryNode = [enumerator nextObject])
        {
            [libraryNode setName:[folderPath lastPathComponent]];
            [libraryNode setIconName:@"folder"];
            @synchronized (self)
            {
                [[self mutableLibraryNodes] addObject:libraryNode];
                [results addObject:libraryNode];
                [myCustomFolderInfo addObject:[NSDictionary dictionaryWithObjectsAndKeys:libraryNode, @"libraryNode", folderPath, @"folderPath", NULL]];
            }
        }
    }
    
    return results;
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
                [[self mutableLibraryNodes] removeObject:libraryNode];
                [myCustomFolderInfo removeObject:info];
                [folderPathsRemoved addObject:[info objectForKey:@"folderPath"]];
            }
        }
    }
    return folderPathsRemoved;
}

@end
