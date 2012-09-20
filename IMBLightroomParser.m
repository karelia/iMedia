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
#import "IMBLightroom3VideoParser.h"
#import "IMBLightroom4VideoParser.h"
#import "IMBIconCache.h"
#import "IMBNode.h"
#import "IMBFolderObject.h"
#import "IMBObject.h"
#import "IMBOrderedDictionary.h"
#import "IMBParserController.h"
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSURL+iMedia.h"
#import "SBUtilities.h"

#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSArray* sSupportedUTIs = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLightroomParser ()

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
					  idLocal:(NSNumber*)idLocal
						 name:(NSString*)inName
				  pyramidPath:(NSString*)inPyramidPath
					 metadata:(NSDictionary*)inMetadata
						index:(NSUInteger)inIndex;

- (NSString*) rootNodeIdentifier;
- (NSString*) identifierWithFolderId:(NSNumber*)inIdLocal;
- (NSString*) identifierWithCollectionId:(NSNumber*)inIdLocal;
- (BOOL) isFolderNode:(IMBNode*)inNode;
- (BOOL) isCollectionNode:(IMBNode*)inNode;
- (BOOL) isRootCollectionNode:(IMBNode*)inNode;

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
@synthesize dataPath = _dataPath;
@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;
@synthesize databases = _databases;
@synthesize thumbnailDatabases = _thumbnailDatabases;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (id) init
{
	if ((self = [super init]))
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
				if (exists) [inLibraryPaths addObject:path];
                
                [fileManager release];
                path = @"";
            }
        }
        
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    }
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	NSError* error = nil;

	NSString* libraryPath = [self.mediaSource path];
	
	NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16.0,16.0)];

	// Create the top-level node...

	IMBNode* node = [[[IMBNode alloc] initWithParser:self topLevel:YES] autorelease];
	node.icon = icon;
	node.name = @"Lightroom";
	node.identifier = [self rootNodeIdentifier];
	node.isLeafNode = NO;
	node.groupType = kIMBGroupTypeLibrary;
	node.isIncludedInPopup = YES;

	// If necessary append the name of the library...
	
	if (node.isTopLevelNode && self.shouldDisplayLibraryName)
	{
		node.name = [NSString stringWithFormat:@"%@ (%@)",node.name,[self libraryName]];
	}

	// Watch the root node. Whenever something in Lightroom changes, we have to replace the
	// WHOLE node tree, as we have no way of finding out WHAT has changed in Lightroom...
	
	node.watcherType = kIMBWatcherTypeFSEvent;
	node.watchedPath = libraryPath;

	if (outError) *outError = error;
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	// Create subnodes for the root node as needed...
	
	if ([inNode isTopLevelNode])
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
	
	else if ([self isRootCollectionNode:inNode])
	{
		[self populateSubnodesForCollectionNode:inNode];
	}
	
    else
    {
		[inNode mutableArrayForPopulatingSubnodes];
        inNode.objects = [NSArray array];
    }

	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// When the parser is deselected, then get rid of cached data. In our case we can close the database...

//- (void) didStopUsingParser
//{
//	@synchronized (self)
//	{
//		self.databases = nil;
//		self.thumbnailDatabases = nil;
//	}
//}


//----------------------------------------------------------------------------------------------------------------------


// Build a thumbnail for our object...

- (id) thumbnailForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
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
#if 0
			CGFloat width = CGImageGetWidth(imageRepresentation);
			CGFloat height = CGImageGetHeight(imageRepresentation);

			NSLog(@"width: %f, height: %f", width, height);
#endif
			
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
	else {
		NSString* title = NSLocalizedStringWithDefaultValue(
															@"IMB.IMBLightroomParser.ThumbnailNotAvailableTitle",
															nil,
															IMBBundle(),
															@"Processed image not found.\n",
															@"Message to export when Pyramid file is missing");
		
		NSString* description  = NSLocalizedStringWithDefaultValue(
																   @"IMB.IMBLightroomParser.ThumbnailNotAvailableDescription",
																   nil,
																   IMBBundle(),
																   @"Please launch Lightroom and select the menu command Library > Previews > Render 1:1 Previews.",
																   @"Message to export when Pyramid file is missing");
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  title, @"title",
								  description, NSLocalizedDescriptionKey,
								  nil];
		
		
		inObject.error = [NSError errorWithDomain:kIMBErrorDomain code:kIMBErrorThumbnailNotAvailable userInfo:userInfo];
	}
	
