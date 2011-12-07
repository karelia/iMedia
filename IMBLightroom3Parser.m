/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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

#import "IMBLightroom3Parser.h"

#import <Quartz/Quartz.h>

#import "FMDatabase.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBObject.h"
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"


@interface IMBLightroom3Parser ()

+ (NSString*)cloneDatabase:(NSString*)databasePath;

- (NSNumber*) databaseVersion;

@end


@implementation IMBLightroom3Parser

//----------------------------------------------------------------------------------------------------------------------


// Check if Lightroom is installed...

+ (NSString*) lightroomPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.adobe.Lightroom3"];
}


// Return an array to Lightroom library files...

+ (NSArray*) libraryPaths
{
	NSMutableArray* libraryPaths = [NSMutableArray array];
    
	CFStringRef recentLibrariesList = CFPreferencesCopyAppValue((CFStringRef)@"recentLibraries20",(CFStringRef)@"com.adobe.Lightroom3");
	
	if (recentLibrariesList) {
        [self parseRecentLibrariesList:(NSString*)recentLibrariesList into:libraryPaths];
        CFRelease(recentLibrariesList);
	}
	
    if ([libraryPaths count] == 0) {
		CFPropertyListRef activeLibraryPath = CFPreferencesCopyAppValue((CFStringRef)@"libraryToLoad20",(CFStringRef)@"com.adobe.Lightroom3");
		
		if (activeLibraryPath) {
			CFRelease(activeLibraryPath);
		}
    }
    
	return libraryPaths;
}

+ (NSArray*) concreteParserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	if ([self isInstalled]) {
		NSArray* libraryPaths = [self libraryPaths];
		
		for (NSString* libraryPath in libraryPaths) {
			NSString* dataPath = [[[libraryPath stringByDeletingPathExtension]
								   stringByAppendingString:@" Previews"]
								  stringByAppendingPathExtension:@"lrdata"];
			NSFileManager* fileManager = [NSFileManager imb_threadSafeManager];
			
			BOOL isDirectory;
			if (!([fileManager fileExistsAtPath:dataPath isDirectory:&isDirectory] && isDirectory)) {
				dataPath = nil;
			}
			
			IMBLightroom3Parser* parser = [[[[self class] alloc] initWithMediaType:inMediaType] autorelease];
			parser.mediaSource = libraryPath;
			parser.dataPath = dataPath;
			parser.shouldDisplayLibraryName = libraryPaths.count > 1;
			
			/*
            // Check database version
            // Commented out because in Sandvox case #159516 it's beachballing. Pierre advises this hack should fix it for now
			NSNumber *databaseVersion = [parser databaseVersion];
			
			if (databaseVersion != nil) {
				long databaseVersionLong = [databaseVersion longValue];
				
				if (databaseVersionLong < 300025) {
					continue;
				}
				else if (databaseVersionLong >= 400000) {
					continue;
				}
			}
			*/
			[parserInstances addObject:parser];
		}
	}
	
	return parserInstances;
}

- (NSNumber*) databaseVersion
{
	FMDatabase *database = [self database];
	NSNumber *databaseVersion = nil;
	
	if (database != nil) {		
		NSString* query =	@" SELECT value"
							@" FROM Adobe_variablesTable avt"
							@" WHERE avt.name = ?"
							@" LIMIT 1";
		
		FMResultSet* results = [database executeQuery:query, @"Adobe_DBVersion"];
		
		if ([results next]) {				
			databaseVersion = [NSNumber numberWithLong:[results longForColumn:@"value"]];
		}
		
		[results close];
	}
	
	return databaseVersion;
}

// This method creates the immediate subnodes of the "Lightroom" root node. The two subnodes are "Folders"  
// and "Collections"...

