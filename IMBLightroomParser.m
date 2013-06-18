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


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroomParser.h"
#import "IMBLightroomObject.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "IMBConfig.h"
#import "IMBLightroom1Parser.h"
#import "IMBLightroom2Parser.h"
#import "IMBLightroom3Parser.h"
#import "IMBLightroom4Parser.h"
#import "IMBLightroom5Parser.h"
#import "IMBLightroom3VideoParser.h"
#import "IMBLightroom4VideoParser.h"
#import "IMBLightroom5VideoParser.h"
#import "IMBIconCache.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBObject.h"
#import "IMBObjectsPromise.h"
#import "IMBOrderedDictionary.h"
#import "IMBParserController.h"
#import "IMBPyramidObjectPromise.h"
#import "NSFileManager+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSObject+iMedia.h"
#import "NSString+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSURL+iMedia.h"

#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSArray* sSupportedUTIs = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLightroomParser ()

- (NSString*) libraryName;

- (NSArray*) supportedUTIs;
- (BOOL) canOpenImageFileAtPath:(NSString*)inPath;
- (IMBObject*) objectWithPath:(NSString*)inPath
					  idLocal:(NSNumber*)idLocal
						 name:(NSString*)inName
				  pyramidPath:(NSString*)inPyramidPath
					 metadata:(NSDictionary*)inMetadata
						index:(NSUInteger)inIndex;

- (NSString*) rootNodeIdentifier;
- (NSString*) identifierWithFolderId:(NSNumber*)inIdLocal;
- (NSString*) identifierWithCollectionId:(NSNumber*)inIdLocal;

- (NSNumber*) rootFolderFromAttributes:(NSDictionary*)inAttributes;
- (NSNumber*) idLocalFromAttributes:(NSDictionary*)inAttributes;
- (NSString*) rootPathFromAttributes:(NSDictionary*)inAttributes;
- (NSString*) pathFromRootFromAttributes:(NSDictionary*)inAttributes;
- (NSString*) absolutePathFromAttributes:(NSDictionary*)inAttributes;
- (IMBLightroomNodeType) nodeTypeFromAttributes:(NSDictionary*)inAttributes;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLightroomParser

@synthesize appPath = _appPath;
@synthesize atomicDataPath = _dataPath;
@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;
@synthesize databases = _databases;
@synthesize thumbnailDatabases = _thumbnailDatabases;


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeMovie];
	[pool drain];
}

// Check if Lightroom is installed...

+ (NSString*) lightroomPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:[self lightroomAppBundleIdentifier]];
}


// Returns the path to the previews database as soon as the mediaSource is accessible.
// If so, sets atomicDataPath lazily and draws from atomicDataPath from then on.
// This construction is necessary because parsers are cached and thus would provide a nil dataPath
// even if the library is later granted accessible (library could have been non-existent because it was
// renamed or moved in the file system).

- (NSString*) dataPath
{
    if (!self.atomicDataPath)
    {
        NSString* libraryPath = self.mediaSource;
        
        NSString* dataPath = [[[libraryPath stringByDeletingPathExtension]
                               stringByAppendingString:@" Previews"]
                              stringByAppendingPathExtension:@"lrdata"];
        
        NSURL *dataURL = [NSURL fileURLWithPath:dataPath isDirectory:YES];
        
        NSNumber *isDirectory;
        if (![dataURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL] || ![isDirectory boolValue])
        {
            dataPath = nil;
        }
        
        self.atomicDataPath = dataPath;
    }
    return self.atomicDataPath;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (id) initWithMediaType:(NSString*)inMediaType
{
	if ((self = [super initWithMediaType:inMediaType]) != nil)
	{
		self.appPath = [[self class] lightroomPath];

		_databases = [[NSMutableDictionary alloc] init];
		_thumbnailDatabases = [[NSMutableDictionary alloc] init];

		[self supportedUTIs];	// Init early and in the main thread!
	}

	return self;
}

- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_dataPath);
	IMBRelease(_databases);
	IMBRelease(_thumbnailDatabases);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Subclasses must return a unique identifier...

+ (NSString*) identifier
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}

// The bundle identifier of the Lightroom app this parser is based upon

+ (NSString*) lightroomAppBundleIdentifier
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}

// Key in Ligthroom app user defaults: which library to load

+ (NSString*) preferencesLibraryToLoadKey
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}

// Key in Ligthroom app user defaults: which libraries have been loaded recently

+ (NSString*) preferencesRecentLibrariesKey
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}


// Helper method that converts single string into an array of paths...

+ (void) parseRecentLibrariesList:(NSString*)inRecentLibrariesList into:(NSMutableArray*)inLibraryPaths
{
    NSCharacterSet* newlineCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    NSScanner* scanner = [NSScanner scannerWithString:inRecentLibrariesList];
    
    NSString* path = @"";
	
    while (![scanner isAtEnd])
    {
        NSString* token;
        if ([scanner scanUpToCharactersFromSet:newlineCharacterSet intoString:&token])
        {
            NSString* string = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if (([string length] == 0) || 
                [string isEqualTo:@"recentLibraries = {"] || 
                [string isEqualTo:@"}"])
            {
                continue;
            }
            
            path = [path stringByAppendingString:string];
            
            if ([path hasSuffix:@"\","])
            {
				path = [path substringWithRange:NSMakeRange(1, [path length] - 3)];
                NSFileManager *fileManager = [[NSFileManager alloc] init];
 
				BOOL exists,changed;
				exists = [fileManager imb_fileExistsAtPath:&path wasChanged:&changed];
				if (exists) {
                    [inLibraryPaths addObject:path];
// Maybe we only want to return the first existing library from the recents list?
//                    [fileManager release];
//                    break;
                }
                
                [fileManager release];
                path = @"";
            }
        }
        
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    }
}