//	if (imageRepresentation == NULL) {
//		imageRepresentation = [super thumbnailFromLocalImageFileForObject:inObject error:&error];
//	}
		 
	if (outError) *outError = error;
	return (id)imageRepresentation;
}


//----------------------------------------------------------------------------------------------------------------------


// Loaded lazily when actually needed for display. Here we combine the metadata we got from the Lightroom database
// (which was available immediately, but not enough information) with more information that we obtain via ImageIO.
// This takes a little longer, but since it only done laziy for those object that are actually visible it's fine.
// Please note that this method may be called on a background thread...
// NOTE: This method will only provide metadata surpassing preliminaryMetadata if the object's URL is already accessible.

- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSDictionary* metadata = inObject.preliminaryMetadata;
	
    // If the master resource resides in a not yet entitled location (e.g. on an additional storage device)
    // we do not query it for extra metadata thus not prompting the user for granting even more entitlements
    // which also involved the need to chose an appropriate to be entitled directory carefully.
    
	if ([inObject.URL imb_accessibility] == kIMBResourceIsAccessible &&
        [inObject isKindOfClass:[IMBLightroomObject class]])
	{
		IMBLightroomObject* object = (IMBLightroomObject*)inObject;
        
        NSMutableDictionary *mutableMetadata = [NSMutableDictionary dictionaryWithDictionary:object.preliminaryMetadata];
        [mutableMetadata addEntriesFromDictionary:[NSImage imb_metadataFromImageAtURL:object.URL checkSpotlightComments:NO]];
        metadata = (NSDictionary*)mutableMetadata;
	}

	return metadata;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSData* jpegData = [self previewDataForObject:inObject maximumSize:nil];

	if (jpegData != nil) {
		IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
		NSString* orientation = [[lightroomObject preliminaryMetadata] objectForKey:@"orientation"];;
		NSString* fileName = [[inObject.location lastPathComponent] stringByDeletingPathExtension];
        NSFileManager *fileManager = [[NSFileManager alloc] init];
		NSString* jpegPath = [[fileManager imb_uniqueTemporaryFile:fileName] stringByAppendingPathExtension:@"jpg"];
        [fileManager release];
		NSURL* jpegURL = [NSURL fileURLWithPath:jpegPath];
		BOOL success = NO;
		
		if ((orientation == nil) || [orientation isEqual:@"AB"]) {
			success = [jpegData writeToFile:jpegPath atomically:YES];
		}
		else {
			CGImageSourceRef jpegSource = CGImageSourceCreateWithData((CFDataRef)jpegData, NULL);
			
			if (jpegSource != NULL) {
				CGImageRef jpegImage = CGImageSourceCreateImageAtIndex(jpegSource, 0, NULL);
				
				if (jpegImage != NULL) {
					CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)jpegURL, (CFStringRef)@"public.jpeg", 1, nil);
					
					if (destination != NULL) {
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
						
						NSDictionary* metadata = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:orientationProperty]
																			 forKey:((NSString*)kCGImagePropertyOrientation)];
						CGImageDestinationAddImage(destination, jpegImage, (CFDictionaryRef)metadata);
						
						success = CGImageDestinationFinalize(destination);
						
						CFRelease(destination);
					}
					
					CGImageRelease(jpegImage);
				}
				
				CFRelease(jpegSource);
			}
		}
		
		if (success) {
			NSError* error = nil;
			NSData* bookmark = nil;
			
			bookmark = [jpegURL 
						bookmarkDataWithOptions:0 //options
						includingResourceValuesForKeys:nil
						relativeToURL:nil
						error:&error];
			
			if (outError != NULL) {
				*outError = error;
			}
			
			return bookmark;
		}
	}
	
	return [self bookmarkForLocalFileObject:inObject error:outError];
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
	
	NSMutableArray* subnodes = [inFoldersNode mutableArrayForPopulatingSubnodes];
	NSMutableArray* objects = [NSMutableArray array];
	inFoldersNode.displayedObjectCount = 0;
	
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
			
			IMBNode* node = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
			node.name = name;
			node.icon = [self folderIcon];
			node.identifier = [self identifierWithFolderId:id_local];
			node.attributes = [self attributesWithRootFolder:id_local
													 idLocal:id_local
													rootPath:path
												pathFromRoot:nil
                                                    nodeType:IMBLightroomNodeTypeFolder];
			node.isLeafNode = NO;
			
			[subnodes addObject:node];
			
			IMBFolderObject* object = [[[IMBFolderObject alloc] init] autorelease];
			object.representedNodeIdentifier = node.identifier;
			object.name = name;
			object.metadata = nil;
			object.parserIdentifier = self.identifier;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];
			
			[objects addObject:object];
			
			[pool drain];
		}
		
		[results close];
	}
	
	inFoldersNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


