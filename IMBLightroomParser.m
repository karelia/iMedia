/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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

#import <Quartz/Quartz.h>

#import "FMDatabase.h"
#import "FMResultSet.h"
#import "IMBConfig.h"
#import "IMBLightroom1Parser.h"
#import "IMBLightroom2Parser.h"
#import "IMBLightroom3Parser.h"
#import "IMBLightroom3VideoParser.h"
#import "IMBIconCache.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBObject.h"
#import "IMBObjectPromise.h"
#import "IMBOrderedDictionary.h"
#import "IMBParserController.h"
#import "IMBPyramidObjectPromise.h"
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"
#import "NSWorkspace+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSArray* sSupportedUTIs = nil;


//----------------------------------------------------------------------------------------------------------------------


// This subclass adds the addition apertureMetadata property, which stores the metadata coming from the database. 
// it will later be augmented (lazily) by metadata read from the file itself (which is a fairly slow process).
// That is why that step is only done lazily...


@implementation IMBLightroomObject

@synthesize absolutePyramidPath = _absolutePyramidPath;

- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]) != nil) {
		self.absolutePyramidPath = [inCoder decodeObjectForKey:@"absolutePyramidPath"];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	
	[inCoder encodeObject:self.absolutePyramidPath forKey:@"absolutePyramidPath"];
}

- (id) copyWithZone:(NSZone*)inZone
{
	IMBLightroomObject* copy = [super copyWithZone:inZone];
	
	copy.absolutePyramidPath = self.absolutePyramidPath;
	
	return copy;
}

- (void) dealloc
{
	IMBRelease(_absolutePyramidPath);
	
	[super dealloc];
}


#pragma mark 
#pragma mark IKImageBrowserItem Protocol

// Use the path or URL as the unique identifier...

- (NSString*) imageUID
{
	if (_absolutePyramidPath != nil) {
		return _absolutePyramidPath;
	}
	
	return [super imageUID];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLightroomParser ()

+ (void) parseRecentLibrariesList:(NSString*)inRecentLibrariesList into:(NSMutableArray*)inLibraryPaths;
- (NSString*) libraryName;

- (void) populateSubnodesForRootNode:(IMBNode*)inRootNode;
- (void) populateSubnodesForRootFoldersNode:(IMBNode*)inFoldersNode;
- (void) populateSubnodesForFolderNode:(IMBNode*)inParentNode;
- (void) populateSubnodesForCollectionNode:(IMBNode*)inRootNode;
- (void) populateObjectsForFolderNode:(IMBNode*)inNode;
- (void) populateObjectsForCollectionNode:(IMBNode*)inNode;

- (NSArray*) supportedUTIs;
- (BOOL) canOpenImageFileAtPath:(NSString*)inPath;
- (IMBObject*) objectWithPath:(NSString*)inPath
						 name:(NSString*)inName
				  pyramidPath:(NSString*)inPyramidPath
					 metadata:(NSDictionary*)inMetadata
						index:(NSUInteger)inIndex;
- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata;

- (NSString*) rootNodeIdentifier;
- (NSString*) identifierWithFolderId:(NSNumber*)inIdLocal;
- (NSString*) identifierWithCollectionId:(NSNumber*)inIdLocal;
- (BOOL) isFolderNode:(IMBNode*)inNode;
- (BOOL) isCollectionNode:(IMBNode*)inNode;

- (NSDictionary*) attributesWithRootFolder:(NSNumber*)inRootFolder
								   idLocal:(NSNumber*)inIdLocal
								  rootPath:(NSString*)inRootPath
							  pathFromRoot:(NSString*)inPathFromRoot;
- (NSNumber*) rootFolderFromAttributes:(NSDictionary*)inAttributes;
- (NSNumber*) idLocalFromAttributes:(NSDictionary*)inAttributes;
- (NSString*) rootPathFromAttributes:(NSDictionary*)inAttributes;
- (NSString*) pathFromRootFromAttributes:(NSDictionary*)inAttributes;
- (NSString*) absolutePathFromAttributes:(NSDictionary*)inAttributes;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLightroomParser

@synthesize appPath = _appPath;
@synthesize dataPath = _dataPath;
@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;
@synthesize database = _database;
@synthesize thumbnailDatabase = _thumbnailDatabase;


//----------------------------------------------------------------------------------------------------------------------


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeMovie];
	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