// Factory method for the parser instances. Create one instance per library and configure it...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];

	if ([kIMBMediaTypeImage isEqualTo:inMediaType]) {
		[parserInstances addObjectsFromArray:[IMBLightroom1Parser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom2Parser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom3Parser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom4Parser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom5Parser concreteParserInstancesForMediaType:inMediaType]];
	}
	else if ([kIMBMediaTypeMovie isEqualTo:inMediaType]) {
		[parserInstances addObjectsFromArray:[IMBLightroom3VideoParser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom4VideoParser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom5VideoParser concreteParserInstancesForMediaType:inMediaType]];
	}

	return parserInstances;
}


// Return an array to Lightroom library files...

+ (NSArray*) libraryPaths
{
	NSMutableArray* libraryPaths = [NSMutableArray array];
    Class parserClass = [self class];
    
    if ([libraryPaths count] == 0) {
		CFPropertyListRef activeLibraryPath = CFPreferencesCopyAppValue((CFStringRef)[parserClass preferencesLibraryToLoadKey],
																		(CFStringRef)[parserClass lightroomAppBundleIdentifier]);
		
		if (activeLibraryPath) {
			[libraryPaths addObject:(NSString*)activeLibraryPath];

			CFRelease(activeLibraryPath);
		}
    }
    
	if ([libraryPaths count] == 0) {
		CFStringRef recentLibrariesList = CFPreferencesCopyAppValue((CFStringRef)[parserClass preferencesRecentLibrariesKey],
                                                                    (CFStringRef)[parserClass lightroomAppBundleIdentifier]);
        
		if (recentLibrariesList) {
			[self parseRecentLibrariesList:(NSString*)recentLibrariesList into:libraryPaths];
			CFRelease(recentLibrariesList);
		}
    }
	
	return libraryPaths;
}

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	IMBNode* node = [[[IMBNode alloc] init] autorelease];

	// Create an empty root node (without subnodes, but with empty objects array)...

	if (inOldNode == nil)
	{
		NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0,16.0)];

		node.mediaSource = self.mediaSource;
		node.identifier = [self rootNodeIdentifier];
		node.name = @"Lightroom";
		node.icon = icon;
		node.parser = self;
		node.leaf = NO;
		node.isTopLevelNode = YES;
		node.groupType = kIMBGroupTypeLibrary;
	}
	else
	{
		node.mediaSource = self.mediaSource;
		node.identifier = inOldNode.identifier;
		node.name = inOldNode.name;
		node.icon = inOldNode.icon;
		node.parser = self;
		node.leaf = inOldNode.leaf;
		node.groupType = inOldNode.groupType;
		node.attributes = [[inOldNode.attributes copy] autorelease];
	}

	if (node.isTopLevelNode && self.shouldDisplayLibraryName)
	{
		node.name = [NSString stringWithFormat:@"%@ (%@)",node.name,[self libraryName]];
	}

	// Watch the root node. Whenever something in Lightroom changes, we have to replace the
	// WHOLE node tree, as we have no way of finding out WHAT has changed in Lightroom...

	if (node.isTopLevelNode)
	{
		node.watcherType = kIMBWatcherTypeFSEvent;
		node.watchedPath = self.mediaSource;
	}
	else
	{
		node.watcherType = kIMBWatcherTypeNone;
	}

	// If the old node was populated, then also populate the new node...

	if (inOldNode.isPopulated)
	{
		[self populateNewNode:node likeOldNode:inOldNode options:inOptions];
	}

	if (outError) *outError = error;
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	// Create subnodes for the root node as needed...
	
	if ([inNode isTopLevelNode])
	{
		[self populateSubnodesForRootNode:inNode];
	}
	else {
		NSDictionary* attributes = inNode.attributes;
		IMBLightroomNodeType nodeType = [self nodeTypeFromAttributes:attributes];

		switch (nodeType) {

			// Create subnodes for the Folders node as needed...
			case IMBLightroomNodeTypeFolder:
			{
				NSString* rootFoldersIdentifier = [self identifierWithFolderId:[NSNumber numberWithInt:-1]];

				if ([inNode.identifier isEqualToString:rootFoldersIdentifier])
				{
					[self populateSubnodesForRootFoldersNode:inNode];
				}
				else
				{
					[self populateSubnodesForFolderNode:inNode];
				}

				[self populateObjectsForFolderNode:inNode];

				break;
			}

			// Create subnodes for the Collections node as needed...
			case IMBLightroomNodeTypeCollection:
			{
				[self populateSubnodesForCollectionNode:inNode];
				[self populateObjectsForCollectionNode:inNode];

				break;
			}

			case IMBLightroomNodeTypeRootCollection:
			{
				[self populateSubnodesForCollectionNode:inNode];

				break;
			}

			case IMBLightroomNodeTypeSmartCollection:
			{
				[self populateSubnodesForSmartCollectionNode:inNode];
				[self populateObjectsForSmartCollectionNode:inNode];

				break;
			}

			default:
			{
				inNode.subNodes = [NSArray array];
				inNode.objects = [NSArray array];

				break;
			}

		}
	}
	
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// When the parser is deselected, then get rid of cached data. In our case we can close the database...

