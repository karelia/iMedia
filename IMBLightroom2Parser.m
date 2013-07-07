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

#import "IMBLightroom2Parser.h"

#import <Quartz/Quartz.h>

#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBObject.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBSandboxUtilities.h"


@implementation IMBLightroom2Parser

//----------------------------------------------------------------------------------------------------------------------


// Unique identifier for this parser...

+ (NSString*) identifier
{
	return @"com.karelia.imedia.Lightroom2";
}

// The bundle identifier of the Lightroom app this parser is based upon

+ (NSString*) lightroomAppBundleIdentifier
{
    return @"com.adobe.Lightroom2";
}

// Key in Ligthroom app user defaults: which library to load

+ (NSString*) preferencesLibraryToLoadKey
{
    return @"libraryToLoad20";
}

// Key in Ligthroom app user defaults: which libraries have been loaded recently

+ (NSString*) preferencesRecentLibrariesKey
{
    return @"recentLibraries20";
}

+ (NSArray*) concreteParserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	if ([self lightroomPath] != nil) {
		NSArray* libraryPaths = [self libraryPaths];
		
		for (NSString* libraryPath in libraryPaths) {			
			IMBLightroom2Parser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
			parser.mediaSource = libraryPath;
			parser.shouldDisplayLibraryName = libraryPaths.count > 1;
			
			[parserInstances addObject:parser];
			[parser release];
		}
	}
	
	return parserInstances;
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

	inRootNode.subNodes = subNodes;
	inRootNode.objects = objects;
	
	// Add the Collections node...
	
	[super populateSubnodesForRootNode:inRootNode];
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
						@" ORDER BY pathFromRoot, robustRepresentation ASC";
	
	
	return query;
}

- (NSString*) rootCollectionNodesQuery
{
	NSString* query =	@" SELECT alt.id_local, alt.parent, alt.name"
						@" FROM AgLibraryTag alt"
						@" WHERE kindName = 'AgCollectionTagKind'"
						@" AND alt.parent IS NULL"
						@" AND NOT EXISTS ("
						@"	SELECT alc.id_local"
						@"	FROM AgLibraryContent alc"
						@"	WHERE alt.id_local = alc.containingTag"
						@"	AND alc.owningModule = 'ag.library.smart_collection')";
	
	return query;
}

- (NSString*) collectionNodesQuery
{
	NSString* query =	@" SELECT alt.id_local, alt.parent, alt.name"
						@" FROM AgLibraryTag alt"
						@" WHERE kindName = 'AgCollectionTagKind'"
						@" AND alt.parent = ?"
						@" AND NOT EXISTS ("
						@"	SELECT alc.id_local"
						@"	FROM AgLibraryContent alc"
						@"	WHERE alt.id_local = alc.containingTag"
						@"	AND alc.owningModule = 'ag.library.smart_collection')";
	
	return query;
}

- (NSString*) folderObjectsQuery
{
	NSString* query =	@" SELECT	alf.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
						@"			caption, apcp.relativeDataPath pyramidPath"
						@" FROM AgLibraryFile alf"
						@" INNER JOIN Adobe_images ai ON alf.id_local = ai.rootFile"
						@" INNER JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"
						@" LEFT JOIN"
						@"		(SELECT altiCaption.image captionImage, altCaption.name caption, altiCaption.tag, altCaption.id_local"
						@" 		 FROM AgLibraryTagImage altiCaption"
						@" 		 INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"
						@" 		 WHERE altiCaption.tagKind = 'AgCaptionTagKind'"
						@"		)"
						@"		ON ai.id_local = captionImage"
						@" WHERE alf.folder in ( "
						@"		SELECT id_local"
						@"		FROM AgLibraryFolder"
						@"		WHERE id_local = ? OR (rootFolder = ? AND (pathFromRoot IS NULL OR pathFromRoot = ''))"
						@" )"
						@" ORDER BY ai.captureTime ASC";
	
	return query;
}

- (NSString*) collectionObjectsQuery
{
	NSString* query =	@" SELECT	arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
						@"			aif.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
						@"			caption, apcp.relativeDataPath pyramidPath"
						@" FROM AgLibraryFile aif"
						@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"
						@" INNER JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"
						@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
						@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
						@" INNER JOIN AgLibraryTagImage alti ON ai.id_local = alti.image"
						@" LEFT JOIN"
						@"		(SELECT altiCaption.image captionImage, altCaption.name caption, altiCaption.tag, altCaption.id_local"
						@"		FROM AgLibraryTagImage altiCaption"
						@"		INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"
						@"		WHERE altiCaption.tagKind = 'AgCaptionTagKind')"
						@"	ON ai.id_local = captionImage"
						@" WHERE alti.tag = ?"
						@" ORDER BY ai.captureTime ASC";
	
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

@end