// Helper method that converts simgle string into an array of paths...

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
                [inLibraryPaths addObject:[path substringWithRange:NSMakeRange(1, [path length] - 3)]];
                path = @"";
            }
        }
        
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    }
}


//----------------------------------------------------------------------------------------------------------------------


// Factory method for the parser instances. Create one instance per library and configure it...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	if ([kIMBMediaTypeImage isEqualTo:inMediaType]) {
		[parserInstances addObjectsFromArray:[IMBLightroom1Parser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom2Parser concreteParserInstancesForMediaType:inMediaType]];
		[parserInstances addObjectsFromArray:[IMBLightroom3Parser concreteParserInstancesForMediaType:inMediaType]];
	}
	else if ([kIMBMediaTypeMovie isEqualTo:inMediaType]) {
		[parserInstances addObjectsFromArray:[IMBLightroom3VideoParser concreteParserInstancesForMediaType:inMediaType]];
	}
			  
	return parserInstances;
}

+ (BOOL) isInstalled
{
	return [self lightroomPath] != nil;
}

//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.appPath = [[self class] lightroomPath];
		_database = nil;
		_thumbnailSize = NSZeroSize;
		
		[self supportedUTIs];	// Init early and in the main thread!
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_database);
	[super dealloc];
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
		NSImage* icon = [[NSWorkspace threadSafeWorkspace] iconForFile:self.appPath];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0,16.0)];
		
		node.parentNode = inOldNode.parentNode;
		node.mediaSource = self.mediaSource;
		node.identifier = [self rootNodeIdentifier];
		node.name = @"Lightroom";
		node.icon = icon;
		node.parser = self;
		node.leaf = NO;
		node.groupType = kIMBGroupTypeLibrary;
		node.objects = [NSMutableArray array];
	}
	else
	{
		node.parentNode = inOldNode.parentNode;
		node.mediaSource = self.mediaSource;
		node.identifier = inOldNode.identifier;
		node.name = inOldNode.name;
		node.icon = inOldNode.icon;
		node.parser = self;
		node.leaf = inOldNode.leaf;
		node.groupType = inOldNode.groupType;
		node.attributes = [[inOldNode.attributes copy] autorelease];
	}
	
	if (node.isRootNode && self.shouldDisplayLibraryName)
	{
		node.name = [NSString stringWithFormat:@"%@ (%@)",node.name,[self libraryName]];
	}
	
	// Watch the root node. Whenever something in Lightroom changes, we have to replace the
	// WHOLE node tree, as we have no way of finding out WHAT has changed in Lightroom...
	
	if (node.parentNode == nil)
	{
		node.watcherType = kIMBWatcherTypeFSEvent;
		node.watchedPath = (NSString*)self.mediaSource;
	}
	else
	{
		node.watcherType = kIMBWatcherTypeNone;
	}
	
	// If the old node was populated, then also populate the new node...
	
	if (inOldNode.subNodes.count > 0 || inOldNode.objects.count > 0)
	{
		[self populateNode:node options:inOptions error:&error];
	}
	
	if (outError) *outError = error;
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	// Create subnodes for the root node as needed...
	
	if ([inNode isRootNode])
	{
		[self populateSubnodesForRootNode:inNode];
	}
	
	// Create subnodes for the Folders node as needed...
	
	else if ([self isFolderNode:inNode])
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
	}
	
	// Create subnodes for the Collections node as needed...
	
	else if ([self isCollectionNode:inNode])
	{
		[self populateSubnodesForCollectionNode:inNode];
		[self populateObjectsForCollectionNode:inNode];
	}
	
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


