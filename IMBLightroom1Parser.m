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

#import "IMBLightroom1Parser.h"

#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBSandboxUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBLightroom1Parser


//----------------------------------------------------------------------------------------------------------------------


// Unique identifier for this parser...

+ (NSString*) identifier
{
	return @"com.karelia.imedia.Lightroom1";
}

// The bundle identifier of the Lightroom app this parser is based upon

+ (NSString*) lightroomAppBundleIdentifier
{
    return @"com.adobe.Lightroom";
}

// Key in Lightroom app user defaults: which library to load

+ (NSString*) preferencesLibraryToLoadKey
{
    return @"AgLibrary_activeLibraryPath11";
}

// Key in Lightroom app user defaults: which libraries have been loaded recently

+ (NSString*) preferencesRecentLibrariesKey
{
    return @"recentLibraries11";
}

+ (NSArray*) concreteParserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	if ([self lightroomPath] != nil) {
		NSArray* libraryPaths = [self libraryPaths];
		
		for (NSString* libraryPath in libraryPaths) {
			IMBLightroom1Parser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
			parser.mediaSource = libraryPath;
			parser.shouldDisplayLibraryName = libraryPaths.count > 1;
			
			[parserInstances addObject:parser];
			[parser release];
		}
	}
	
	return parserInstances;
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
	NSString* query =	@" SELECT	aif.absolutePath, aif.idx_filename, ai.id_local, ai.fileHeight, ai.fileWidth, ai.orientation, ai.captureTime,"
						@"			caption, apcp.relativeDataPath pyramidPath"
						@" FROM Adobe_imageFiles aif"
						@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"
						@" INNER JOIN Adobe_previewCachePyramids apcp ON apcp.id_local = ai.pyramidIDCache"
						@" INNER JOIN AgLibraryTagImage alti ON ai.id_local = alti.image"
						@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name caption, altiCaption.tag, altCaption.id_local"
						@" 		   FROM AgLibraryTagImage altiCaption"
						@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"
						@" 		   WHERE altiCaption.tagKind = 'AgCaptionTagKind') ON ai.id_local = captionImage"
						@" WHERE alti.tag = ?"
						@" ORDER BY ai.captureTime ASC";
	
	return query;
}

+ (NSImage*) folderIcon
{
	static NSImage* folderIcon = nil;
	
	if (folderIcon == nil) {
		folderIcon = [[NSImage imb_sharedGenericFolderIcon] copy];
	}
	
	return folderIcon;
}

+ (NSImage*) groupIcon;
{
	static NSImage* groupIcon = nil;
	
	if (groupIcon == nil) {
		groupIcon = [[NSImage imb_sharedGenericFolderIcon] copy];
	}
	
	return groupIcon;
}

+ (NSImage*) collectionIcon;
{
	static NSImage* collectionIcon = nil;
	
	if (collectionIcon == nil) {
		collectionIcon = [[NSImage imb_sharedGenericFolderIcon] copy];
	}
	
	return collectionIcon;
}

@end