- (void) didStopUsingParser
{
	@synchronized (self)
	{
		self.databases = nil;
		self.thumbnailDatabases = nil;
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Creating Subnodes


// This method creates the immediate subnodes of the "Lightroom" root node. The two subnodes are "Folders"  
// and "Collections"...

- (void) populateSubnodesForRootNode:(IMBNode*)inRootNode
{
	[self populateSubnodesForCollectionNode:inRootNode];
}


//----------------------------------------------------------------------------------------------------------------------


// This method creates the immediate subnodes of the "Folders" node. The Lightroom database seems to call them
// root folders. Each import usually creates one of these folders with the capture date as the folder name...

- (void) populateSubnodesForRootFoldersNode:(IMBNode*)inFoldersNode
{
	// Add subnodes array, even if nothing is found in database, so that we do not cause endless loop...
	
	NSMutableArray* subNodes = [NSMutableArray array];
	NSMutableArray* objects = [NSMutableArray array];
	inFoldersNode.displayedObjectCount = 0;
	
	// Query the database for the root folders and create a node for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSString* query = [[self class] rootFolderQuery];
		FMResultSet* results = [database executeQuery:query];
		NSInteger index = 0;
		
		while ([results next]) {
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			NSNumber* id_local = [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
			NSString* path = [results stringForColumn:@"absolutePath"];
			NSString* name = [results stringForColumn:@"name"];
			
			if (name == nil) {
				name = NSLocalizedStringWithDefaultValue(
														 @"IMBLightroomParser.Unnamed",
														 nil,IMBBundle(),
														 @"Unnamed",
														 @"Name of unnamed node in IMBLightroomParser");
			}
			
			IMBNode* node = [[[IMBNode alloc] init] autorelease];
			node.name = name;
			node.icon = [[self class] folderIcon];
			node.parser = self;
			node.mediaSource = self.mediaSource;
			node.identifier = [self identifierWithFolderId:id_local];
			node.attributes = [self attributesWithRootFolder:id_local
													 idLocal:id_local
													rootPath:path
												pathFromRoot:nil
                                                    nodeType:IMBLightroomNodeTypeFolder];
			node.leaf = NO;

			[subNodes addObject:node];
			
			IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];
			object.representedNodeIdentifier = node.identifier;
			object.name = name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];
			
			[objects addObject:object];
			
			[pool drain];
		}
		
		[results close];
	}
	
	inFoldersNode.subNodes = subNodes;
	inFoldersNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


// This method creates subnodes for folders deeper into the hierarchy. Please note that here the SQL query is different
// from the previous method. We are no longer selecting from AgLibraryRootFolder, but from AgLibraryFolder instead...

- (void) populateSubnodesForFolderNode:(IMBNode*)inParentNode
{
	// Add subnodes array, even if nothing is found in database, so that we do not cause endless loop...
	
	NSMutableArray* subNodes = [NSMutableArray array];
	NSMutableArray* objects = [NSMutableArray array];
	inParentNode.displayedObjectCount = 0;
	
	// Query the database for subfolder and add a node for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSDictionary* attributes = inParentNode.attributes;
		NSString* parentPathFromRoot = [self pathFromRootFromAttributes:attributes];	
		NSNumber* parentRootFolder = [self rootFolderFromAttributes:attributes];
		NSString* parentRootPath = [self rootPathFromAttributes:inParentNode.attributes];
		NSString* query = [[self class] folderNodesQuery];
		NSString* pathFromRootAccept = nil;
		NSString* pathFromRootReject = nil;
		
		if ([parentPathFromRoot length] > 0) {
			pathFromRootAccept = [NSString stringWithFormat:@"%@/%%/", parentPathFromRoot];
			pathFromRootReject = [NSString stringWithFormat:@"%@/%%/%%/", parentPathFromRoot];
		}
		else {
			pathFromRootAccept = @"%/";
			pathFromRootReject = @"%/%/";
		}
				
		FMResultSet* results = [database executeQuery:query, parentRootFolder, pathFromRootAccept, pathFromRootReject];
		NSInteger index = 0;
		
		while ([results next]) {
			NSNumber* id_local = [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
			NSString* pathFromRoot = [results stringForColumn:@"pathFromRoot"];
			
			if ([pathFromRoot hasSuffix:@"/"]) {
				pathFromRoot = [pathFromRoot substringToIndex:(pathFromRoot.length - 1)];
			}
			
			IMBNode *node = nil;
			
			if ([pathFromRoot length] > 0) {
				node = [[[IMBNode alloc] init] autorelease];

				node.icon = [[self class] folderIcon];
				node.parser = self;
				node.mediaSource = self.mediaSource;
				node.name = [pathFromRoot lastPathComponent];
				node.leaf = NO;
				

				node.identifier = [self identifierWithFolderId:id_local];
				
				[subNodes addObject:node];
			
				NSDictionary* attributes = [self attributesWithRootFolder:parentRootFolder
																  idLocal:id_local
																 rootPath:parentRootPath
															 pathFromRoot:pathFromRoot
                                                                 nodeType:IMBLightroomNodeTypeFolder];

				node.attributes = attributes;
				
				NSString* path = [self absolutePathFromAttributes:attributes];
				
				IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];
				object.representedNodeIdentifier = node.identifier;
				object.name = node.name;
				object.metadata = nil;
				object.parser = self;
				object.index = index++;
				object.imageLocation = (id)self.mediaSource;
				object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
				object.imageRepresentation = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];

				[objects addObject:object];
			}
		}
		[results close];
	}
	
	inParentNode.subNodes = subNodes;
	inParentNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


// This method populates collection subnodes for the specified parent node. Even though the query returns all Collections,
// only create nodes that are immediate children of our parent node. This is necessary, because the returned 
// results from the query are not ordered in a way that would let us build the whole node tree in one single
// step...