- (void) populateSubnodesForRootNode:(IMBNode*)inRootNode
{
	NSMutableArray* subNodes = [NSMutableArray array];
	NSMutableArray* objects = [NSMutableArray array];
	inRootNode.displayedObjectCount = 0;
	
	// Add the Folders node...
	
	NSNumber* id_local = [NSNumber numberWithInt:-1];
	
	NSString* foldersName = NSLocalizedStringWithDefaultValue(
															  @"IMBLightroomParser.foldersName",
															  nil,IMBBundle(),
															  @"Folders",
															  @"Name of Folders node in IMBLightroomParser");
	
	IMBNode* foldersNode = [[[IMBNode alloc] init] autorelease];
	foldersNode.mediaSource = self.mediaSource;
	foldersNode.identifier = [self identifierWithFolderId:id_local];
	foldersNode.name = foldersName;
	foldersNode.icon = [self folderIcon];
	foldersNode.parser = self;
	foldersNode.attributes = [self attributesWithRootFolder:id_local
                                                    idLocal:id_local
                                                   rootPath:nil
                                               pathFromRoot:nil
                                                   nodeType:IMBLightroomNodeTypeFolder];
	foldersNode.leaf = NO;
	
	[subNodes addObject:foldersNode];

	IMBNodeObject* foldersObject = [[[IMBNodeObject alloc] init] autorelease];
	foldersObject.representedNodeIdentifier = foldersNode.identifier;
	foldersObject.name = foldersNode.name;
	foldersObject.metadata = nil;
	foldersObject.parser = self;
	foldersObject.index = 0;
	foldersObject.imageLocation = (id)self.mediaSource;
	foldersObject.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
	foldersObject.imageRepresentation = [self largeFolderIcon];
	
	[objects addObject:foldersObject];

	
	// Add the Collections node...
	
	NSString* collectionsName = NSLocalizedStringWithDefaultValue(
																  @"IMBLightroomParser.collectionsName",
																  nil,IMBBundle(),
																  @"Collections",
																  @"Name of Collections node in IMBLightroomParser");
	
	IMBNode* collectionsNode = [[[IMBNode alloc] init] autorelease];
	collectionsNode.identifier = [self identifierWithCollectionId:[NSNumber numberWithLong:0]];
	collectionsNode.name = collectionsName;
	collectionsNode.icon = [self groupIcon];
	collectionsNode.parser = self;
	collectionsNode.leaf = NO;
	
	[subNodes addObject:collectionsNode];
	
	IMBNodeObject* collectionsObject = [[[IMBNodeObject alloc] init] autorelease];
	collectionsObject.representedNodeIdentifier = collectionsNode.identifier;
	collectionsObject.name = collectionsNode.name;
	collectionsObject.metadata = nil;
	collectionsObject.parser = self;
	collectionsObject.index = 1;
	collectionsObject.imageLocation = (id)self.mediaSource;
	collectionsObject.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
	collectionsObject.imageRepresentation = [self largeFolderIcon];
	
	[objects addObject:collectionsObject];
	
	inRootNode.subNodes = subNodes;
	inRootNode.objects = objects;

	[super populateSubnodesForRootNode:collectionsNode];
}


- (NSString*) rootFolderQuery
{
	NSString* query =	@" SELECT id_local, absolutePath, name"
						@" FROM AgLibraryRootFolder"
						@" ORDER BY name ASC";
	
	return query;
}

- (NSString*) folderNodesQuery
{
	NSString* query =	@" SELECT id_local, pathFromRoot"
						@" FROM AgLibraryFolder"
						@" WHERE rootFolder = ?"
						@" AND (pathFromRoot LIKE ? AND NOT (pathFromRoot LIKE ?))"
						@" ORDER BY pathFromRoot ASC";
	
	
	return query;
}

- (NSString*) rootCollectionNodesQuery
{
	NSString* query =	@" SELECT alc.id_local, alc.parent, alc.name"
						@" FROM AgLibraryCollection alc"
						@" WHERE (creationId = 'com.adobe.ag.library.collection' OR creationId = 'com.adobe.ag.library.group') "
						@" AND alc.parent IS NULL";
	
	return query;
}


- (NSString*) collectionNodesQuery
{
	NSString* query =	@" SELECT alc.id_local, alc.parent, alc.name"
						@" FROM AgLibraryCollection alc"
                        @" WHERE (creationId = 'com.adobe.ag.library.collection' OR creationId = 'com.adobe.ag.library.group') "
						@" AND alc.parent = ?";
	
	return query;
}


- (NSString*) folderObjectsQuery
{
	NSString* query =	@" SELECT	alf.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation,"
						@"			iptc.caption"
						@" FROM AgLibraryFile alf"
						@" INNER JOIN Adobe_images ai ON alf.id_local = ai.rootFile"
						@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
						@" WHERE alf.folder in ( "
						@"		SELECT id_local"
						@"		FROM AgLibraryFolder"
						@"		WHERE id_local = ? OR (rootFolder = ? AND (pathFromRoot IS NULL OR pathFromRoot = ''))"
						@" )"
						@" AND ai.fileFormat <> 'VIDEO'"
						@" ORDER BY ai.captureTime ASC";
	
	return query;
}

