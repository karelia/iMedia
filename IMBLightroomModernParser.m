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

#import "IMBLightroomModernParser.h"

#import <Quartz/Quartz.h>

#import "FMDatabase.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBObject.h"
#import "IMBLightroomObject.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSObject+iMedia.h"
#import "NSWorkspace+iMedia.h"


@interface IMBLightroomModernParser ()

- (BOOL) checkDatabaseVersion;

@end


@implementation IMBLightroomModernParser

//----------------------------------------------------------------------------------------------------------------------

+ (NSArray*) concreteParserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	if ([self lightroomPath] != nil) {
		NSArray* libraryPaths = [self libraryPaths];
		
		for (NSString* libraryPath in libraryPaths) {
			IMBLightroomModernParser* parser = [[[[self class] alloc] initWithMediaType:inMediaType] autorelease];
			parser.mediaSource = libraryPath;
			parser.shouldDisplayLibraryName = libraryPaths.count > 1;
			
			// Check database version
			
			if (! [parser checkDatabaseVersion]) {
				continue;
			}
			
			[parserInstances addObject:parser];
		}
	}
	
	return parserInstances;
}

- (BOOL) checkDatabaseVersion
{	
	return NO;
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
	foldersNode.icon = [[self class] folderIcon];
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
	foldersObject.imageRepresentation = [[self class] largeFolderIcon];
	
	[objects addObject:foldersObject];

	
	// Add the Collections node...
	
	NSString* collectionsName = NSLocalizedStringWithDefaultValue(
																  @"IMBLightroomParser.collectionsName",
																  nil,IMBBundle(),
																  @"Collections",
																  @"Name of Collections node in IMBLightroomParser");
	
	NSMutableDictionary *collectionsAttributes = [NSMutableDictionary dictionaryWithCapacity:5];
	
	[collectionsAttributes setValue:[NSNumber numberWithInt:IMBLightroomNodeTypeRootCollection] forKey:@"nodeType"];

	IMBNode* collectionsNode = [[[IMBNode alloc] init] autorelease];
	collectionsNode.identifier = [self identifierWithCollectionId:[NSNumber numberWithLong:0]];
	collectionsNode.name = collectionsName;
	collectionsNode.icon = [[self class] groupIcon];
	collectionsNode.parser = self;
	collectionsNode.leaf = NO;
	collectionsNode.attributes = collectionsAttributes;

	[subNodes addObject:collectionsNode];
	
	IMBNodeObject* collectionsObject = [[[IMBNodeObject alloc] init] autorelease];
	collectionsObject.representedNodeIdentifier = collectionsNode.identifier;
	collectionsObject.name = collectionsNode.name;
	collectionsObject.metadata = nil;
	collectionsObject.parser = self;
	collectionsObject.index = 1;
	collectionsObject.imageLocation = (id)self.mediaSource;
	collectionsObject.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
	collectionsObject.imageRepresentation = [[self class] largeFolderIcon];
	
	[objects addObject:collectionsObject];
	
	inRootNode.subNodes = subNodes;
	inRootNode.objects = objects;
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
	NSString* query =	@" SELECT alc.id_local, alc.parent, alc.name, alc.creationId"
						@" FROM AgLibraryCollection alc"
						@" WHERE (alc.creationId = 'com.adobe.ag.library.collection' OR alc.creationId = 'com.adobe.ag.library.group') "
						@" AND alc.parent IS NULL";
	
	return query;
}


- (NSString*) collectionNodesQuery
{
	NSString* query =	@" SELECT alc.id_local, alc.parent, alc.name, alc.creationId"
						@" FROM AgLibraryCollection alc"
                        @" WHERE (alc.creationId = 'com.adobe.ag.library.collection' OR alc.creationId = 'com.adobe.ag.library.group') "
						@" AND alc.parent = ?";
	
	return query;
}