// When the parser is deselected, then get rid of cached data. In our case we can close the database...

- (void) didStopUsingParser
{
	@synchronized (self) {
		self.database = nil;
		self.thumbnailDatabase = nil;
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Creating Subnodes


// This method creates the immediate subnodes of the "Lightroom" root node. The two subnodes are "Folders"  
// and "Collections"...

- (void) populateSubnodesForRootNode:(IMBNode*)inRootNode
{
	if (inRootNode.subNodes == nil) {
		inRootNode.subNodes = [NSMutableArray array];
	}
	
	[self populateSubnodesForCollectionNode:inRootNode];
}


//----------------------------------------------------------------------------------------------------------------------


// This method creates the immediate subnodes of the "Folders" node. The Lightroom database seems to call them
// root folders. Each import usually creates one of these folders with the capture date as the folder name...

- (void) populateSubnodesForRootFoldersNode:(IMBNode*)inFoldersNode
{
	// Add subnodes array, even if nothing is found in database, so that we do not cause endless loop...
	
	if (inFoldersNode.subNodes == nil) {
		inFoldersNode.subNodes = [NSMutableArray array];
	}
	
	if (inFoldersNode.objects == nil) {
		inFoldersNode.objects = [NSMutableArray array];
	}
	
	// Query the database for the root folders and create a node for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSString* query = [self rootFolderQuery];
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
			node.parentNode = inFoldersNode;
			node.name = name;
			node.icon = [self folderIcon];
			node.parser = self;
			node.mediaSource = self.mediaSource;
			node.identifier = [self identifierWithFolderId:id_local];
			node.attributes = [self attributesWithRootFolder:id_local
													 idLocal:nil
													rootPath:path
												pathFromRoot:nil];
			node.leaf = NO;
			
			[(NSMutableArray*)inFoldersNode.subNodes addObject:node];
			
			IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];
			object.location = (id)node;
			object.name = name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
			
			[(NSMutableArray*)inFoldersNode.objects addObject:object];
			
			[pool release];
		}
		
		[results close];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This method creates subnodes for folders deeper into the hierarchy. Please note that here the SQL query is different
// from the previous method. We are no longer selecting from AgLibraryRootFolder, but from AgLibraryFolder instead...

- (void) populateSubnodesForFolderNode:(IMBNode*)inParentNode
{
	// Add subnodes array, even if nothing is found in database, so that we do not cause endless loop...
	
	if (inParentNode.subNodes == nil) {
		inParentNode.subNodes = [NSMutableArray array];
	}
	
	if (inParentNode.objects == nil) {
		inParentNode.objects = [NSMutableArray array];
	}
	
	// Query the database for subfolder and add a node for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSDictionary* attributes = inParentNode.attributes;
		NSString* parentPathFromRoot = [self pathFromRootFromAttributes:attributes];	
		NSNumber* parentRootFolder = [self rootFolderFromAttributes:attributes];
		NSString* parentRootPath = [self rootPathFromAttributes:inParentNode.attributes];
		NSString* query = [self folderNodesQuery];
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
				
				node.parentNode = inParentNode;
				node.icon = [self folderIcon];
				node.parser = self;
				node.mediaSource = self.mediaSource;
				node.name = [pathFromRoot lastPathComponent];
				node.leaf = NO;
				
				[(NSMutableArray*)inParentNode.subNodes addObject:node];
			}
			else {
				node = inParentNode;
			}
			
			node.identifier = [self identifierWithFolderId:id_local];

			NSDictionary* attributes = [self attributesWithRootFolder:parentRootFolder
															  idLocal:id_local
															 rootPath:parentRootPath
														 pathFromRoot:pathFromRoot];
			node.attributes = attributes;
			
			NSString* path = [self absolutePathFromAttributes:attributes];
			
			IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];
			object.location = (id)node;
			object.name = node.name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
			
			[(NSMutableArray*)inParentNode.objects addObject:object];
		}
		
		[results close];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This method Collection subnodes for the specified parent node. Even though the query returns all Collections,
