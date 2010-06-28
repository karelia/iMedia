/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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

#import "iMBLightroomPhotosParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "iMBParserController.h"

#import "CIImage+iMedia.h"
#import "NSImage+iMedia.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"


@interface iMBLightroomPhotosParser (Private)

- (iMBLibraryNode *)parseOneDatabaseWithPath:(NSString*)path intoLibraryNode:(iMBLibraryNode *)root version:(int)lightroom_version;
- (iMBLibraryNode *)parseAllImagesForRoot:(iMBLibraryNode*)root version:(int)lightroom_version;
- (iMBLibraryNode *)parseCollectionsForRoot:(iMBLibraryNode*)root version:(int)lightroom_version;
- (iMBLibraryNode*)parseFoldersForRoot:(iMBLibraryNode*)root version:(int)lightroom_version;

- (iMBLibraryNode*)nodeWithLocalID:(NSNumber*)idLocal inDictionary:(NSMutableDictionary*)dictionary;
- (iMBLibraryNode*)nodeWithPath:(NSString*)path inDictionary:(NSMutableDictionary*)dictionary;

+ (NSArray *)libraryPathsV3;
+ (NSArray *)libraryPathsV2;
+ (NSArray *)libraryPathsV1;
+ (void)parseRecentLibrariesList:(NSString *)recentLibrariesList into:(NSMutableArray *)libraryFilePaths;

+ (NSString*)cachePath;

@end


@interface NSData (IndexExtensions)

- (unsigned)lastIndexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength;
- (unsigned)indexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength;
- (unsigned)indexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength options:(int)mask;
- (unsigned)indexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength options:(int)mask range:(NSRange)searchRange;

@end


@implementation iMBLightroomPhotosParser

#pragma mark -
#pragma mark Initialization

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	[iMediaConfiguration registerParser:[self class] forMediaType:@"photos"];
    
	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:nil])
	{
	}
	
	return self;
}

#pragma mark -
#pragma mark instance methods

- (void)populateLibraryNode:(iMBLibraryNode *)rootLibraryNode name:(NSString *)name databasePath:(NSString *)databasePath
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    int lightroom_version = [[rootLibraryNode attributeForKey:@"LightroomVersion"] intValue];

    [self parseOneDatabaseWithPath:databasePath intoLibraryNode:rootLibraryNode version:lightroom_version];

    [pool release];
}

- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate
{
    NSMutableArray *libraryNodes = [NSMutableArray array];

    NSEnumerator *enumerator;
	NSString *currentPath;
    
	NSArray *libraryPathsV3 = [iMBLightroomPhotosParser libraryPathsV3];
	enumerator = [libraryPathsV3 objectEnumerator];
	while ((currentPath = [enumerator nextObject]) != nil)
    {
		NSString *name = LocalizedStringInIMedia(@"Lightroom 3", @"Lightroom");
        if ([libraryPathsV3 count] > 1)
            name = [name stringByAppendingFormat:@" (%@)", [[currentPath stringByDeletingLastPathComponent] lastPathComponent]];
        NSString *iconName = @"com.adobe.Lightroom3:";
        iMBLibraryNode *libraryNode = [self parseDatabaseInThread:currentPath gate:gate name:name iconName:iconName icon:NULL];
        [libraryNode setAttribute:[NSNumber numberWithInt:3] forKey:@"LightroomVersion"];
        if (libraryNode != NULL)
        {
			[libraryNode setWatchedPath:currentPath];
			[libraryNode setPrioritySortOrder:3];
            [libraryNodes addObject:libraryNode];
        }
    }
	
    NSArray *libraryPathsV2 = [iMBLightroomPhotosParser libraryPathsV2];
	enumerator = [libraryPathsV2 objectEnumerator];
	while ((currentPath = [enumerator nextObject]) != nil)
    {
		NSString *name = LocalizedStringInIMedia(@"Lightroom 2", @"Lightroom");
        if ([libraryPathsV2 count] > 1)
            name = [name stringByAppendingFormat:@" (%@)", [[currentPath stringByDeletingLastPathComponent] lastPathComponent]];
        NSString *iconName = @"com.adobe.Lightroom2:";
        iMBLibraryNode *libraryNode = [self parseDatabaseInThread:currentPath gate:gate name:name iconName:iconName icon:NULL];
        [libraryNode setAttribute:[NSNumber numberWithInt:2] forKey:@"LightroomVersion"];
        if (libraryNode != NULL)
        {
			[libraryNode setWatchedPath:currentPath];
			[libraryNode setPrioritySortOrder:2];
            [libraryNodes addObject:libraryNode];
        }
    }
    
    NSArray *libraryPathsV1 = [iMBLightroomPhotosParser libraryPathsV1];
	enumerator = [libraryPathsV1 objectEnumerator];
	while ((currentPath = [enumerator nextObject]) != nil)
    {
		NSString *name = LocalizedStringInIMedia(@"Lightroom", @"Lightroom");
        if ([libraryPathsV1 count] > 1)
            name = [name stringByAppendingFormat:@" (%@)", [[currentPath stringByDeletingLastPathComponent] lastPathComponent]];
        NSString *iconName = @"com.adobe.Lightroom:";
        iMBLibraryNode *libraryNode = [self parseDatabaseInThread:currentPath gate:gate name:name iconName:iconName icon:NULL];
        [libraryNode setAttribute:[NSNumber numberWithInt:1] forKey:@"LightroomVersion"];
        if (libraryNode != NULL)
        {
			[libraryNode setWatchedPath:currentPath];
			[libraryNode setPrioritySortOrder:1];
            [libraryNodes addObject:libraryNode];
        }
    }
	
    return libraryNodes;
}