- (NSString*) folderObjectsQuery
{
	NSString* query = nil;

	if ([self.mediaType isEqualTo:kIMBMediaTypeMovie]) {
		query =
		@" SELECT	alf.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
		@"			iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile alf ON ai.rootFile = alf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE alf.folder in ( "
		@"		SELECT id_local"
		@"		FROM AgLibraryFolder"
		@"		WHERE id_local = ? OR (rootFolder = ? AND (pathFromRoot IS NULL OR pathFromRoot = ''))"
		@" )"
		@" AND ai.fileFormat == 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}
	else
	{
		query =
		@" SELECT	alf.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
		@"			iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile alf ON ai.rootFile = alf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE alf.folder in ( "
		@"		SELECT id_local"
		@"		FROM AgLibraryFolder"
		@"		WHERE id_local = ? OR (rootFolder = ? AND (pathFromRoot IS NULL OR pathFromRoot = ''))"
		@" )"
		@" AND ai.fileFormat <> 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}

	return query;

}

- (NSString*) collectionObjectsQuery
{
	NSString* query = nil;

	if ([self.mediaType isEqualTo:kIMBMediaTypeMovie])
	{
		query =  @" SELECT arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
		@"        aif.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
		@"        iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile aif ON aif.id_local = ai.rootFile"
		@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
		@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE IFNULL(ai.masterImage, ai.id_local) in ( "
		@"		SELECT image"
		@"		FROM AgLibraryCollectionImage alci"
		@"		WHERE alci.collection = ?"
		@" )"
		@" AND ai.fileFormat == 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}
	else
	{
		query =  @" SELECT arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
		@"        aif.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
		@"        iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile aif ON aif.id_local = ai.rootFile"
		@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
		@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE IFNULL(ai.masterImage, ai.id_local) in ( "
		@"		SELECT image"
		@"		FROM AgLibraryCollectionImage alci"
		@"		WHERE alci.collection = ?"
		@" )"
		@" AND ai.fileFormat <> 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}
	
	return query;
}

+ (NSImage*) folderIcon
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

+ (NSImage*) groupIcon;
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

+ (NSImage*) collectionIcon;
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

- (NSData*)previewDataForObject:(IMBObject*)inObject maximumSize:(NSNumber*)maximumSize
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
        NSData *patternData = [NSData dataWithBytesNoCopy:(void *)pattern length:4 freeWhenDone:NO];
		
		NSUInteger index = NSNotFound;
		
		if (maximumSize == nil) {
			index = [data rangeOfData:patternData options:NSDataSearchBackwards range:NSMakeRange(0, [data length])].location;
		}
		else {
			index = [data rangeOfData:patternData options:0 range:NSMakeRange(0, [data length])].location;
		}
		
		NSData* previousData = nil;
		CGFloat maximumSizeFloat = [maximumSize floatValue];
		
		while (index != NSNotFound) {
			unsigned short headerLengthValue; // size 2
			unsigned long long dataLengthValue; // size 8
			
			[data getBytes:&headerLengthValue range:NSMakeRange(index + 4, 2)];
			[data getBytes:&dataLengthValue range:NSMakeRange(index + 4 + 2 + 1 + 1, 8)];
			
			headerLengthValue = NSSwapBigShortToHost(headerLengthValue);
			dataLengthValue = NSSwapBigLongLongToHost(dataLengthValue);
			
			NSData* jpegData = nil;
			
            if ((index + headerLengthValue + dataLengthValue) < [data length]) {
                jpegData = [data subdataWithRange:NSMakeRange(index + headerLengthValue, dataLengthValue)];
            }
            
			if (maximumSize == nil) {
				return jpegData;
			}
			
			if (jpegData != nil) {
				CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)jpegData, nil);
				
				if (source != NULL) {
					CGImageRef imageRepresentation = CGImageSourceCreateImageAtIndex(source, 0, NULL);
					
					CFRelease(source);
					
					if (imageRepresentation != NULL) {
						CGFloat width = CGImageGetWidth(imageRepresentation);
						CGFloat height = CGImageGetHeight(imageRepresentation);
						
						CFRelease(imageRepresentation);
						
						if ((width > maximumSizeFloat) || (height > maximumSizeFloat)) {
							if (previousData == nil) {
								previousData = jpegData;
							}
							
							break;
						}
					}
					
					previousData = jpegData;
					index = [data rangeOfData:patternData options:0 range:NSMakeRange(index + 4, [data length] - index - 4)].location;
					
					continue;
				}
			}
			
			return jpegData;
		}
		
		return previousData;
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (FMDatabase*) libraryDatabase
{
	[[self class] imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	
	return nil;
}

- (FMDatabase*) previewsDatabase
{
	[[self class] imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------



//----------------------------------------------------------------------------------------------------------------------

@end