// only create nodes that are immediate children of our parent node. This is necessary, because the returned 
// results from the query are not ordered in a way that would let us build the whole node tree in one single
// step...

- (void) populateSubnodesForCollectionNode:(IMBNode*)inParentNode 
{
	// Add an empty subnodes array, to avoid endless loop, even if the following query returns no results...
	
	if (inParentNode.subNodes == nil) {
		inParentNode.subNodes = [NSMutableArray array];
	}
	
	if (inParentNode.objects == nil) {
		inParentNode.objects = [NSMutableArray array];
	}
	
	
	// Now query the database for subnodes to the specified parent node...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSDictionary* attributes = inParentNode.attributes;
		NSNumber* collectionId = [self idLocalFromAttributes:attributes];
		NSString* query = nil;
		FMResultSet* results = nil;
		
		if ([collectionId longValue] == 0) {
			query = [self rootCollectionNodesQuery];
			results = [database executeQuery:query];
		}
		else {
			query = [self collectionNodesQuery];
			results = [database executeQuery:query, collectionId];
		}
		
		NSInteger index = 0;
		
		while ([results next]) {
			// Get properties for next collection. Also substitute missing names...
			
			NSNumber* idLocal = [NSNumber numberWithLong:[results longForColumn:@"id_local"]]; 
			NSNumber* idParentLocal = [NSNumber numberWithLong:[results longForColumn:@"parent"]];
			NSString* name = [results stringForColumn:@"name"];
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
			
			IMBNode* node = [[[IMBNode alloc] init] autorelease];
			node.parentNode = inParentNode;
			node.identifier = [self identifierWithCollectionId:idLocal];
			node.name = name;
			node.icon = isGroup ? [self groupIcon] : [self collectionIcon];
			node.parser = self;
			node.mediaSource = self.mediaSource;
			node.attributes = [self attributesWithRootFolder:nil
													 idLocal:idLocal
													rootPath:nil
												pathFromRoot:nil];
			node.leaf = NO;
			
			[(NSMutableArray*)inParentNode.subNodes addObject:node];
			
			IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];
			object.location = (id)node;
			object.name = node.name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [self largeFolderIcon];
			
			[(NSMutableArray*)inParentNode.objects addObject:object];
		}
		
		[results close];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) largeFolderIcon
{
	NSImage* icon = [NSImage genericFolderIcon];
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
		inNode.objects = [NSMutableArray array];
	}
	
	// Query the database for image files for the specified node. Add an IMBObject for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSMutableArray* objects = [NSMutableArray array];
		NSString* query = [self folderObjectsQuery];
		
		NSDictionary* attributes = inNode.attributes;
		NSString* folderPath = [self absolutePathFromAttributes:attributes];
		NSNumber* folderId = [self idLocalFromAttributes:attributes];
		FMResultSet* results = [database executeQuery:query, folderId];
		NSUInteger index = 0;
		
		while ([results next]) {
			NSString* filename = [results stringForColumn:@"idx_filename"];
			NSNumber* idLocal = [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
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
				
				IMBObject* object = [self objectWithPath:path
													name:name
											 pyramidPath:pyramidPath
												metadata:metadata
												   index:index++];
				
				[objects addObject:object];
			}
		}
		
		[results close];
		
		[objects addObjectsFromArray:inNode.objects];
		[(NSMutableArray*)inNode.objects setArray:objects];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This method populates an existing folder node with objects (image files). The essential part is id_local stored
// in the attributes dictionary. It determines the correct database query...

