/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2008 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2008 by Karelia Software et al.
 
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

#import "CIImage+iMedia.h"
#import "NSImage+iMedia.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"


@interface iMBLightroomPhotosParser (Private)

- (iMBLibraryNode *)parseOneDatabaseWithPath:(NSString*)path intoLibraryNode:(iMBLibraryNode *)root version:(int)lightroom_version;
- (iMBLibraryNode *)parseAllImagesForRoot:(iMBLibraryNode*)root version:(int)lightroom_version;
- (iMBLibraryNode *)parseCollectionsForRoot:(iMBLibraryNode*)root version:(int)lightroom_version;

- (iMBLibraryNode*)nodeWithLocalID:(NSNumber*)aid withRoot:(iMBLibraryNode*)root;

+ (NSArray *)libraryPathsV2;
+ (NSArray *)libraryPathsV1;

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

    // the node is populated, so remove the 'loading' moniker. do this on the main thread to be friendly to bindings.
	[rootLibraryNode performSelectorOnMainThread:@selector(setName:) withObject:name waitUntilDone:NO];

    [pool release];
}

- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate
{
    NSMutableArray *libraryNodes = [NSMutableArray array];

    NSEnumerator *enumerator;
	NSString *currentPath;
    
    NSArray *libraryPathsV2 = [iMBLightroomPhotosParser libraryPathsV2];
	enumerator = [libraryPathsV2 objectEnumerator];
	while ((currentPath = [enumerator nextObject]) != nil)
    {
		NSString *name = LocalizedStringInIMedia(@"Lightroom 2", @"Lightroom");
        if ([libraryPathsV2 count] > 1)
            name = [name stringByAppendingFormat:@" (%@)", [[currentPath stringByDeletingLastPathComponent] lastPathComponent]];
        NSString *iconName = @"com.adobe.Lightroom:";
        iMBLibraryNode *libraryNode = [self parseDatabaseInThread:currentPath gate:gate name:name iconName:iconName icon:NULL];
        [libraryNode setAttribute:[NSNumber numberWithInt:2] forKey:@"LightroomVersion"];
        if (libraryNode != NULL)
        {
			[libraryNode setWatchedPath:currentPath];
			[libraryNode setPrioritySortOrder:1];
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
			[self parseAllImagesForRoot:root version:lightroom_version];
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
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
	NSString *path = [root attributeForKey:@"path"];
	FMDatabase *database = [FMDatabase databaseWithPath:path];
	
	if ([database open]) {
		NSMutableString *collectionQuery = [NSMutableString stringWithString:@"SELECT id_local, parent, kindName, name"];
		
		[collectionQuery appendString:@" FROM "];
		[collectionQuery appendString:@"AgLibraryTag"];
		[collectionQuery appendString:@" WHERE "];
		[collectionQuery appendString:@"kindName = ?"];
		
		FMResultSet *rsCollections = [database executeQuery:collectionQuery, @"AgCollectionTagKind"];
		
		while ([rsCollections next]) {
			NSNumber *idLocal = [NSNumber numberWithLong:[rsCollections longForColumn:@"id_local"]]; 
			NSNumber *idParentLocal = [NSNumber numberWithLong:[rsCollections longForColumn:@"parent"]];
			NSString *kind = [rsCollections stringForColumn:@"kindName"];
			NSString *name = [rsCollections stringForColumn:@"name"];
			
			if (name == nil) {
				if ([idParentLocal intValue] == 0) {
					name = LocalizedStringInIMedia(@"Collections", @"Collections");
				}
				else {
					name = LocalizedStringInIMedia(@"Unnamed", @"Unnamed");
				}
			}
			
			iMBLibraryNode *currentNode = [self nodeWithLocalID:idLocal withRoot:root];
			
			if (currentNode == nil) {
				currentNode = [[[iMBLibraryNode alloc] init] autorelease];
			}
            
            // after this point, all accesses to currentNode need to be thread safe (i.e. happen on the main thread)
			
			[currentNode fromThreadSetAttribute:idLocal forKey:@"idLocal"];
			[currentNode fromThreadSetAttribute:idParentLocal forKey:@"idParentLocal"];
			[currentNode fromThreadSetAttribute:name forKey:@"name"];
			[currentNode fromThreadSetAttribute:kind forKey:@"kind"];
			[currentNode fromThreadSetAttribute:name forKey:@"identifier"];
			[currentNode fromThreadSetAttribute:NSStringFromClass([self class]) forKey:@"parserClassName"];
//			[currentNode fromThreadSetAttribute:myDatabase forKey:@"watchedPath"];
			
			[currentNode fromThreadSetName:name];
			[currentNode fromThreadSetIcon:[NSImage genericFolderIcon]];
			[currentNode fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
			
			iMBLibraryNode *parentNode = [self nodeWithLocalID:idParentLocal withRoot:root];
			
			[parentNode fromThreadAddItem:currentNode];
			
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			FMDatabase *localDatabase = [FMDatabase databaseWithPath:path];
			
			if ([localDatabase open]) {
				NSMutableArray *images = [NSMutableArray array];				
				NSMutableString *imageQuery = [NSMutableString string];
                
                if (lightroom_version == 1)
                {
                    [imageQuery appendString:@" SELECT aif.absolutePath, aif.idx_filename, captionName"];
                    [imageQuery appendString:@" FROM Adobe_imageFiles aif"];
                    [imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryTagImage alti ON ai.id_local = alti.image"];
                    [imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
                    [imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
                    [imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
                    [imageQuery appendString:@" 		   WHERE altiCaption.tagKind = ?) ON ai.id_local = captionImage"];
                    [imageQuery appendString:@" WHERE "];
                    [imageQuery appendString:@" alti.tag = ?"];
                }
                else if (lightroom_version == 2)
                {
                    [imageQuery appendString:@" SELECT arf.absolutePath, alf.pathFromRoot, aif.idx_filename, captionName"];
                    [imageQuery appendString:@" FROM AgLibraryFile aif"];
                    [imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"];
                    [imageQuery appendString:@" INNER JOIN AgLibraryTagImage alti ON ai.id_local = alti.image"];
                    [imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
                    [imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
                    [imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
                    [imageQuery appendString:@" 		   WHERE altiCaption.tagKind = ?) ON ai.id_local = captionImage"];
                    [imageQuery appendString:@" WHERE "];
                    [imageQuery appendString:@" alti.tag = ?"];
                }
				
				FMResultSet *rsImages = [localDatabase executeQuery:imageQuery, @"AgCaptionTagKind", idLocal];
				
				while ([rsImages next]) {
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
						
						[imageRecord setObject:absolutePath forKey:@"ImagePath"];
						
						NSString *caption = [rsImages stringForColumn:@"captionName"];
						
						if (caption != nil) {
							[imageRecord setObject:caption forKey:@"Caption"];
						}
						else {
							NSString *fileName = [rsImages stringForColumn:@"idx_filename"];
							
							[imageRecord setObject:fileName forKey:@"Caption"];
							
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
            [imageQuery appendString:@" SELECT aif.absolutePath, aif.idx_filename, captionName"];
            [imageQuery appendString:@" FROM Adobe_imageFiles aif"];
            [imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
            [imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
            [imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
            [imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
            [imageQuery appendString:@" 		   WHERE altiCaption.tagKind = ?) ON ai.id_local = captionImage"];
        }
        else if (lightroom_version == 2)
        {
            [imageQuery appendString:@" SELECT arf.absolutePath, alf.pathFromRoot, aif.idx_filename, captionName"];
            [imageQuery appendString:@" FROM AgLibraryFile aif"];
            [imageQuery appendString:@" INNER JOIN Adobe_images ai ON aif.id_local = ai.rootFile"];
            [imageQuery appendString:@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"];
            [imageQuery appendString:@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"];
            [imageQuery appendString:@" LEFT JOIN (SELECT altiCaption.image captionImage, altCaption.name captionName, altiCaption.tag, altCaption.id_local"];
            [imageQuery appendString:@" 		   FROM AgLibraryTagImage altiCaption"];
            [imageQuery appendString:@" 		   INNER JOIN AgLibraryTag altCaption ON altiCaption.tag = altCaption.id_local"];
            [imageQuery appendString:@" 		   WHERE altiCaption.tagKind = ?) ON ai.id_local = captionImage"];
        }
		
		FMResultSet *rsImages = [database executeQuery:imageQuery, @"AgCaptionTagKind"];

		while ([rsImages next]) {
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
				
				[imageRecord setObject:absolutePath forKey:@"ImagePath"];
				
				NSString *caption = nil; //[rsImages stringForColumn:@"captionName"];
				
				if (caption != nil) {
					[imageRecord setObject:caption forKey:@"Caption"];
				}
				else {
					NSString *fileName = [rsImages stringForColumn:@"idx_filename"];
					
					[imageRecord setObject:fileName forKey:@"Caption"];
					
				}
				
				[images addObject:imageRecord];
			}
		}
		
		[imagesNode fromThreadSetAttribute:images forKey:@"Images"];
		
		[rsImages close];
	}
	
	[database close];
	[outerPool release];
	
	return root;
}

- (iMBLibraryNode*)nodeWithLocalID:(NSNumber*)aid withRoot:(iMBLibraryNode*)root
{
	if ([[root attributeForKey:@"idLocal"] longValue] == [aid longValue])
	{
		return root;
	}
	NSEnumerator *e = [[root allItems] objectEnumerator];
	iMBLibraryNode *cur;
	iMBLibraryNode *found;
	
	while (cur = [e nextObject])
	{
		found = [self nodeWithLocalID:[[aid retain] autorelease] withRoot:cur];
		if (found)
		{
			return found;
		}
	}
	return nil;
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

@end