- (NSString*) collectionObjectsQuery
{
	NSString* query =	@" SELECT	arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
						@"			aif.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation,"
						@"			iptc.caption"
						@" FROM AgLibraryFile aif"
						@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"
						@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
						@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
						@" INNER JOIN AgLibraryCollectionImage alci ON ai.id_local = alci.image"
						@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
						@" WHERE alci.collection = ?"
						@" AND ai.fileFormat <> 'VIDEO'"
						@" ORDER BY ai.captureTime ASC";
	
	return query;
}

- (NSImage*) folderIcon
{
	static NSImage* folderIcon = nil;
	
	if (folderIcon == nil) {
		NSString* pathToOtherApp = [[self class] lightroomPath];
		NSString* pathToModule = [pathToOtherApp stringByAppendingPathComponent:@"Contents/Frameworks/Library.lrmodule"];
		NSString* pathToResources = [pathToModule stringByAppendingPathComponent:@"Contents/Resources"];
		NSString* pathToIcon = [pathToResources stringByAppendingPathComponent:@"icon_folder.png"];
		NSImage* image = [[[NSImage alloc] initByReferencingFile:pathToIcon] autorelease];
		image = [image imb_imageCroppedToRect:NSMakeRect(2,1,19,16)];
		
		if (image == nil) {
			image = [NSImage imb_sharedGenericFolderIcon];
		}
		
		folderIcon = [image copy];
	}
	
	return folderIcon;
}

- (NSImage*) groupIcon;
{
	static NSImage* groupIcon = nil;
	
	if (groupIcon == nil) {
		NSString* pathToOtherApp = [[self class] lightroomPath];
		NSString* pathToModule = [pathToOtherApp stringByAppendingPathComponent:@"Contents/Frameworks/Library.lrmodule"];
		NSString* pathToResources = [pathToModule stringByAppendingPathComponent:@"Contents/Resources"];
		NSString* pathToIcon = [pathToResources stringByAppendingPathComponent:@"groupCreation.png"];
		NSImage* image = [[[NSImage alloc] initByReferencingFile:pathToIcon] autorelease];
		image = [image imb_imageCroppedToRect:NSMakeRect(2,2,19,16)];
		
		if (image == nil) {
			image = [NSImage imb_sharedGenericFolderIcon];
		}
		
		groupIcon = [image copy];
	}
	
	return groupIcon;
}

- (NSImage*) collectionIcon;
{
	static NSImage* collectionIcon = nil;
	
	if (collectionIcon == nil) {
		NSString* pathToOtherApp = [[self class] lightroomPath];
		NSString* pathToModule = [pathToOtherApp stringByAppendingPathComponent:@"Contents/Frameworks/Library.lrmodule"];
		NSString* pathToResources = [pathToModule stringByAppendingPathComponent:@"Contents/Resources"];
		NSString* pathToIcon = [pathToResources stringByAppendingPathComponent:@"collectionCreation.png"];
		NSImage* image = [[[NSImage alloc] initByReferencingFile:pathToIcon] autorelease];
		image = [image imb_imageCroppedToRect:NSMakeRect(1,1,19,16)];
	
		if (image == nil) {
			image = [NSImage imb_sharedGenericFolderIcon];
		}
	
		collectionIcon = [image copy];
	}

	return collectionIcon;
}

- (NSString*)pyramidPathForImage:(NSNumber*)idLocal
{
	FMDatabase *database = [self database];
	NSString *uuid = nil;
	NSString *digest = nil;
	
	if (database != nil) {	
		NSString* query =	@" SELECT alf.id_global uuid, ids.digest"
							@" FROM Adobe_imageDevelopSettings ids"
							@" INNER JOIN Adobe_images ai ON ai.id_local = ids.image"
							@" INNER JOIN AgLibraryFile alf on alf.id_local = ai.rootFile"
							@" WHERE ids.image = ?"
							@" ORDER BY alf.id_global ASC"
							@" LIMIT 1";
		
		FMResultSet* results = [database executeQuery:query, idLocal];
		
		if ([results next]) {				
			uuid = [results stringForColumn:@"uuid"];
			digest = [results stringForColumn:@"digest"];
		}
		
		[results close];
	}
		
	if ((uuid != nil) && (digest != nil)) {
		NSString* prefixOne = [uuid substringToIndex:1];
		NSString* prefixFour = [uuid substringToIndex:4];
		NSString* fileName = [[NSString stringWithFormat:@"%@-%@", uuid, digest] stringByAppendingPathExtension:@"lrprev"];
		
		return [[prefixOne stringByAppendingPathComponent:prefixFour] stringByAppendingPathComponent:fileName];
	}
	
	return nil;
}