- (void) populateObjectsForCollectionNode:(IMBNode*)inNode
{
	// Add object array, even if nothing is found in database, so that we do not cause endless loop...
	
	if (inNode.objects == nil) {
		inNode.objects = [NSMutableArray array];
	}
	
	// Query the database for image files for the specified node. Add an IMBObject for each one we find...
	
	FMDatabase *database = self.database;
	
	if (database != nil) {
		NSString* query = [self collectionObjectsQuery];
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
													name:name
											 pyramidPath:pyramidPath
												metadata:metadata
												   index:index++];
				[(NSMutableArray*)inNode.objects addObject:object];
			}
		}
		
		[results close];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Check if we can open this image file...

- (BOOL) canOpenImageFileAtPath:(NSString*)inPath
{
	NSString* uti = [NSString UTIForFileAtPath:inPath];
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
						 name:(NSString*)inName
				  pyramidPath:(NSString*)inPyramidPath
					 metadata:(NSDictionary*)inMetadata
						index:(NSUInteger)inIndex
{
	IMBLightroomObject* object = [[[IMBLightroomObject alloc] init] autorelease];
	NSString* absolutePyramidPath = (inPyramidPath != nil) ? [self.dataPath stringByAppendingPathComponent:inPyramidPath] : nil;

	object.absolutePyramidPath = absolutePyramidPath;
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


- (void) objectViewDidChangeIconSize:(NSSize)inSize
{
	if (_thumbnailSize.width<inSize.width || _thumbnailSize.height<inSize.height)
	{
		_thumbnailSize = inSize;
		[self invalidateThumbnails];
	}	
}

- (CGImageRef)imageRotated:(CGImageRef)imgRef forOrientation:(NSInteger)orientationProperty
{
	CGFloat w = CGImageGetWidth(imgRef);
	CGFloat h = CGImageGetHeight(imgRef);
	
	CGAffineTransform transform;
	
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
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGContextRef context = CGBitmapContextCreate(NULL,
												 (orientationProperty < 5) ? w : h,
												 (orientationProperty < 5) ? h : w,
												 8,
												 0,
												 colorSpace,
												 kCGImageAlphaPremultipliedFirst);
	CGContextSetAllowsAntialiasing(context, FALSE);
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
	CGColorSpaceRelease(colorSpace);
	
	CGContextConcatCTM(context, transform);
	CGContextDrawImage(context, CGRectMake(0, 0, w, h), imgRef);
	
	CGImageRef rotatedImage = CGBitmapContextCreateImage(context);
	
	CFRelease(context);
	[NSMakeCollectable(rotatedImage) autorelease];
	
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

- (NSData*)previewDataForObject:(IMBObject*)inObject
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
	NSString* absolutePyramidPath = [lightroomObject absolutePyramidPath];
	
	if (absolutePyramidPath != nil) {
		FMDatabase *database = [self thumbnailDatabase];
		
		if (database != nil) {
			NSNumber* targetWidth = [NSNumber numberWithDouble:_thumbnailSize.width];
			NSNumber* targetHeight = [NSNumber numberWithDouble:_thumbnailSize.height];
			NSDictionary* metadata = [lightroomObject preliminaryMetadata];
			NSNumber* idLocal = [metadata objectForKey:@"idLocal"];
			
			@synchronized (database) {
				NSString* query =	@" SELECT pcpl.dataOffset, pcpl.dataLength"
									@" FROM Adobe_images ai"
									@" INNER JOIN Adobe_previewCachePyramidLevels pcpl ON pcpl.pyramid = ai.pyramidIDCache"
									@" WHERE ai.id_local = ?"
									@" AND pcpl.height >= ?"
									@" AND pcpl.width >= ?"
									@" ORDER BY pcpl.height, pcpl.width ASC"
									@" LIMIT 1";
				
				FMResultSet* results = [database executeQuery:query, idLocal, targetWidth, targetHeight];
				
				if ([results next]) {				
					double dataOffset = [results doubleForColumn:@"dataOffset"];
					double dataLength = [results doubleForColumn:@"dataLength"];
					
					NSData* data = [NSData dataWithContentsOfMappedFile:absolutePyramidPath];
					NSData* jpegData = [data subdataWithRange:NSMakeRange(dataOffset, dataLength)];
					
					return jpegData;
				}
				
				[results close];
			}
		}
	}
	
	return nil;
}


- (void) loadThumbnailForObject:(IMBObject*)inObject
{	
	CGImageRef imageRepresentation = nil;
	NSData *jpegData = [self previewDataForObject:inObject];
	
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
		[super loadThumbnailForObject:inObject];
	}
}
	

//----------------------------------------------------------------------------------------------------------------------


// Loaded lazily when actually needed for display. Here we combine the metadata we got from the Lightroom database
// (which was available immediately, but not enough information) with more information that we obtain via ImageIO.
// This takes a little longer, but since it only done laziy for those object that are actually visible it's fine.
// Please note that this method may be called on a background thread...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	IMBLightroomObject* object = (IMBLightroomObject*)inObject;
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:object.preliminaryMetadata];
	[metadata addEntriesFromDictionary:[NSImage metadataFromImageAtPath:object.path]];
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


// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return [NSImage imageMetadataDescriptionForMetadata:inMetadata];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Database Access


// Returns the name of the libary...

- (NSString*) libraryName
{
	NSString* path = (NSString*)self.mediaSource;
	NSString* name = [[path lastPathComponent] stringByDeletingPathExtension];
	return name;
}


// Return a database object for our library...

- (FMDatabase*) libraryDatabase
{
	NSString* databasePath = (NSString*)self.mediaSource;
	FMDatabase* database = [FMDatabase databaseWithPath:databasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*) previewsDatabase
{
	NSString* databasePath = (NSString*)self.mediaSource;
	FMDatabase* database = [FMDatabase databaseWithPath:databasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*)database
{
	@synchronized (self) {
		if (_database == nil) {
			FMDatabase* database = [self libraryDatabase];
			
			if ([database open]) {
				_database = [database retain];
			}
		}
	}
	
	return [[_database retain] autorelease];
}

- (FMDatabase*)thumbnailDatabase
{
	@synchronized (self) {
		if (_thumbnailDatabase == nil) {
			FMDatabase* database = [self previewsDatabase];
			
			if ([database open]) {
				_thumbnailDatabase = [database retain];
			}
		}
	}
	
	return [[_thumbnailDatabase retain] autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Node Identifiers


// The root node always has the hardcoded idLocal 0...

- (NSString*) rootNodeIdentifier
{
	NSString* libraryPath = (NSString*) self.mediaSource;
	NSString* libraryName = [self libraryName];
	NSString* path = [NSString stringWithFormat:@"/%@(%i)",libraryName,[libraryPath hash]];
	return [self identifierForPath:path];
}


// Create an unique identifier from the idLocal. An example is "IMBLightroomParser://Peter(123)/folder/17"...

- (NSString*) identifierWithFolderId:(NSNumber*)inIdLocal
{
	NSString* libraryPath = (NSString*) self.mediaSource;
	NSString* libraryName = [self libraryName];
	NSString* path = [NSString stringWithFormat:@"/%@(%i)/folder/%@",libraryName,[libraryPath hash],inIdLocal];
	return [self identifierForPath:path];
}


- (NSString*) identifierWithCollectionId:(NSNumber*)inIdLocal
{
	NSString* libraryPath = (NSString*) self.mediaSource;
	NSString* libraryName = [self libraryName];
	NSString* path = [NSString stringWithFormat:@"/%@(%i)/collection/%@",libraryName,[libraryPath hash],inIdLocal];
	return [self identifierForPath:path];
}


// Node types...


- (BOOL) isFolderNode:(IMBNode*)inNode
{
	NSString* identifier = inNode.identifier;
	return [identifier rangeOfString:@"/folder"].location != NSNotFound;
}


- (BOOL) isCollectionNode:(IMBNode*)inNode
{
	NSString* identifier = inNode.identifier;
	return [identifier rangeOfString:@"/collection"].location != NSNotFound;
}


//----------------------------------------------------------------------------------------------------------------------


// We are using the attributes dictionary to store id_local for each node. This is essential in populateObjectsForNode:
// because these the SQL query needs to know which images to look up in the database...


- (NSDictionary*) attributesWithRootFolder:(NSNumber*)inRootFolder
								   idLocal:(NSNumber*)inIdLocal
								  rootPath:(NSString*)inRootPath
							  pathFromRoot:(NSString*)inPathFromRoot
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
	
	[dictionary setValue:inRootFolder forKey:@"rootFolder"];
	[dictionary setValue:inRootPath forKey:@"rootPath"];
	[dictionary setValue:inIdLocal forKey:@"id_local"];
	[dictionary setValue:inPathFromRoot forKey:@"pathFromRoot"];
	
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
- (IMBObjectPromise*) objectPromiseWithObjects: (NSArray*) inObjects
{
	return [[(IMBObjectPromise*)[IMBPyramidObjectPromise alloc] initWithObjects:inObjects] autorelease];
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
																	  @"IMBObjectViewController.menuItem.openInApp.Lightroom",
																	  nil,IMBBundle(),
																	  @"Open Master Image in %@",
																	  @"Menu item in context menu of IMBObjectViewController");
			NSString* appName = [[NSFileManager threadSafeManager] displayNameAtPath:[IMBConfig editorAppForMediaType:self.mediaType]];
			NSString* title = [NSString stringWithFormat:titleFormat, appName];	
			
			[menuItem setTitle:title];
		}
		else if (action == @selector(openInViewerApp:)) {
			NSString* titleFormat = NSLocalizedStringWithDefaultValue(
																	  @"IMBObjectViewController.menuItem.openInApp.Lightroom",
																	  nil,IMBBundle(),
																	  @"Open Master Image in %@",
																	  @"Menu item in context menu of IMBObjectViewController");
			NSString* appName = [[NSFileManager threadSafeManager] displayNameAtPath:[IMBConfig viewerAppForMediaType:self.mediaType]];
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
																@"Reveal Master Image in Finder",
																@"Menu item in context menu of IMBObjectViewController");
			
			[menuItem setTitle:title];
		}
	}
	
	[inMenu addItem:[NSMenuItem separatorItem]];

	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
	NSString* path = [lightroomObject path];
	
	if ([[NSFileManager threadSafeManager] fileExistsAtPath:path]) {
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
			NSString* appName = [[NSFileManager threadSafeManager] displayNameAtPath:appPath];
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
	
	[[NSWorkspace threadSafeWorkspace] selectFile:absolutePyramidPath inFileViewerRootedAtPath:folder];
}

- (void)openPreviewInApp:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSURL* url = [IMBPyramidObjectPromise urlForObject:lightroomObject];
	
	[[NSWorkspace threadSafeWorkspace] openURL:url];
}

- (void)openPreviewInEditorApp:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSURL* url = [IMBPyramidObjectPromise urlForObject:lightroomObject];
	NSString* app = [IMBConfig editorAppForMediaType:self.mediaType];
	
	[[NSWorkspace threadSafeWorkspace] openFile:[url path] withApplication:app];
}

- (void)openPreviewInViewerApp:(id)sender
{
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)[sender representedObject];
	NSURL* url = [IMBPyramidObjectPromise urlForObject:lightroomObject];
	NSString* app = [IMBConfig viewerAppForMediaType:self.mediaType];
	
	[[NSWorkspace threadSafeWorkspace] openFile:[url path] withApplication:app];
}

@end
