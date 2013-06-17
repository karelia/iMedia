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


//----------------------------------------------------------------------------------------------------------------------


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBParser.h"
#import "IMBObject.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class FMDatabase;


//----------------------------------------------------------------------------------------------------------------------


typedef enum
{ 
	kIMBLightroomNodeTypeUnspecified = 0,
	IMBLightroomNodeTypeFolder,
	IMBLightroomNodeTypeCollection,
	IMBLightroomNodeTypeRootCollection,
	IMBLightroomNodeTypeSmartCollection
}
IMBLightroomNodeType;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLightroomParser : IMBParser
{
	NSString* _appPath;
	NSString* _dataPath;
	BOOL _shouldDisplayLibraryName;

	// We keep a separate FMDatabase instance for each thread that we are invoked from.
	// SQLite is basically threadsafe, but I have seen issues when using the same database
	// instance across multiple threads, and we can't predict which thread we will be called on.
	NSMutableDictionary* _databases;
	NSMutableDictionary* _thumbnailDatabases;
}

@property (retain) NSString* appPath;
@property (retain) NSString* atomicDataPath;
@property (assign) BOOL shouldDisplayLibraryName;
@property (nonatomic, retain) NSMutableDictionary *databases;
@property (nonatomic, retain) NSMutableDictionary *thumbnailDatabases;
@property (retain,readonly) FMDatabase* database;
@property (retain,readonly) FMDatabase* thumbnailDatabase;

+ (NSString*) identifier;
+ (NSString*) lightroomPath;

// Return an array to Lightroom library files...
+ (NSArray*) libraryPaths;
+ (void) parseRecentLibrariesList:(NSString*)inRecentLibrariesList into:(NSMutableArray*)inLibraryPaths;

- (NSString*) rootNodeIdentifier;
- (NSString*) identifierWithFolderId:(NSNumber*)inIdLocal;
- (NSString*) identifierWithCollectionId:(NSNumber*)inIdLocal;

- (NSDictionary*) attributesWithRootFolder:(NSNumber*)inRootFolder
								   idLocal:(NSNumber*)inIdLocal
								  rootPath:(NSString*)inRootPath
							  pathFromRoot:(NSString*)inPathFromRoot
                                  nodeType:(IMBLightroomNodeType)inNodeType;


// Returns a cached FMDatabase for the current thread
- (FMDatabase*) database;
- (FMDatabase*) thumbnailDatabase;

// Unconditionally creates an autoreleased FMDatabase instance. Used 
// by the above caching accessors to instantiate as needed per-thread.
- (FMDatabase*) libraryDatabase;
- (FMDatabase*) previewsDatabase;

- (NSString*)pyramidPathForImage:(NSNumber*)idLocal;
- (NSData*)previewDataForObject:(IMBObject*)inObject maximumSize:(NSNumber*)maximumSize;

@end


//----------------------------------------------------------------------------------------------------------------------


@protocol IMBLightroomParser

@required

+ (NSArray*) concreteParserInstancesForMediaType:(NSString*)inMediaType;

+ (NSString*) rootFolderQuery;
+ (NSString*) folderNodesQuery;

+ (NSString*) rootCollectionNodesQuery;
+ (NSString*) collectionNodesQuery;

+ (NSString*) folderObjectsQuery;
+ (NSString*) collectionObjectsQuery;

+ (NSImage*) folderIcon;
+ (NSImage*) groupIcon;
+ (NSImage*) collectionIcon;

@end


@interface IMBLightroomParser (Subclassers)

- (void) populateSubnodesForRootNode:(IMBNode*)inRootNode;
- (void) populateSubnodesForRootFoldersNode:(IMBNode*)inFoldersNode;
- (void) populateSubnodesForFolderNode:(IMBNode*)inParentNode;
- (void) populateSubnodesForCollectionNode:(IMBNode*)inRootNode;
- (void) populateSubnodesForSmartCollectionNode:(IMBNode*)inRootNode;
- (void) populateObjectsForFolderNode:(IMBNode*)inNode;
- (void) populateObjectsForCollectionNode:(IMBNode*)inNode;
- (void) populateObjectsForSmartCollectionNode:(IMBNode*)inNode;

+ (IMBLightroomNodeType) nodeTypeForCreationId:(NSString *)creationId;

+ (NSImage*) largeFolderIcon;

- (NSNumber*) idLocalFromAttributes:(NSDictionary*)inAttributes;
- (BOOL) canOpenImageFileAtPath:(NSString*)inPath;
- (IMBObject*) objectWithPath:(NSString*)inPath
					  idLocal:(NSNumber*)idLocal
						 name:(NSString*)inName
				  pyramidPath:(NSString*)inPyramidPath
					 metadata:(NSDictionary*)inMetadata
						index:(NSUInteger)inIndex;

@end

//----------------------------------------------------------------------------------------------------------------------