- (void) populateSubnodesForCollectionNode:(IMBNode*)inParentNode 
{
	// Add an empty subnodes array, to avoid endless loop, even if the following query returns no results...
	
	NSMutableArray* subNodes = [NSMutableArray arrayWithArray:inParentNode.subNodes];
	NSMutableArray* objects = [NSMutableArray arrayWithArray:inParentNode.objects];
	inParentNode.displayedObjectCount = 0;
	
	// Now query the database for subnodes to the specified parent node...
	
	FMDatabase *database = self.database;

	if (database != nil) {
		NSDictionary* attributes = inParentNode.attributes;
		NSNumber* collectionId = [self idLocalFromAttributes:attributes];
		NSString* query = nil;
		FMResultSet* results = nil;
		
		if ([collectionId longValue] == 0) {
			query = [[self class] rootCollectionNodesQuery];
			results = [database executeQuery:query];
		}
		else {
			query = [[self class] collectionNodesQuery];
			results = [database executeQuery:query, collectionId];
		}

		NSInteger index = 0;
		
		while ([results next]) {
			// Get properties for next collection. Also substitute missing names...
			
			NSNumber* idLocal = [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
			NSNumber* idParentLocal = [NSNumber numberWithLong:[results longForColumn:@"parent"]];
			NSString* name = [results stringForColumn:@"name"];
			NSString* creationId = [results hasColumnWithName:@"creationid"] ? [results stringForColumn:@"creationid"] : nil;
			BOOL isGroup = NO;
			
			if (name == nil)
			{
				if ([idParentLocal intValue] == 0)
				{
					name = NSLocalizedStringWithDefaultValue(
															 @"IMBLightroomParser.collectionsName",
															 nil,IMBBundle(),
															 @"Collections",
															 @"Name of Collections node in IMBLightroomParser");
					isGroup = YES;
				}
				else
				{
					name = NSLocalizedStringWithDefaultValue(
															 @"IMBLightroomParser.Unnamed",
															 nil,IMBBundle(),
															 @"Unnamed",
															 @"Name of unnamed node in IMBLightroomParser");
				}
			}

			IMBLightroomNodeType nodeType = [[self class] nodeTypeForCreationId:creationId];
			
			IMBNode* node = [[[IMBNode alloc] init] autorelease];
			node.identifier = [self identifierWithCollectionId:idLocal];
			node.name = name;
			node.icon = isGroup ? [[self class] groupIcon] : [[self class] collectionIcon];
			node.parser = self;
			node.mediaSource = self.mediaSource;
			node.attributes = [self attributesWithRootFolder:nil
													 idLocal:idLocal
													rootPath:nil
												pathFromRoot:nil
                                                    nodeType:nodeType];

			node.leaf = NO;

			[subNodes addObject:node];
			
			IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];
			object.representedNodeIdentifier = node.identifier;
			object.name = node.name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [[self class] largeFolderIcon];
			
			[objects addObject:object];
		}
		
		[results close];
	}
	
	inParentNode.subNodes = subNodes;
	inParentNode.objects = objects;
}

- (void) populateSubnodesForSmartCollectionNode:(IMBNode*)inParentNode
{
	[self populateSubnodesForCollectionNode:inParentNode];
}

//----------------------------------------------------------------------------------------------------------------------


+ (IMBLightroomNodeType) nodeTypeForCreationId:(NSString *)creationId;
{
	return IMBLightroomNodeTypeCollection;
}

+ (NSImage*) largeFolderIcon
{
	NSImage* icon = [NSImage imb_genericFolderIcon];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(64.0,64.0)];
	
	return icon;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Creating Objects


// This method populates an existing folder node with objects (image files). The essential part is id_local stored
// in the attributes dictionary. It determines the correct database query...