- (NSData*)previewDataForObject:(IMBObject*)inObject
{	
	IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
	NSString* absolutePyramidPath = [lightroomObject absolutePyramidPath];
	
	if (absolutePyramidPath != nil) {
		NSData* data = [NSData dataWithContentsOfMappedFile:absolutePyramidPath];
		
//		'AgHg'					-- a magic marker
//		header length			-- 2 bytes, big endian includes marker and length
//		version					-- 1 byte, zero for now
//		kind					-- 1 bytes, 0 == string, 1 == blob
//		data length				-- 8 bytes, big endian
//		data padding length		-- 8 bytes, big endian
//		name					-- zero terminated
//		< padding for rest of header >
//		< data >
//		< data padding >
		
		const char pattern[4] = { 0x41, 0x67, 0x48, 0x67 };
		NSUInteger index = [data lastIndexOfBytes:pattern length:4];
		
		if (index != NSNotFound) {
			unsigned short headerLengthValue; // size 2
			unsigned long long dataLengthValue; // size 8
			
			[data getBytes:&headerLengthValue range:NSMakeRange(index + 4, 2)];
			[data getBytes:&dataLengthValue range:NSMakeRange(index + 4 + 2 + 1 + 1, 8)];

			headerLengthValue = NSSwapBigShortToHost(headerLengthValue);
			dataLengthValue = NSSwapBigLongLongToHost(dataLengthValue);

			NSData* jpegData = nil;
            
            if ((index + headerLengthValue + dataLengthValue) < [data length]) {
                [data subdataWithRange:NSMakeRange(index + headerLengthValue, dataLengthValue)];
            }
            
			return jpegData;
		}
	}
	
	return nil;
}

- (FMDatabase*) libraryDatabase
{
	NSString* databasePath = (NSString*)self.mediaSource;
	NSString* readOnlyDatabasePath = [[self class] cloneDatabase:databasePath];
	FMDatabase* database = [FMDatabase databaseWithPath:readOnlyDatabasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*) previewsDatabase
{
	NSString* mainDatabasePath = (NSString*)self.mediaSource;
	NSString* rootPath = [mainDatabasePath stringByDeletingPathExtension];
	NSString* previewPackagePath = [[NSString stringWithFormat:@"%@ Previews", rootPath] stringByAppendingPathExtension:@"lrdata"];
	NSString* previewDatabasePath = [[previewPackagePath stringByAppendingPathComponent:@"previews"] stringByAppendingPathExtension:@"db"];
	FMDatabase* database = [FMDatabase databaseWithPath:previewDatabasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

+ (NSString*)cloneDatabase:(NSString*)databasePath
{
	// BEGIN ugly hack to work around Lightroom locking its database
	
	NSString *basePath = [databasePath stringByDeletingPathExtension];	
	NSString *pathExtension = [databasePath pathExtension];	
	NSString *readOnlyDatabasePath = [[NSString stringWithFormat:@"%@-readOnly", basePath] stringByAppendingPathExtension:pathExtension];
	
	NSFileManager *fileManager = [NSFileManager imb_threadSafeManager];
	BOOL needToCopyFile = YES;		// probably we will need to copy but let's check
	NSError* error;
	
	if ([fileManager fileExistsAtPath:readOnlyDatabasePath]) {
		error = nil;
		NSDictionary *attributesOfCopy = [fileManager attributesOfItemAtPath:readOnlyDatabasePath error:&error];
		if (error) NSLog (@"Unable to fetch attributes from %@: %@", readOnlyDatabasePath, error.localizedDescription);
		NSDate *modDateOfCopy = [attributesOfCopy fileModificationDate];
		
		error = nil;
		NSDictionary *attributesOfOrig = [fileManager attributesOfItemAtPath:databasePath error:&error];
		if (error) NSLog (@"Unable to fetch attributes from %@: %@", databasePath, error.localizedDescription);
		NSDate *modDateOfOrig = [attributesOfOrig fileModificationDate];
		
		if (NSOrderedSame == [modDateOfOrig compare:modDateOfCopy]) {
			needToCopyFile = NO;
		}
	}
	
	if (needToCopyFile) {
		(void) [fileManager removeItemAtPath:readOnlyDatabasePath error:&error];
		BOOL copied = (nil != databasePath)
					&& (nil != readOnlyDatabasePath)
					&& [fileManager copyItemAtPath:databasePath toPath:readOnlyDatabasePath error:&error];
		
		if (!copied) {
			NSLog (@"Unable to copy database file at %@: %@", databasePath, error.localizedDescription);
		}
	}
	
	// END ugly hack
	
	return readOnlyDatabasePath;
}

@end