// This method creates subnodes for folders deeper into the hierarchy. Please note that here the SQL query is different
// from the previous method. We are no longer selecting from AgLibraryRootFolder, but from AgLibraryFolder instead...

- (void) populateSubnodesForFolderNode:(IMBNode*)inParentNode
{
	// Add subnodes array, even if nothing is found in database, so that we do not cause endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
	NSMutableArray* objects = [NSMutableArray array];
	inParentNode.displayedObjectCount = 0;
	
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
				node = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
				
				node.icon = [self folderIcon];
				node.name = [pathFromRoot lastPathComponent];
				node.isLeafNode = NO;

				node.identifier = [self identifierWithFolderId:id_local];
				
				[subnodes addObject:node];
			
				NSDictionary* attributes = [self attributesWithRootFolder:parentRootFolder
																  idLocal:id_local
																 rootPath:parentRootPath
															 pathFromRoot:pathFromRoot
                                                                 nodeType:IMBLightroomNodeTypeFolder];

				node.attributes = attributes;
				
				NSString* path = [self absolutePathFromAttributes:attributes];
				
				IMBFolderObject* object = [[[IMBFolderObject alloc] init] autorelease];
				object.representedNodeIdentifier = node.identifier;
				object.name = node.name;
				object.metadata = nil;
				object.parserIdentifier = self.identifier;
				object.index = index++;
				object.imageLocation = (id)self.mediaSource;
				object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
				object.imageRepresentation = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];

				[objects addObject:object];
			}
		}
		[results close];
	}
	
	inParentNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


// This method Collection subnodes for the specified parent node. Even though the query returns all Collections,
// only create nodes that are immediate children of our parent node. This is necessary, because the returned 
// results from the query are not ordered in a way that would let us build the whole node tree in one single
// step...

- (void) populateSubnodesForCollectionNode:(IMBNode*)inParentNode 
{
	// Add an empty subnodes array, to avoid endless loop, even if the following query returns no results...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
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
			
			IMBNode* node = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
			node.identifier = [self identifierWithCollectionId:idLocal];
			node.name = name;
			node.icon = isGroup ? [self groupIcon] : [self collectionIcon];
			node.attributes = [self attributesWithRootFolder:nil
													 idLocal:idLocal
													rootPath:nil
												pathFromRoot:nil
                                                    nodeType:IMBLightroomNodeTypeCollection];

			node.isLeafNode = NO;
			
			[subnodes addObject:node];
			
			IMBFolderObject* object = [[[IMBFolderObject alloc] init] autorelease];
			object.representedNodeIdentifier = node.identifier;
			object.name = node.name;
			object.metadata = nil;
			object.parserIdentifier = self.identifier;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = [self largeFolderIcon];
			
			[objects addObject:object];
		}
		
		[results close];
	}
	
	inParentNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) largeFolderIcon
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
		NSString* query = [self folderObjectsQuery];
		
		NSDictionary* attributes = inNode.attributes;
		NSString* folderPath = [self absolutePathFromAttributes:attributes];
		NSNumber* folderId = [self idLocalFromAttributes:attributes];
		FMResultSet* results = [database executeQuery:query, folderId, folderId];
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