- (void) populateObjectsForFolderNode:(IMBNode*)inNode
{
	// Add object array, even if nothing is found in database, so that we do not cause endless loop...
	
	if (inNode.objects == nil) {
		inNode.objects = [NSArray array];
		inNode.displayedObjectCount = 0;
	}
	
	// Query the database for image files for the specified node. Add an IMBObject for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSMutableArray* objects = [NSMutableArray array];
		NSString* query = [[self class] folderObjectsQuery];
		
		NSDictionary* attributes = inNode.attributes;
		NSString* folderPath = [self absolutePathFromAttributes:attributes];
		NSNumber* folderId = [self idLocalFromAttributes:attributes];
		FMResultSet* results = [database executeQuery:query, folderId, folderId];
		NSUInteger index = 0;
		
		while ([results next]) {
			NSString* filename = [results stringForColumn:@"idx_filename"];
			NSNumber* idLocal = [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
			NSString* captureTime = [results stringForColumn:@"captureTime"];
			NSNumber* fileHeight = [NSNumber numberWithDouble:[results doubleForColumn:@"fileHeight"]];
			NSNumber* fileWidth = [NSNumber numberWithDouble:[results doubleForColumn:@"fileWidth"]];
			NSString* orientation = [results stringForColumn:@"orientation"];
			NSString* caption = [results stringForColumn:@"caption"];
			NSString* pyramidPath = ([results hasColumnWithName:@"pyramidPath"] ? [results stringForColumn:@"pyramidPath"] : nil);
			NSString* name = caption!= nil ? caption : filename;
			NSString* path = [folderPath stringByAppendingPathComponent:filename];
			
			if (pyramidPath == nil) {
				pyramidPath = [self pyramidPathForImage:idLocal];
			}
			
			if ([self canOpenImageFileAtPath:path]) {
				NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
				
				[metadata setObject:path forKey:@"MasterPath"];
				[metadata setObject:idLocal forKey:@"idLocal"];
				[metadata setObject:path forKey:@"path"];
				[metadata setObject:fileHeight forKey:@"height"];
				[metadata setObject:fileWidth forKey:@"width"];
				[metadata setObject:orientation forKey:@"orientation"];
				
				if (name) {
					[metadata setObject:name forKey:@"name"];
				}
				
				if (captureTime) {
					[metadata setObject:captureTime forKey:@"dateTime"];
				}
                
                if (caption) {
					[metadata setObject:caption forKey:@"comment"];
                }
				
				IMBObject* object = [self objectWithPath:path
												 idLocal:idLocal
													name:name
											 pyramidPath:pyramidPath
												metadata:metadata
												   index:index++];
				
				[objects addObject:object];
				inNode.displayedObjectCount++;
			}
		}
		
		[results close];
		
		[objects addObjectsFromArray:inNode.objects];
		inNode.objects = objects;
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This method populates an existing collection node with objects (image files). The essential part is id_local stored
// in the attributes dictionary. It determines the correct database query...

- (void) populateObjectsForCollectionNode:(IMBNode*)inNode
{
	// Add object array, even if nothing is found in database, so that we do not cause endless loop...
	
	if (inNode.objects == nil) {
		inNode.objects = [NSMutableArray array];
		inNode.displayedObjectCount = 0;
	}
	
	// Query the database for image files for the specified node. Add an IMBObject for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSString* query = [[self class] collectionObjectsQuery];
		NSNumber* collectionId = [self idLocalFromAttributes:inNode.attributes];
		FMResultSet* results = [database executeQuery:query, collectionId];
		NSUInteger index = 0;
		
		while ([results next]) {
			NSString* absolutePath = [results stringForColumn:@"absolutePath"];
			NSString* filename = [results stringForColumn:@"idx_filename"];
			NSNumber* idLocal = [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
			NSNumber* fileHeight = [NSNumber numberWithDouble:[results doubleForColumn:@"fileHeight"]];
			NSNumber* fileWidth = [NSNumber numberWithDouble:[results doubleForColumn:@"fileWidth"]];
			NSString* orientation = [results stringForColumn:@"orientation"];
			NSString* caption = [results stringForColumn:@"caption"];
			NSString* pyramidPath = ([results hasColumnWithName:@"pyramidPath"] ? [results stringForColumn:@"pyramidPath"] : nil);
			NSString* name = caption!= nil ? caption : filename;
			NSString* path = [absolutePath stringByAppendingString:filename];
			
			if (pyramidPath == nil) {
				pyramidPath = [self pyramidPathForImage:idLocal];
			}
			
			if ([self canOpenImageFileAtPath:path]) {
				NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
				
				[metadata setObject:path forKey:@"MasterPath"];
				[metadata setObject:idLocal forKey:@"idLocal"];
				[metadata setObject:path forKey:@"path"];
				[metadata setObject:fileHeight forKey:@"height"];
				[metadata setObject:fileWidth forKey:@"width"];
				[metadata setObject:orientation forKey:@"orientation"];
				
				if (name) {
					[metadata setObject:name forKey:@"name"];
				}
				
				IMBObject* object = [self objectWithPath:path
												 idLocal:idLocal
													name:name
											 pyramidPath:pyramidPath
												metadata:metadata
												   index:index++];
				[(NSMutableArray*)inNode.objects addObject:object];
				inNode.displayedObjectCount++;
			}
		}
		
		[results close];
	}
}


// This method populates an existing smart collection node with objects (image files). The essential part is id_local stored
// in the attributes dictionary. It determines the correct database query...

- (void) populateObjectsForSmartCollectionNode:(IMBNode*)inNode
{
	// Add object array, even if nothing is found in database, so that we do not cause endless loop...

	if (inNode.objects == nil) {
		inNode.objects = [NSMutableArray array];
		inNode.displayedObjectCount = 0;
	}

	// Not implemented for legacy libraries
}


//----------------------------------------------------------------------------------------------------------------------


// Check if we can open this image file...

- (BOOL) canOpenImageFileAtPath:(NSString*)inPath
{
	NSString* uti = [NSString imb_UTIForFileAtPath:inPath];
	NSArray* supportedUTIs = [self supportedUTIs];
	
	for (NSString* supportedUTI in supportedUTIs)
	{
		if (UTTypeConformsTo((CFStringRef)uti,(CFStringRef)supportedUTI)) return YES;
	}
	
	return NO;
}


// List of all supported file types...

- (NSArray*) supportedUTIs
{
	if (sSupportedUTIs == nil)
	{
		sSupportedUTIs = (NSArray*) CGImageSourceCopyTypeIdentifiers();
	}	
	
	return sSupportedUTIs;
}


//----------------------------------------------------------------------------------------------------------------------


// Create a new IMBObject with the specified properties...

- (IMBObject*) objectWithPath:(NSString*)inPath
					  idLocal:(NSNumber*)idLocal
						 name:(NSString*)inName
				  pyramidPath:(NSString*)inPyramidPath
					 metadata:(NSDictionary*)inMetadata
						index:(NSUInteger)inIndex
{
	IMBLightroomObject* object = [[[IMBLightroomObject alloc] init] autorelease];
	NSString* absolutePyramidPath = (inPyramidPath != nil) ? [self.dataPath stringByAppendingPathComponent:inPyramidPath] : nil;

	object.absolutePyramidPath = absolutePyramidPath;
	object.idLocal = idLocal;
	object.location = (id)inPath;
	object.name = inName;
	object.preliminaryMetadata = inMetadata;	// This metadata was in the XML file and is available immediately
	object.metadata = nil;						// Build lazily when needed (takes longer)
	object.metadataDescription = nil;			// Build lazily when needed (takes longer)
	object.parser = self;
	object.index = inIndex;
	object.imageLocation = (id)inPath;
	object.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
	object.imageRepresentation = nil;
	
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


- (CGImageRef)imageRotated:(CGImageRef)imgRef forOrientation:(NSInteger)orientationProperty
{
	CGFloat w = CGImageGetWidth(imgRef);
	CGFloat h = CGImageGetHeight(imgRef);
	
	CGAffineTransform transform = {0};
	
	switch (orientationProperty) {
		case 1:
			// 1 = 0th row is at the top, and 0th column is on the left.
			// Orientation Normal
			transform = CGAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
			break;
			
		case 2:
			// 2 = 0th row is at the top, and 0th column is on the right.
			// Flip Horizontal
			transform = CGAffineTransformMake(-1.0, 0.0, 0.0, 1.0, w, 0.0);
			break;
			
		case 3:
			// 3 = 0th row is at the bottom, and 0th column is on the right.
			// Rotate 180 degrees
			transform = CGAffineTransformMake(-1.0, 0.0, 0.0, -1.0, w, h);
			break;
			
		case 4:
			// 4 = 0th row is at the bottom, and 0th column is on the left.
			// Flip Vertical
			transform = CGAffineTransformMake(1.0, 0.0, 0, -1.0, 0.0, h);
			break;
			
		case 5:
			// 5 = 0th row is on the left, and 0th column is the top.
			// Rotate -90 degrees and Flip Vertical
			transform = CGAffineTransformMake(0.0, -1.0, -1.0, 0.0, h, w);
			break;
			
		case 6:
			// 6 = 0th row is on the right, and 0th column is the top.
			// Rotate 90 degrees
			transform = CGAffineTransformMake(0.0, -1.0, 1.0, 0.0, 0.0, w);
			break;
			
		case 7:
			// 7 = 0th row is on the right, and 0th column is the bottom.
			// Rotate 90 degrees and Flip Vertical
			transform = CGAffineTransformMake(0.0, 1.0, 1.0, 0.0, 0.0, 0.0);
			break;
			
		case 8:
			// 8 = 0th row is on the left, and 0th column is the bottom.
			// Rotate -90 degrees
			transform = CGAffineTransformMake(0.0, 1.0,-1.0, 0.0, h, 0.0);
			break;
	}
	
	CGImageRef rotatedImage = NULL;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGContextRef context = CGBitmapContextCreate(NULL,
												 (orientationProperty < 5) ? w : h,
												 (orientationProperty < 5) ? h : w,
												 8,
												 0,
												 colorSpace,
												 kCGImageAlphaPremultipliedFirst);
	CGColorSpaceRelease(colorSpace);
												 
	if (context)
	{											 
		CGContextSetAllowsAntialiasing(context, FALSE);
		CGContextSetInterpolationQuality(context, kCGInterpolationNone);
		CGContextConcatCTM(context, transform);
		CGContextDrawImage(context, CGRectMake(0, 0, w, h), imgRef);
		rotatedImage = CGBitmapContextCreateImage(context);
		CFRelease(context);
		
		[NSMakeCollectable(rotatedImage) autorelease];
	}
	
	return rotatedImage;
}

- (NSString*)pyramidPathForImage:(NSNumber*)idLocal
{
	FMDatabase *database = [self thumbnailDatabase];
	NSString *pyramidPath = nil;
	
	if (database != nil) {		
		NSString* query =	@" SELECT apcp.relativeDataPath pyramidPath"
							@" FROM Adobe_images ai"
							@" INNER JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"
							@" WHERE ai.id_local = ?"
							@" ORDER BY ai.pyramidIDCache ASC"
							@" LIMIT 1";
	
		FMResultSet* results = [database executeQuery:query, idLocal];
		
		if ([results next]) {				
			pyramidPath = [results stringForColumn:@"pyramidPath"];
		}
	
		[results close];
	}
	
	return pyramidPath;
}

- (NSData*)previewDataForObject:(IMBObject*)inObject maximumSize:(NSNumber*)maximumSize
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
	NSString* absolutePyramidPath = [lightroomObject absolutePyramidPath];
	NSData* jpegData = nil;
	
	if (absolutePyramidPath != nil) {
		FMDatabase *database = [self thumbnailDatabase];
		
		if (database != nil) {
			NSDictionary* metadata = [lightroomObject preliminaryMetadata];
			NSNumber* idLocal = [metadata objectForKey:@"idLocal"];
			
			@synchronized (database) {
				FMResultSet* results = nil;
				
				if (maximumSize != nil) {
					NSString* query =	@" SELECT pcpl.dataOffset, pcpl.dataLength"
										@" FROM Adobe_images ai"
										@" INNER JOIN Adobe_previewCachePyramidLevels pcpl ON pcpl.pyramid = ai.pyramidIDCache"
										@" WHERE ai.id_local = ?"
										@" AND pcpl.height <= ?"
										@" AND pcpl.width <= ?"
										@" ORDER BY pcpl.height, pcpl.width DESC"
										@" LIMIT 1";
					
					results = [database executeQuery:query, idLocal, maximumSize, maximumSize];
				}
				else {
					NSString* query =	@" SELECT pcpl.dataOffset, pcpl.dataLength"
										@" FROM Adobe_images ai"
										@" INNER JOIN Adobe_previewCachePyramidLevels pcpl ON pcpl.pyramid = ai.pyramidIDCache"
										@" WHERE ai.id_local = ?"
										@" ORDER BY pcpl.height, pcpl.width DESC"
										@" LIMIT 1";
					
					results = [database executeQuery:query, idLocal];
				}
				
				if ([results next]) {				
					double dataOffset = [results doubleForColumn:@"dataOffset"];
					double dataLength = [results doubleForColumn:@"dataLength"];
					
					NSData* data = [NSData dataWithContentsOfMappedFile:absolutePyramidPath];
					
					jpegData = [data subdataWithRange:NSMakeRange(dataOffset, dataLength)];
				}
				
				[results close];
			}
		}
	}
	
	return jpegData;
}


//----------------------------------------------------------------------------------------------------------------------

- (id) loadThumbnailForObject:(IMBObject*)inObject
{
	CGImageRef imageRepresentation = nil;
	NSData *jpegData = [self previewDataForObject:inObject maximumSize:[NSNumber numberWithFloat:256.0]];

	if (jpegData != nil) {
		CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)jpegData, nil);

		if (source != NULL) {
			imageRepresentation = CGImageSourceCreateImageAtIndex(source, 0, NULL);

			CFRelease(source);
		}

		[NSMakeCollectable(imageRepresentation) autorelease];

		if (imageRepresentation) {
			IMBLightroomObject *lightroomObject = (IMBLightroomObject*)inObject;
			NSString *orientation = [[lightroomObject preliminaryMetadata] objectForKey:@"orientation"];

			if (!((orientation == nil) || [orientation isEqual:@"AB"])) {
				NSInteger orientationProperty = 2;

				if ([orientation isEqual:@"BC"]) {
					orientationProperty = 6;
				}
				else if ([orientation isEqual:@"CD"]) {
					orientationProperty = 4;
				}
				else if ([orientation isEqual:@"DA"]) {
					orientationProperty = 8;
				}
				else if ([orientation isEqual:@"CB"]) {
					orientationProperty = 5;
				}
				else if ([orientation isEqual:@"DC"]) {
					orientationProperty = 3;
				}
				else if ([orientation isEqual:@"AD"]) {
					orientationProperty = 7;
				}

				imageRepresentation = [self imageRotated:imageRepresentation forOrientation:orientationProperty];
			}
		}
	}

	// Return the result to the main thread...

	if (imageRepresentation) {
		[inObject performSelectorOnMainThread:@selector(setImageRepresentation:)
								   withObject:(id)imageRepresentation
								waitUntilDone:NO
										modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	else {
		imageRepresentation = (CGImageRef) [super loadThumbnailForObject:inObject];
	}

	return (id) imageRepresentation;
}


//----------------------------------------------------------------------------------------------------------------------


// Loaded lazily when actually needed for display. Here we combine the metadata we got from the Lightroom database
// (which was available immediately, but not enough information) with more information that we obtain via ImageIO.
// This takes a little longer, but since it only done laziy for those object that are actually visible it's fine.
// Please note that this method may be called on a background thread...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	if ([inObject isKindOfClass:[IMBLightroomObject class]])
	{
		IMBLightroomObject* object = (IMBLightroomObject*)inObject;
		NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:object.preliminaryMetadata];
		[metadata addEntriesFromDictionary:[NSImage imb_metadataFromImageAtPath:object.path checkSpotlightComments:NO]];
		NSString* description = [self metadataDescriptionForMetadata:metadata];

		if ([NSThread isMainThread])
		{
			inObject.metadata = metadata;
			inObject.metadataDescription = description;
		}
		else
		{
			NSArray* modes = [NSArray arrayWithObject:NSRunLoopCommonModes];
			[inObject performSelectorOnMainThread:@selector(setMetadata:) withObject:metadata waitUntilDone:NO modes:modes];
			[inObject performSelectorOnMainThread:@selector(setMetadataDescription:) withObject:description waitUntilDone:NO modes:modes];
		}
	}
}


// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return [NSImage imb_imageMetadataDescriptionForMetadata:inMetadata];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Database Access


// Returns the name of the libary...

- (NSString*) libraryName
{
	NSString* path = self.mediaSource;
	NSString* name = [[path lastPathComponent] stringByDeletingPathExtension];
	return name;
}


// Return a database object for our library...

- (FMDatabase*) libraryDatabase
{
	NSString* databasePath = self.mediaSource;
	FMDatabase* database = [FMDatabase databaseWithPath:databasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*) previewsDatabase
{
	NSString* databasePath = self.mediaSource;
	FMDatabase* database = [FMDatabase databaseWithPath:databasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

// NOTE: We return a separate FMDatabase instance per thread. This seems to 
// eliminate some funky SQLite behavior that was observed when separate threads 
// try to interact with the same connection from different threads.

- (FMDatabase*)database
{
	FMDatabase* foundDatabase = nil;
	@synchronized (self) {
		foundDatabase = [_databases objectForKey:[NSValue valueWithPointer:[NSThread currentThread]]];
		if (foundDatabase == nil) {
			foundDatabase = [self libraryDatabase];
			
			if ([foundDatabase open]) {
				[_databases setObject:foundDatabase forKey:[NSValue valueWithPointer:[NSThread currentThread]]];
			}
		}
	}
	
	return foundDatabase;
}

- (FMDatabase*)thumbnailDatabase
{
	FMDatabase* foundDatabase = nil;
	@synchronized (self) {
		foundDatabase = [_thumbnailDatabases objectForKey:[NSValue valueWithPointer:[NSThread currentThread]]];
		if (foundDatabase == nil) {
			foundDatabase = [self previewsDatabase];
			
			if ([foundDatabase open]) {
				[_thumbnailDatabases setObject:foundDatabase forKey:[NSValue valueWithPointer:[NSThread currentThread]]];
			}
		}
	}
	
	return foundDatabase;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Node Identifiers


// The root node always has the hardcoded idLocal 0...

- (NSString*) rootNodeIdentifier
{
	NSString* libraryPath = self.mediaSource;
	NSString* libraryName = [self libraryName];
	NSString* path = [NSString stringWithFormat:@"/%@(%lu)",libraryName,(unsigned long)[libraryPath hash]];
	return [self identifierForPath:path];
}


// Create an unique identifier from the idLocal. An example is "IMBLightroomParser://Peter(123)/folder/17"...

- (NSString*) pathPrefixWithType:(NSString*)type
{
	NSString* libraryPath = self.mediaSource;
	NSString* libraryName = [self libraryName];
	NSString* pathPrefix = [NSString stringWithFormat:@"/%@(%lu)/%@/",libraryName,(unsigned long)[libraryPath hash],type];
	return pathPrefix;
}

- (NSString*) identifierWithFolderId:(NSNumber*)inIdLocal
{
	NSString* identifierPrefix = [self pathPrefixWithType:@"folder"];
	NSString* path = [identifierPrefix stringByAppendingString:[inIdLocal description]];
	return [self identifierForPath:path];
}


- (NSString*) identifierWithCollectionId:(NSNumber*)inIdLocal
{
	NSString* identifierPrefix = [self pathPrefixWithType:@"collection"];
	NSString* path = [identifierPrefix stringByAppendingString:[inIdLocal description]];
	return [self identifierForPath:path];
}


//----------------------------------------------------------------------------------------------------------------------


// We are using the attributes dictionary to store id_local for each node. This is essential in populateObjectsForNode:
// because these the SQL query needs to know which images to look up in the database...


- (NSDictionary*) attributesWithRootFolder:(NSNumber*)inRootFolder
								   idLocal:(NSNumber*)inIdLocal
								  rootPath:(NSString*)inRootPath
							  pathFromRoot:(NSString*)inPathFromRoot
                                  nodeType:(IMBLightroomNodeType)inNodeType
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:5];
	
	[dictionary setValue:inRootFolder forKey:@"rootFolder"];
	[dictionary setValue:inRootPath forKey:@"rootPath"];
	[dictionary setValue:inIdLocal forKey:@"id_local"];
	[dictionary setValue:inPathFromRoot forKey:@"pathFromRoot"];
	[dictionary setValue:[NSNumber numberWithInt:inNodeType] forKey:@"nodeType"];
	
	return dictionary;
}

- (NSNumber*) rootFolderFromAttributes:(NSDictionary*)inAttributes
{
	return [inAttributes objectForKey:@"rootFolder"];
}

- (NSNumber*) idLocalFromAttributes:(NSDictionary*)inAttributes
{
	return [inAttributes objectForKey:@"id_local"];
}

- (NSString*) rootPathFromAttributes:(NSDictionary*)inAttributes
{
	return [inAttributes objectForKey:@"rootPath"];
}

- (NSString*) pathFromRootFromAttributes:(NSDictionary*)inAttributes
{
	return [inAttributes objectForKey:@"pathFromRoot"];
}

- (IMBLightroomNodeType) nodeTypeFromAttributes:(NSDictionary*)inAttributes
{
	return [[inAttributes objectForKey:@"nodeType"] intValue];
}

- (NSString*) absolutePathFromAttributes:(NSDictionary*)inAttributes
{
	NSString *rootPath = [self rootPathFromAttributes:inAttributes];
	NSString *pathFromRoot = [self pathFromRootFromAttributes:inAttributes];
	
	if ([pathFromRoot length] > 0) {
		return [rootPath stringByAppendingPathComponent:pathFromRoot];
	}
	
	return rootPath;
}


//----------------------------------------------------------------------------------------------------------------------


// For Lightroom we need a promise that splits the pyramid file
- (IMBObjectsPromise*) objectPromiseWithObjects: (NSArray*) inObjects
{
	return [[[IMBPyramidObjectPromise alloc] initWithIMBObjects:inObjects] autorelease];
}

- (void) willShowContextMenu:(NSMenu*)inMenu forObject:(IMBObject*)inObject
{
	if (![inObject isKindOfClass:[IMBLightroomObject class]]) {
		return;
	}
	
	for (NSMenuItem* menuItem in [inMenu itemArray]) {
		SEL action = [menuItem action];
		
		if (action == @selector(openInEditorApp:)) {
			NSString* titleFormat = NSLocalizedStringWithDefaultValue(
																	  @"IMBObjectViewController.menuItem.openWithApp.Lightroom",
																	  nil,IMBBundle(),
																	  @"Open Master Image With %@",
																	  @"Menu item in context menu of IMBObjectViewController");
			NSString* appName = [[NSFileManager imb_threadSafeManager] displayNameAtPath:[IMBConfig editorAppForMediaType:self.mediaType]];
			NSString* title = [NSString stringWithFormat:titleFormat, appName];	
			
			[menuItem setTitle:title];
		}
		else if (action == @selector(openInViewerApp:)) {
			NSString* titleFormat = NSLocalizedStringWithDefaultValue(
																	  @"IMBObjectViewController.menuItem.openWithApp.Lightroom",
																	  nil,IMBBundle(),
																	  @"Open Master Image With %@",
																	  @"Menu item in context menu of IMBObjectViewController");
			NSString* appName = [[NSFileManager imb_threadSafeManager] displayNameAtPath:[IMBConfig viewerAppForMediaType:self.mediaType]];
			NSString* title = [NSString stringWithFormat:titleFormat, appName];	
			
			[menuItem setTitle:title];
		}
		else if (action == @selector(openInApp:)) {
			NSString* title = NSLocalizedStringWithDefaultValue(
																@"IMBObjectViewController.menuItem.openWithFinder.Lightroom",
																nil,IMBBundle(),
																@"Open Master Image with Finder",
																@"Menu item in context menu of IMBObjectViewController");
			
			[menuItem setTitle:title];
		}
		else if (action == @selector(revealInFinder:)) {
			NSString* title = NSLocalizedStringWithDefaultValue(
																@"IMBObjectViewController.menuItem.revealInFinder.Lightroom",
																nil,IMBBundle(),
																@"Show Master Image in Finder",
																@"Menu item in context menu of IMBObjectViewController");
			
			[menuItem setTitle:title];
		}
	}
	
	[inMenu addItem:[NSMenuItem separatorItem]];

	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
	NSString* path = [lightroomObject path];
	
	if ([[NSFileManager imb_threadSafeManager] fileExistsAtPath:path]) {
		IMBMutableOrderedDictionary *applications = [IMBMutableOrderedDictionary orderedDictionaryWithCapacity:2];
		
		NSString* editorAppKey = [IMBConfig editorAppForMediaType:self.mediaType];
		if (editorAppKey != nil) [applications setObject:@"openPreviewInEditorApp:" forKey:editorAppKey];
		
		NSString* viewerAppKey = [IMBConfig viewerAppForMediaType:self.mediaType];
		if (viewerAppKey != nil) [applications setObject:@"openPreviewInViewerApp:" forKey:viewerAppKey];

		for (NSString* appPath in [applications allKeys]) {
			NSString* titleFormat = NSLocalizedStringWithDefaultValue(
																	  @"IMBObjectViewController.menuItem.openPreviewInApp.Lightroom",
																	  nil,IMBBundle(),
																	  @"Open Processed Image in %@",
																	  @"Menu item in context menu of IMBLightroomParser");
			NSString* appName = [[NSFileManager imb_threadSafeManager] displayNameAtPath:appPath];
			NSString* title = [NSString stringWithFormat:titleFormat, appName];	

			NSString* selector = [applications objectForKey:appPath];
			NSMenuItem* openPreviewItem = [[NSMenuItem alloc] initWithTitle:title 
																	 action:NSSelectorFromString(selector) 
															  keyEquivalent:@""];
			
			[openPreviewItem setTarget:self];
			[openPreviewItem setRepresentedObject:inObject];
			
			[inMenu addItem:openPreviewItem];
			[openPreviewItem release];
		}
	}
}

- (void)revealPyramid:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSString* absolutePyramidPath = [lightroomObject absolutePyramidPath];
	NSString* folder = [absolutePyramidPath stringByDeletingLastPathComponent];
	
	[[NSWorkspace imb_threadSafeWorkspace] selectFile:absolutePyramidPath inFileViewerRootedAtPath:folder];
}

- (void)openPreviewInApp:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSURL* url = [IMBPyramidObjectPromise urlForObject:lightroomObject];
	
	[[NSWorkspace imb_threadSafeWorkspace] openURL:url];
}

- (void)openPreviewInEditorApp:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSURL* url = [IMBPyramidObjectPromise urlForObject:lightroomObject];
	NSString* app = [IMBConfig editorAppForMediaType:self.mediaType];
	
	[[NSWorkspace imb_threadSafeWorkspace] openFile:[url path] withApplication:app];
}

- (void)openPreviewInViewerApp:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSURL* url = [IMBPyramidObjectPromise urlForObject:lightroomObject];
	NSString* app = [IMBConfig viewerAppForMediaType:self.mediaType];
	
	[[NSWorkspace imb_threadSafeWorkspace] openFile:[url path] withApplication:app];
}

@end