+ (NSDictionary*)enhancedRecordForRecord:(NSDictionary*)record
{
	NSString *previewPath = [record valueForKey:@"PreviewPath"];
	NSString *pyramidPath = [record valueForKey:@"PyramidPath"];

	if ((previewPath == nil) && (pyramidPath != nil)) {
		iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:@"photos"];
		NSString *nodeIdentifier = [record valueForKey:@"NodeIdentifier"];
		iMBLibraryNode *node = [parserController libraryNodeWithIdentifier:nodeIdentifier];
		iMBLibraryNode *rootNode = [node root];
		NSString *rootPath = [rootNode attributeForKey:@"path"];
		NSString *dataPath = [[[rootPath stringByDeletingPathExtension]
							   stringByAppendingString:@" Previews"]
							  stringByAppendingPathExtension:@"lrdata"];
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		
		BOOL isDirectory;
		if ([fileManager fileExistsAtPath:dataPath isDirectory:&isDirectory] && isDirectory) {
			NSString *originalPath = [record valueForKey:@"OriginalPath"];
			NSDictionary *originalAttributes = [fileManager fileAttributesAtPath:originalPath traverseLink:YES];
			NSDate *originalDate = [originalAttributes objectForKey:NSFileModificationDate];
			
			NSString *cacheFile = [[pyramidPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
			NSString *cachePath = [iMBLightroomPhotosParser cachePath];
			NSString *cacheFilePath = [cachePath stringByAppendingPathComponent:cacheFile];
			NSDictionary *cacheAttributes = [fileManager fileAttributesAtPath:cacheFilePath traverseLink:YES];
			NSDate *cacheDate = [cacheAttributes objectForKey:NSFileModificationDate];

			if ((cacheDate == nil) || ([cacheDate compare:originalDate] == NSOrderedAscending)) {
				NSString *fullPath = [dataPath stringByAppendingPathComponent:pyramidPath];
				NSData *data = [NSData dataWithContentsOfFile:fullPath];
				const char pattern[3] = { 0xFF, 0xD8, 0xFF };
				unsigned index = [data lastIndexOfBytes:pattern length:3];
				
				if (index != NSNotFound) {
					NSEnumerator *pathComponents = [[[cacheFile stringByDeletingLastPathComponent] pathComponents] objectEnumerator];
					NSString *tmpPath = cachePath;
					NSString *tmpComponent = nil;
					
					while ((tmpComponent = [pathComponents nextObject]) != nil) {
						tmpPath = [tmpPath stringByAppendingPathComponent:tmpComponent];
						
						if (![fileManager fileExistsAtPath:tmpPath]) {
							[fileManager createDirectoryAtPath:tmpPath attributes:nil];
						}
					}
					
					NSData *jpgData = [data subdataWithRange:NSMakeRange(index, [data length] - index)];
					BOOL success = [jpgData writeToFile:cacheFilePath atomically:YES];

					if (success) {
						previewPath = cacheFilePath;
					}
				}
			}
			else {
				previewPath = cacheFilePath;
			}
		}
	}
	
	if (previewPath != nil) {
		NSMutableDictionary *enhancedRecord = [NSMutableDictionary dictionaryWithDictionary:record];
		
		[enhancedRecord setObject:previewPath forKey:@"PreviewPath"];
		
		return enhancedRecord;
	}
	
	return record;
}

@end

					
@implementation iMBLightroomPhotosParser (Private)

- (iMBLibraryNode *)parseOneDatabaseWithPath:(NSString*)path intoLibraryNode:(iMBLibraryNode *)root version:(int)lightroom_version
{
	BOOL isReadable = [[NSFileManager defaultManager] isReadableFileAtPath:path];
	
	if (isReadable) {
		[root fromThreadSetAttribute:[NSNumber numberWithLong:0] forKey:@"idLocal"];
		[root fromThreadSetAttribute:path forKey:@"path"];
		[root fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
		
		@try {
			if (lightroom_version >= 2) {
				[self parseFoldersForRoot:root version:lightroom_version];
			}
			else {
				[self parseAllImagesForRoot:root version:lightroom_version];
			}
			
			[self parseCollectionsForRoot:root version:lightroom_version];
		}
		@catch (NSException *exception) {
			NSLog(@"Failed to parse %@: %@", path, exception);
		}
		
		return root;
	}	
	
	return nil;
}

- (iMBLibraryNode*)parseCollectionsForRoot:(iMBLibraryNode*)root version:(int)lightroom_version
{
	NSMutableDictionary *nodesById = [NSMutableDictionary dictionary];
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
	NSString *path = [root attributeForKey:@"path"];
	FMDatabase *database = [FMDatabase databaseWithPath:path];
	
	if ([database open]) {
		NSString* collectionQuery = nil;
		
		if (lightroom_version < 3) {
			collectionQuery = 	@" SELECT alt.id_local, alt.parent, alt.name"
								@" FROM AgLibraryTag alt"
								@" WHERE kindName = 'AgCollectionTagKind'"
								@" AND NOT EXISTS ("
								@"	SELECT alc.id_local"
								@"	FROM AgLibraryContent alc"
								@"	WHERE alt.id_local = alc.containingTag"
								@"	AND alc.owningModule = 'ag.library.smart_collection')";
		}
		else {
			collectionQuery =	@" SELECT alc.id_local, alc.parent, alc.name"
								@" FROM AgLibraryCollection alc"
								@" WHERE creationId = 'com.adobe.ag.library.collection'";
		}

		FMResultSet *rsCollections = [database executeQuery:collectionQuery];
		
		while ([rsCollections next]) {
			NSNumber *idLocal = [NSNumber numberWithLong:[rsCollections longForColumn:@"id_local"]]; 
			NSNumber *idParentLocal = [NSNumber numberWithLong:[rsCollections longForColumn:@"parent"]];
			NSString *name = [rsCollections stringForColumn:@"name"];
			
			if (name == nil) {
				if ([idParentLocal intValue] == 0) {
					name = LocalizedStringInIMedia(@"Collections", @"Collections");
				}
				else {
					name = LocalizedStringInIMedia(@"Unnamed", @"Unnamed");
				}
			}
			
			iMBLibraryNode *currentNode = [self nodeWithLocalID:idLocal inDictionary:nodesById];
			
            // after this point, all accesses to currentNode need to be thread safe (i.e. happen on the main thread)
			
			[currentNode fromThreadSetAttribute:idLocal forKey:@"idLocal"];
			[currentNode fromThreadSetAttribute:idParentLocal forKey:@"idParentLocal"];
			[currentNode fromThreadSetAttribute:name forKey:@"name"];
			[currentNode fromThreadSetAttribute:name forKey:@"identifier"];
			[currentNode fromThreadSetAttribute:NSStringFromClass([self class]) forKey:@"parserClassName"];
//			[currentNode fromThreadSetAttribute:myDatabase forKey:@"watchedPath"];
			
			[currentNode fromThreadSetName:name];
			[currentNode fromThreadSetIcon:[NSImage genericFolderIcon]];
			[currentNode fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
			
			iMBLibraryNode *parentNode;
			
			if ([idParentLocal intValue] == 0) {
				parentNode = root;
			}
			else {
				parentNode = [self nodeWithLocalID:idParentLocal inDictionary:nodesById];
			}
			
			[parentNode fromThreadAddItem:currentNode];
			
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			FMDatabase *localDatabase = [FMDatabase databaseWithPath:path];
			
			if ([localDatabase open]) {
				NSMutableArray *images = [NSMutableArray array];				
				NSMutableString *imageQuery = [NSMutableString string];
                
                if (lightroom_version == 1) {
                    [imageQuery appendString:@" SELECT aif.absolutePath, aif.idx_filename, captionName, apcp.relativeDataPath pyramidPath"];
                    [imageQuery appendString:@" FROM Adobe_imageFiles aif"];
                    [imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryTagImage alti ON ai.id_local = alti.image"];
                    [imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
                    [imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
                    [imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
                    [imageQuery appendString:@" 		   WHERE altiCaption.tagKind = 'AgCollectionTagKind') ON ai.id_local = captionImage"];
                    [imageQuery appendString:@" LEFT JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"];
                    [imageQuery appendString:@" WHERE "];
                    [imageQuery appendString:@" alti.tag = ?"];
					[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
               }
                else if (lightroom_version == 2) {
                    [imageQuery appendString:@" SELECT	arf.absolutePath, alf.pathFromRoot, aif.idx_filename,"];
					[imageQuery appendString:@"			captionName, apcp.relativeDataPath pyramidPath"];
                    [imageQuery appendString:@" FROM AgLibraryFile aif"];
                    [imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryTagImage alti ON ai.id_local = alti.image"];
                    [imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
                    [imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
                    [imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
                    [imageQuery appendString:@" 		   WHERE altiCaption.tagKind = 'AgCollectionTagKind') ON ai.id_local = captionImage"];
                    [imageQuery appendString:@" LEFT JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"];
                    [imageQuery appendString:@" WHERE "];
                    [imageQuery appendString:@" alti.tag = ?"];
                    [imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
                }
                else if (lightroom_version == 3) {
					[imageQuery appendString:@" SELECT	arf.absolutePath, alf.pathFromRoot, aif.idx_filename,"];
                    [imageQuery appendString:@"			ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation,"];
					[imageQuery appendString:@"			iptc.caption captionName,"];
					[imageQuery appendString:@"			aif.id_global uuid, ids.digest"];
					[imageQuery appendString:@" FROM AgLibraryFile aif"];
					[imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
					[imageQuery appendString:@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"];
					[imageQuery appendString:@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"];
					[imageQuery appendString:@" INNER JOIN AgLibraryCollectionImage alci ON ai.id_local = alci.image"];
					[imageQuery appendString:@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"];
					[imageQuery appendString:@" LEFT JOIN Adobe_imageDevelopSettings ids on ids.image = ai.id_local"];
					[imageQuery appendString:@" WHERE alci.collection = ?"];
					[imageQuery appendString:@" AND ai.fileFormat <> 'VIDEO'"];
					[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
                }

				FMResultSet *rsImages = [localDatabase executeQuery:imageQuery, idLocal];
				
				while ([rsImages next]) {
                    NSString *absolutePath = nil;
					
                    if (lightroom_version == 1) {
                        absolutePath = [rsImages stringForColumn:@"absolutePath"];
                    }
                    else {
                        NSString *absoluteRootPath = [rsImages stringForColumn:@"absolutePath"];
                        NSString *pathFromRoot = [rsImages stringForColumn:@"pathFromRoot"];
                        NSString *filename = [rsImages stringForColumn:@"idx_filename"];
						
                        absolutePath = [[absoluteRootPath stringByAppendingString:pathFromRoot] stringByAppendingString:filename];
                    }
                    
					if ([CIImage isReadableFile:absolutePath]) {
						NSMutableDictionary *imageRecord = [NSMutableDictionary dictionary];
						
						// Issue 68: ImagePath should point to a preview extracted from Previews.lrdata
						[imageRecord setObject:absolutePath forKey:@"ImagePath"];
						
						[imageRecord setObject:absolutePath forKey:@"OriginalPath"];
						
						NSString *caption = [rsImages stringForColumn:@"captionName"];
						
						if (caption != nil) {
							[imageRecord setObject:caption forKey:@"Caption"];
						}
						else {
							NSString *fileName = [rsImages stringForColumn:@"idx_filename"];
							
							[imageRecord setObject:fileName forKey:@"Caption"];
						}
						
						if (lightroom_version < 3) {
							NSString *pyramidPath = [rsImages stringForColumn:@"pyramidPath"];

							if (pyramidPath != nil) {
								[imageRecord setObject:pyramidPath forKey:@"PyramidPath"];
							}
						}
						else {
							NSString *uuid = [rsImages stringForColumn:@"uuid"];
							NSString *digest = [rsImages stringForColumn:@"digest"];

							if ((uuid != nil) && (digest != nil)) {
								NSString *prefixOne = [uuid substringToIndex:1];
								NSString *prefixFour = [uuid substringToIndex:4];
								NSString *fileName = [[NSString stringWithFormat:@"%@-%@", uuid, digest] stringByAppendingPathExtension:@"lrprev"];
								NSString *pyramidPath =[[prefixOne stringByAppendingPathComponent:prefixFour] stringByAppendingPathComponent:fileName];
						
								if (pyramidPath != nil) {
									[imageRecord setObject:pyramidPath forKey:@"PyramidPath"];
								}
							}
						}

                        [images addObject:imageRecord];
					}
				}
				
				[currentNode fromThreadSetAttribute:images forKey:@"Images"];
				
				[rsImages close];
			}
			
			[localDatabase close];
			[innerPool release];
		}
		
		[rsCollections close];
	}
	
	[database close];
	[outerPool release];

	return root;
}

- (iMBLibraryNode*)nodeWithLocalID:(NSNumber*)idLocal inDictionary:(NSMutableDictionary*)dictionary
{	
	iMBLibraryNode *node = [dictionary objectForKey:idLocal];
	
	if (node == nil) {
		node = [[[iMBLibraryNode alloc] init] autorelease];
		
		[dictionary setObject:node forKey:idLocal];
	}
	
	return node;
}

- (iMBLibraryNode*)parseFoldersForRoot:(iMBLibraryNode*)root version:(int)lightroom_version 
{
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
	NSString *path = [root attributeForKey:@"path"];
	FMDatabase *database = [FMDatabase databaseWithPath:path];
	
	if ([database open]) {
		NSNumber *foldersRootNodeID = [NSNumber numberWithInt:-1];
		NSString *foldersRootName = LocalizedStringInIMedia(@"Folders", @"Folders");
		iMBLibraryNode *foldersRootNode = [[[iMBLibraryNode alloc] init] autorelease];
		
		[foldersRootNode fromThreadSetAttribute:foldersRootNodeID forKey:@"idLocal"];
		[foldersRootNode fromThreadSetAttribute:foldersRootName forKey:@"name"];
		[foldersRootNode fromThreadSetAttribute:foldersRootName forKey:@"identifier"];
		[foldersRootNode fromThreadSetAttribute:NSStringFromClass([self class]) forKey:@"parserClassName"];
		
		[foldersRootNode fromThreadSetName:foldersRootName];
		[foldersRootNode fromThreadSetIcon:[NSImage genericFolderIcon]];
		[foldersRootNode fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
		
		[root fromThreadAddItem:foldersRootNode];

		NSMutableString *rootFoldersQuery = [NSMutableString stringWithString:@"SELECT id_local, absolutePath, name"];
		
		[rootFoldersQuery appendString:@" FROM "];
		[rootFoldersQuery appendString:@"AgLibraryRootFolder"];
		[rootFoldersQuery appendString:@" ORDER BY name ASC"];
		
		FMResultSet *rsRootFolders = [database executeQuery:rootFoldersQuery];
		
		while ([rsRootFolders next]) {
			NSNumber *rootFolderID = [NSNumber numberWithLong:[rsRootFolders longForColumn:@"id_local"]];
			NSString *absolutePath = [rsRootFolders stringForColumn:@"absolutePath"];
			NSString *rootFolderName = [rsRootFolders stringForColumn:@"name"];
			
			if (rootFolderName == nil) {
				rootFolderName = LocalizedStringInIMedia(@"Unnamed", @"Unnamed");
			}
			
			iMBLibraryNode *rootFolderNode = [[[iMBLibraryNode alloc] init] autorelease];
			
            // after this point, all accesses to currentNode need to be thread safe (i.e. happen on the main thread)
			
			[rootFolderNode fromThreadSetAttribute:rootFolderID forKey:@"idLocal"];
			[rootFolderNode fromThreadSetAttribute:rootFolderName forKey:@"name"];
			[rootFolderNode fromThreadSetAttribute:rootFolderName forKey:@"identifier"];
			[rootFolderNode fromThreadSetAttribute:NSStringFromClass([self class]) forKey:@"parserClassName"];
			
			[rootFolderNode fromThreadSetName:rootFolderName];
			[rootFolderNode fromThreadSetIcon:[NSImage genericFolderIcon]];
			[rootFolderNode fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
									
			[foldersRootNode fromThreadAddItem:rootFolderNode];
			
			NSAutoreleasePool *rootFolderPool = [[NSAutoreleasePool alloc] init];
			FMDatabase *rootFolderDatabase = [FMDatabase databaseWithPath:path];
			
			if ([rootFolderDatabase open]) {
				NSMutableDictionary *folders = [NSMutableDictionary dictionary];				
				NSMutableString *foldersQuery = [NSMutableString stringWithString:@"SELECT id_local, pathFromRoot"];
				
				[foldersQuery appendString:@" FROM "];
				[foldersQuery appendString:@"AgLibraryFolder"];
				[foldersQuery appendString:@" WHERE rootFolder = ?"];
				[foldersQuery appendString:@" ORDER BY pathFromRoot ASC"];
				
				FMResultSet *rsFolders = [rootFolderDatabase executeQuery:foldersQuery, rootFolderID];
				
				while ([rsFolders next]) {
					NSNumber *folderID = [NSNumber numberWithLong:[rsFolders longForColumn:@"id_local"]];
					NSString *pathFromRoot = [rsFolders stringForColumn:@"pathFromRoot"];
					
					if ([pathFromRoot hasSuffix:@"/"]) {
						pathFromRoot = [pathFromRoot substringToIndex:([pathFromRoot length] - 1)];
					}
					
					NSString *parentPath = [pathFromRoot stringByDeletingLastPathComponent];
					NSString *folderName = [pathFromRoot lastPathComponent];
					
					if ([folderName length] == 0) {
						folderName = LocalizedStringInIMedia(@"Unfiled", @"Unfiled");
					}
					
					iMBLibraryNode *parentNode = nil;
					
					if ([parentPath length] > 0) {
						parentNode = [self nodeWithPath:parentPath inDictionary:folders];
					}
					
					if (parentNode == nil) {
						parentNode = rootFolderNode;
					}

					iMBLibraryNode *folderNode = [self nodeWithPath:pathFromRoot inDictionary:folders];
					
					// after this point, all accesses to currentNode need to be thread safe (i.e. happen on the main thread)
					
					[folderNode fromThreadSetAttribute:folderID forKey:@"idLocal"];
					[folderNode fromThreadSetAttribute:folderName forKey:@"name"];
					[folderNode fromThreadSetAttribute:folderName forKey:@"identifier"];
					[folderNode fromThreadSetAttribute:NSStringFromClass([self class]) forKey:@"parserClassName"];
					
					[folderNode fromThreadSetName:folderName];
					[folderNode fromThreadSetIcon:[NSImage genericFolderIcon]];
					[folderNode fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
					
					[parentNode fromThreadAddItem:folderNode];
					
					NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
					FMDatabase *localDatabase = [FMDatabase databaseWithPath:path];
					
					if ([localDatabase open]) {
						NSMutableArray *images = [NSMutableArray array];				
						NSMutableString *imageQuery = [NSMutableString string];
						
						if (lightroom_version < 3) {
							[imageQuery appendString:@" SELECT alf.idx_filename, captionName, apcp.relativeDataPath pyramidPath"];
							[imageQuery appendString:@" FROM AgLibraryFile alf"];
							[imageQuery appendString:@" INNER JOIN Adobe_images ai ON alf.id_local = ai.rootFile"];
							[imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
							[imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
							[imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
							[imageQuery appendString:@" 		   WHERE altiCaption.tagKind = 'AgCaptionTagKind') ON ai.id_local = captionImage"];
							[imageQuery appendString:@" LEFT JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"];
							[imageQuery appendString:@" WHERE "];
							[imageQuery appendString:@" alf.folder = ?"];
							[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
							}
						else {
							[imageQuery appendString:@" SELECT	alf.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation,"];
							[imageQuery appendString:@"			iptc.caption captionName,"];
							[imageQuery appendString:@"			alf.id_global uuid, ids.digest"];
							[imageQuery appendString:@" FROM AgLibraryFile alf"];
							[imageQuery appendString:@" INNER JOIN Adobe_images ai ON alf.id_local = ai.rootFile"];
							[imageQuery appendString:@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"];
							[imageQuery appendString:@" LEFT JOIN Adobe_imageDevelopSettings ids on ids.image = ai.id_local"];
							[imageQuery appendString:@" WHERE alf.folder = ?"];
							[imageQuery appendString:@" AND ai.fileFormat <> 'VIDEO'"];
							[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
						}
						
						FMResultSet *rsImages = [localDatabase executeQuery:imageQuery, folderID];
						
						while ([rsImages next]) {
							NSString *filename = [rsImages stringForColumn:@"idx_filename"];
							NSString *absoluteFilePath = [[absolutePath stringByAppendingPathComponent:pathFromRoot] stringByAppendingPathComponent:filename];
							
							if ([CIImage isReadableFile:absoluteFilePath]) {
								NSMutableDictionary *imageRecord = [NSMutableDictionary dictionary];
								
								[imageRecord setObject:absoluteFilePath forKey:@"ImagePath"];
								[imageRecord setObject:absoluteFilePath forKey:@"OriginalPath"];
								
								NSString *caption = [rsImages stringForColumn:@"captionName"];
								
								if (caption != nil) {
									[imageRecord setObject:caption forKey:@"Caption"];
								}
								else {									
									[imageRecord setObject:filename forKey:@"Caption"];
								}
								
								if (lightroom_version < 3) {
									NSString *pyramidPath = [rsImages stringForColumn:@"pyramidPath"];
									
									if (pyramidPath != nil) {
										[imageRecord setObject:pyramidPath forKey:@"PyramidPath"];
									}
								}
								else {
									NSString *uuid = [rsImages stringForColumn:@"uuid"];
									NSString *digest = [rsImages stringForColumn:@"digest"];
									
									if ((uuid != nil) && (digest != nil)) {
										NSString *prefixOne = [uuid substringToIndex:1];
										NSString *prefixFour = [uuid substringToIndex:4];
										NSString *fileName = [[NSString stringWithFormat:@"%@-%@", uuid, digest] stringByAppendingPathExtension:@"lrprev"];
										NSString *pyramidPath =[[prefixOne stringByAppendingPathComponent:prefixFour] stringByAppendingPathComponent:fileName];
										
										if (pyramidPath != nil) {
											[imageRecord setObject:pyramidPath forKey:@"PyramidPath"];
										}
									}
								}
								
								[images addObject:imageRecord];
							}
						}
						
						[folderNode fromThreadSetAttribute:images forKey:@"Images"];
												
						[rsImages close];
					}
					
					[localDatabase close];
					[innerPool release];					
				}
				
				[rsFolders close];
			}
			
			[rootFolderDatabase close];
			[rootFolderPool release];
		}
		
		[rsRootFolders close];
	}
	
	[database close];
	[outerPool release];
	
	return root;
}

- (iMBLibraryNode*)nodeWithPath:(NSString*)path inDictionary:(NSMutableDictionary*)dictionary
{
	iMBLibraryNode *node = [dictionary objectForKey:path];
	
	if (node == nil) {
		node = [[[iMBLibraryNode alloc] init] autorelease];
		
		[dictionary setObject:node forKey:path];
	}
	
	return node;
}

- (iMBLibraryNode*)parseAllImagesForRoot:(iMBLibraryNode*)root version:(int)lightroom_version
{		
	iMBLibraryNode *imagesNode = [[[iMBLibraryNode alloc] init] autorelease];	
	
	[imagesNode setAttribute:[NSNumber numberWithInt:-1] forKey:@"idLocal"];
	[imagesNode setName:LocalizedStringInIMedia(@"Images", @"Images")];
	[imagesNode setIcon:[NSImage genericFolderIcon]];
	[imagesNode setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
	[imagesNode setIdentifier:@"Images"];
	[imagesNode setParserClassName:NSStringFromClass([self class])];
//	[imagesNode setWatchedPath:myDatabase];
	
    // after this point, all accesses to imagesNode need to be thread safe (i.e. happen on the main thread)
	[root fromThreadAddItem:imagesNode];
	
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
	NSString *path = [root attributeForKey:@"path"];
	FMDatabase *database = [FMDatabase databaseWithPath:path];
	
	if ([database open]) {
		NSMutableArray *images = [NSMutableArray array];
		NSMutableString *imageQuery = [NSMutableString string];

        if (lightroom_version == 1)
        {
			[imageQuery appendString:@" SELECT aif.absolutePath, aif.idx_filename, captionName, apcp.relativeDataPath pyramidPath"];
			[imageQuery appendString:@" FROM Adobe_imageFiles aif"];
			[imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
			[imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
			[imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
			[imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
			[imageQuery appendString:@" 		   WHERE altiCaption.tagKind = 'AgCaptionTagKind') ON ai.id_local = captionImage"];
			[imageQuery appendString:@" LEFT JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"];
			[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
        }
        else if (lightroom_version == 2)
        {
			[imageQuery appendString:@" SELECT arf.absolutePath, alf.pathFromRoot, aif.idx_filename, captionName, apcp.relativeDataPath pyramidPath"];
			[imageQuery appendString:@" FROM AgLibraryFile aif"];
			[imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
			[imageQuery appendString:@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"];
			[imageQuery appendString:@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"];
			[imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
			[imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
			[imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
			[imageQuery appendString:@" 		   WHERE altiCaption.tagKind = 'AgCaptionTagKind') ON ai.id_local = captionImage"];
			[imageQuery appendString:@" LEFT JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"];
			[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
		}
		
        else if (lightroom_version == 3)
        {
			[imageQuery appendString:@" SELECT	arf.absolutePath, alf.pathFromRoot, aif.idx_filename,"];
			[imageQuery appendString:@"			ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation,"];
			[imageQuery appendString:@"			iptc.caption captionName,"];
			[imageQuery appendString:@"			aif.id_global uuid, ids.digest"];
			[imageQuery appendString:@" FROM AgLibraryFile aif"];
			[imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
			[imageQuery appendString:@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"];
			[imageQuery appendString:@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"];
			[imageQuery appendString:@" INNER JOIN AgLibraryCollectionImage alci ON ai.id_local = alci.image"];
			[imageQuery appendString:@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"];
			[imageQuery appendString:@" LEFT JOIN Adobe_imageDevelopSettings ids on ids.image = ai.id_local"];
			[imageQuery appendString:@" AND ai.fileFormat <> 'VIDEO'"];
			[imageQuery appendString:@" ORDER BY ai.captureTime ASC"];
		}
		
		[database setLogsErrors:YES];
		
		FMResultSet *rsImages = [database executeQuery:imageQuery];

		while ([rsImages next]) {
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
            NSString *absolutePath = NULL;
            if (lightroom_version == 1 )
            {
                absolutePath = [rsImages stringForColumn:@"absolutePath"];
            }
            else if (lightroom_version == 2)
            {
                NSString *absoluteRootPath = [rsImages stringForColumn:@"absolutePath"];
                NSString *pathFromRoot = [rsImages stringForColumn:@"pathFromRoot"];
                NSString *filename = [rsImages stringForColumn:@"idx_filename"];
                absolutePath = [[absoluteRootPath stringByAppendingString:pathFromRoot] stringByAppendingString:filename];
            }

			if ([CIImage isReadableFile:absolutePath]) {
				NSMutableDictionary *imageRecord = [NSMutableDictionary dictionary];
				
				// Issue 68: ImagePath should point to a preview extracted from Previews.lrdata
				[imageRecord setObject:absolutePath forKey:@"ImagePath"];
				
				[imageRecord setObject:absolutePath forKey:@"OriginalPath"];
				
				NSString *caption = nil; //[rsImages stringForColumn:@"captionName"];
				
				if (caption != nil) {
					[imageRecord setObject:caption forKey:@"Caption"];
				}
				else {
					NSString *fileName = [rsImages stringForColumn:@"idx_filename"];
					
					[imageRecord setObject:fileName forKey:@"Caption"];
				}
				
				if (lightroom_version < 3) {
					NSString *pyramidPath = [rsImages stringForColumn:@"pyramidPath"];
					
					if (pyramidPath != nil) {
						[imageRecord setObject:pyramidPath forKey:@"PyramidPath"];
					}
				}
				else {
					NSString *uuid = [rsImages stringForColumn:@"uuid"];
					NSString *digest = [rsImages stringForColumn:@"digest"];
					
					if ((uuid != nil) && (digest != nil)) {
						NSString *prefixOne = [uuid substringToIndex:1];
						NSString *prefixFour = [uuid substringToIndex:4];
						NSString *fileName = [[NSString stringWithFormat:@"%@-%@", uuid, digest] stringByAppendingPathExtension:@"lrprev"];
						NSString *pyramidPath =[[prefixOne stringByAppendingPathComponent:prefixFour] stringByAppendingPathComponent:fileName];
						
						if (pyramidPath != nil) {
							[imageRecord setObject:pyramidPath forKey:@"PyramidPath"];
						}
					}
				}
				
				[images addObject:imageRecord];
			}
			[innerPool release];
		}
		
		[imagesNode fromThreadSetAttribute:images forKey:@"Images"];
		
		[rsImages close];
	}
	
	[database close];
	[outerPool release];
	
	return root;
}

+ (void)parseRecentLibrariesList:(NSString *)recentLibrariesList into:(NSMutableArray *)libraryFilePaths
{
    NSCharacterSet *newlineCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    NSScanner *scanner = [NSScanner scannerWithString:recentLibrariesList];
    
    NSString *path = @"";
    while (![scanner isAtEnd])
    {
        NSString *token;
        if ([scanner scanUpToCharactersFromSet:newlineCharacterSet intoString:&token])
        {
            NSString *string = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if (([string length] == 0) || 
                [string isEqualTo:@"recentLibraries = {"] || 
                [string isEqualTo:@"}"])
            {
                continue;
            }
            
            path = [path stringByAppendingString:string];
            
            if ([path hasSuffix:@"\","])
            {
                [libraryFilePaths addObject:[path substringWithRange:NSMakeRange(1, [path length] - 3)]];
                path = @"";
            }
        }
        
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    }
}

+ (NSArray*)libraryPathsV3
{
	NSMutableArray *libraryFilePaths = [NSMutableArray array];
    
	CFStringRef recentLibrariesList20 = CFPreferencesCopyAppValue((CFStringRef)@"recentLibraries20",
                                                                  (CFStringRef)@"com.adobe.Lightroom3");
	
	if (recentLibrariesList20 != nil) {
        [iMBLightroomPhotosParser parseRecentLibrariesList:(NSString*)recentLibrariesList20 into:libraryFilePaths];
        CFRelease(recentLibrariesList20);
	}
	
    if ([libraryFilePaths count] == 0) {
		CFPropertyListRef activeLibraryPath = CFPreferencesCopyAppValue((CFStringRef)@"libraryToLoad20",
																		(CFStringRef)@"com.adobe.Lightroom3");
		
		if (activeLibraryPath != nil) {
			
			CFRelease(activeLibraryPath);
		}
    }
    
	return libraryFilePaths;
}

+ (NSArray*)libraryPathsV2
{
	NSMutableArray *libraryFilePaths = [NSMutableArray array];
    
	CFStringRef recentLibrariesList20 = CFPreferencesCopyAppValue((CFStringRef)@"recentLibraries20",
                                                                  (CFStringRef)@"com.adobe.Lightroom2");
	
	if (recentLibrariesList20 != nil) {
        [iMBLightroomPhotosParser parseRecentLibrariesList:(NSString*)recentLibrariesList20 into:libraryFilePaths];
        CFRelease(recentLibrariesList20);
	}
	
    if ([libraryFilePaths count] == 0) {
		CFPropertyListRef activeLibraryPath = CFPreferencesCopyAppValue((CFStringRef)@"libraryToLoad20",
																		(CFStringRef)@"com.adobe.Lightroom2");
		
		if (activeLibraryPath != nil) {
			
			CFRelease(activeLibraryPath);
		}
    }
    
	return libraryFilePaths;
}

+ (NSArray*)libraryPathsV1
{
	NSMutableArray *libraryFilePaths = [NSMutableArray array];
    
	CFStringRef recentLibrariesList11 = CFPreferencesCopyAppValue((CFStringRef)@"recentLibraries11",
                                                                  (CFStringRef)@"com.adobe.Lightroom");
	
	if (recentLibrariesList11 != nil) {
        [iMBLightroomPhotosParser parseRecentLibrariesList:(NSString*)recentLibrariesList11 into:libraryFilePaths];
        CFRelease(recentLibrariesList11);
	}
    
	if ([libraryFilePaths count] == 0) {
		CFPropertyListRef activeLibraryPath = CFPreferencesCopyAppValue((CFStringRef)@"AgLibrary_activeLibraryPath11",
																		(CFStringRef)@"com.adobe.Lightroom");
		
		if (activeLibraryPath != nil) {
			
			CFRelease(activeLibraryPath);
		}
	}
    
	return libraryFilePaths;
}

+ (NSString*)cachePath
{
	static NSString *cachePath = nil;
	
	if (cachePath == nil) {
		NSFileManager *fileManager = [NSFileManager defaultManager];

		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		NSString *cacheDirPath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
		NSString *imediaCacheDirPath = [cacheDirPath stringByAppendingPathComponent:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
		
		if (![fileManager fileExistsAtPath:imediaCacheDirPath]) {
			[fileManager createDirectoryAtPath:imediaCacheDirPath attributes:nil];
		}
		
		NSString *parserCacheDirPath = [imediaCacheDirPath stringByAppendingPathComponent:[self className]];
		
		if (![fileManager fileExistsAtPath:parserCacheDirPath]) {
			[fileManager createDirectoryAtPath:parserCacheDirPath attributes:nil];
		}
		
		cachePath = [parserCacheDirPath retain];
	}
	
	return cachePath;
}

@end


@implementation NSData (IndexExtensions)

// Code from NSData_SKExtensions.m
/*
 This software is Copyright (c) 2007-2008
 Christiaan Hofman. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Christiaan Hofman nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

- (unsigned)lastIndexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength
{
    return [self indexOfBytes:patternBytes length:patternLength options:NSBackwardsSearch range:NSMakeRange(0, [self length])];
}

- (unsigned)indexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength
{
    return [self indexOfBytes:patternBytes length:patternLength options:0 range:NSMakeRange(0, [self length])];
}

- (unsigned)indexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength options:(int)mask
{
    return [self indexOfBytes:patternBytes length:patternLength options:mask range:NSMakeRange(0, [self length])];
}

- (unsigned)indexOfBytes:(const void *)patternBytes length:(unsigned int)patternLength options:(int)mask range:(NSRange)searchRange
{
    unsigned int selfLength = [self length];
    if (searchRange.location > selfLength || NSMaxRange(searchRange) > selfLength)
        [NSException raise:NSRangeException format:@"Range {%u,%u} exceeds length %u", searchRange.location, searchRange.length, selfLength];
    
    unsigned const char *selfBufferStart, *selfPtr, *selfPtrEnd, *selfPtrMax;
    unsigned const char firstPatternByte = *(const char *)patternBytes;
    BOOL backward = (mask & NSBackwardsSearch) != 0;
    
    if (patternLength == 0)
        return searchRange.location;
    if (patternLength > searchRange.length) {
        // This test is a nice shortcut, but it's also necessary to avoid crashing: zero-length CFDatas will sometimes(?) return NULL for their bytes pointer, and the resulting pointer arithmetic can underflow.
        return NSNotFound;
    }
    
    selfBufferStart = [self bytes];
    selfPtrMax = selfBufferStart + NSMaxRange(searchRange) + 1 - patternLength;
    if (backward) {
        selfPtr = selfPtrMax - 1;
        selfPtrEnd = selfBufferStart + searchRange.location - 1;
    } else {
        selfPtr = selfBufferStart + searchRange.location;
        selfPtrEnd = selfPtrMax;
    }
    
    for (;;) {
        if (memcmp(selfPtr, patternBytes, patternLength) == 0)
            return (selfPtr - selfBufferStart);
        
        if (backward) {
            do {
                selfPtr--;
            } while (*selfPtr != firstPatternByte && selfPtr > selfPtrEnd);
            if (*selfPtr != firstPatternByte)
                break;
        } else {
            selfPtr++;
            if (selfPtr == selfPtrEnd)
                break;
            selfPtr = memchr(selfPtr, firstPatternByte, (selfPtrMax - selfPtr));
            if (selfPtr == NULL)
                break;
        }
    }
	
    return NSNotFound;
}

@end