// This method populates an existing folder node with objects (image files). The essential part is id_local stored
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
	object.location = [NSURL fileURLWithPath:inPath]; // Only setting location for the need of deriving identifiers
	object.name = inName;
	object.preliminaryMetadata = inMetadata;	// This metadata was in the XML file and is available immediately
	object.metadata = nil;						// Build lazily when needed (takes longer)
	object.metadataDescription = nil;			// Build lazily when needed (takes longer)
	object.parserIdentifier = self.identifier;
	object.index = inIndex;
	object.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
	object.imageRepresentation = nil;
    object.accessibility = [self accessibilityForObject:object];
	
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


#pragma mark 
#pragma mark Database Access


// Returns the name of the libary...

- (NSString*) libraryName
{
	NSString* path = [self.mediaSource path];
	NSString* name = [[path lastPathComponent] stringByDeletingPathExtension];
	return name;
}


// Return a database object for our library...

- (FMDatabase*) libraryDatabase
{
	NSString* databasePath = [self.mediaSource path];
	FMDatabase* database = [FMDatabase databaseWithPath:databasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*) previewsDatabase
{
	NSString* databasePath = [self.mediaSource path];
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

// Get object's resource current accessibility status

- (IMBResourceAccessibility) accessibilityForObject:(IMBObject*)inObject
{
    NSURL* pyramidPathURL = [NSURL fileURLWithPath:((IMBLightroomObject*)inObject).absolutePyramidPath];
    return [pyramidPathURL imb_accessibility];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Node Identifiers


// The root node always has the hardcoded idLocal 0...

- (NSString*) rootNodeIdentifier
{
	NSString* libraryPath = [self.mediaSource path];
	NSString* libraryName = [self libraryName];
	NSString* path = [NSString stringWithFormat:@"/%@(%lu)",libraryName,(unsigned long)[libraryPath hash]];
	return [self identifierForPath:path];
}


// Create an unique identifier from the idLocal. An example is "IMBLightroomParser://Peter(123)/folder/17"...

- (NSString*) pathPrefixWithType:(NSString*)type
{
	NSString* libraryPath = [self.mediaSource path];
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


// Node types...

- (BOOL) isFolderNode:(IMBNode*)inNode
{
    NSDictionary* attributes = inNode.attributes;
    IMBLightroomNodeType nodeType = [self nodeTypeFromAttributes:attributes];
    
    return (nodeType == IMBLightroomNodeTypeFolder);
}


- (BOOL) isCollectionNode:(IMBNode*)inNode
{
    NSDictionary* attributes = inNode.attributes;
    IMBLightroomNodeType nodeType = [self nodeTypeFromAttributes:attributes];
    
    return (nodeType == IMBLightroomNodeTypeCollection);
}

- (BOOL) isRootCollectionNode:(IMBNode*)inNode
{
    NSDictionary* attributes = inNode.attributes;
    IMBLightroomNodeType nodeType = [self nodeTypeFromAttributes:attributes];
    
    return (nodeType == IMBLightroomNodeTypeRootCollection);
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


#pragma mark 
#pragma mark Object Identifiers

// Identifier must account for "virtual copies" of original resources in Lightroom

- (NSString*) identifierForObject:(IMBObject*)inObject
{
	NSString* identifier = [super identifierForObject:inObject];
	
	if ([inObject isKindOfClass:[IMBLightroomObject class]])
	{
		NSNumber* idLocal = [(IMBLightroomObject*)inObject idLocal];
		identifier = [NSString stringWithFormat:@"%@/%@",identifier,idLocal];
	}
	
	return identifier;
}


// Identifier must account for "virtual copies" of original resources in Lightroom

- (NSString *)persistentResourceIdentifierForObject:(IMBObject *)inObject
{
	NSString* identifier = [super persistentResourceIdentifierForObject:inObject];
	
	if ([inObject isKindOfClass:[IMBLightroomObject class]])
	{
		NSNumber* idLocal = [(IMBLightroomObject*)inObject idLocal];
		identifier = [NSString stringWithFormat:@"%@/%@",identifier,idLocal];
	}
	
	return identifier;
}


//----------------------------------------------------------------------------------------------------------------------

/*
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
*/

@end
