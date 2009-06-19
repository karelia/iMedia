/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#import "iMBAperturePhotosParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"

#ifndef NSMakeCollectable
#define NSMakeCollectable(x) (id)(x)
#endif

//	CONFIGURATION
//	
//	If you switch off both defines below you get the same contents as the Aperture
//	tree in iPhoto.
//
//	These settings could be part of the iMedia browser preferences:

//	Shows the 'Aperture Library', knot which holds all images from Aperture not
//	just the "top of the stack" images.
//#define SHOW_ALL_IMAGES_FOLDER

//	Shows a top level knot named "Aperture" which is the root of all other knots.
//#define SHOW_TOP_LEVEL_APERTURE_KNOT


@implementation iMBAperturePhotosParser

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


- (NSImage*) iconForType:(NSString*)name 
{
	// '12' ???
	// cp: I found icons for a 'smart journal' or a 'smart book' but no menu command to create on.
	
	static const SiMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		{@"1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil},	// album
		{@"2",	@"Project_I_SAlbum.tiff",			@"folder",	nil,	nil},	// smart album
		{@"3",	@"List_Icons_LibrarySAlbum.tiff",	@"folder",	nil,	nil},	// library **** ... 200X
		{@"4",	@"Project_I_Project.tiff",			@"folder",	nil,	nil},	// project
		{@"5",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (top level)
		{@"6",	@"Project_I_Folder.tiff",			@"folder",	nil,	nil},	// folder
		{@"7",	@"Project_I_ProjectFolder.tiff",	@"folder",	nil,	nil},	// sub-folder of project
		{@"8",	@"Project_I_Book.tiff",				@"folder",	nil,	nil},	// book
		{@"9",	@"Project_I_WebPage.tiff",			@"folder",	nil,	nil},	// web gallery
		{@"9",	@"Project_I_WebGallery.tiff",		@"folder",	nil,	nil},	// web gallery (alternate image)
		{@"10",	@"Project_I_WebJournal.tiff",		@"folder",	nil,	nil},	// web journal
		{@"11",	@"Project_I_LightTable.tiff",		@"folder",	nil,	nil},	// light table
		{@"13",	@"Project_I_SWebGallery.tiff",		@"folder",	nil,	nil},	// smart web gallery
		{@"97",	@"Project_I_Projects.tiff",			@"folder",	nil,	nil},	// library
		{@"98",	@"AppIcon.icns",					@"folder",	nil,	nil},	// library
		{@"99",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (knot holding all images)
	};

	static const SiMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil}	// fallback image
	};

	return [self iconForType:name fromBundleID:@"com.apple.Aperture" withMappingTable:&kIconTypeMapping];
}

- (iMBLibraryNode *)nodeWithAlbumID:(NSNumber *)aid withRoot:(iMBLibraryNode *)root
{
	if ([[root attributeForKey:@"AlbumId"] longValue] == [aid longValue])
	{
		return root;
	}
	NSEnumerator *e = [[root allItems] objectEnumerator];
	iMBLibraryNode *cur;
	iMBLibraryNode *found;
	
	while (cur = [e nextObject])
	{
		found = [self nodeWithAlbumID:[[aid retain] autorelease] withRoot:cur];
		if (found)
		{
			return found;
		}
	}
	return nil;
}


- (void)parseOneDatabaseWithPath:(NSString *)databasePath intoLibraryNode:(iMBLibraryNode *)root
{
	[root fromThreadSetFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
	
    NSDictionary *library = [NSDictionary dictionaryWithContentsOfFile:databasePath];
	
	NSDictionary *imageRecords = [library objectForKey:@"Master Image List"];
	
	//	cp: No keywords in Aperture XML.
	#if 0
		NSDictionary *keywordMap = [library objectForKey:@"List of Keywords"];
	#endif
	
	NSArray *albums = [library objectForKey:@"List of Albums"];
	NSEnumerator *albumEnum = [albums objectEnumerator];
	NSDictionary *albumRec;
	int fakeAlbumID = 0;
	
	//Parse dictionary creating libraries, and filling with track information
	while (albumRec = [albumEnum nextObject])
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		//	'99': library knot holding all images, not just the "top of the stack" images
		#ifndef SHOW_ALL_IMAGES_FOLDER
		if ([[albumRec objectForKey:@"Album Type"] isEqualToString:@"99"])
		{
			[pool release];
			continue;
		}	
		#endif
		
		iMBLibraryNode *lib = [[[iMBLibraryNode alloc] init] autorelease];
		[lib setName:[albumRec objectForKey:@"AlbumName"]];
        [lib setIdentifier:[albumRec objectForKey:@"AlbumName"]];
        [lib setParserClassName:NSStringFromClass([self class])];
		[lib setWatchedPath:myDatabase];
//		[lib setIcon:[self iconForType:[albumRec objectForKey:@"Album Type"]]];
		NSImage* icon = [self iconForType:[albumRec objectForKey:@"Album Type"]];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(36.0,36.0)];
		[lib setIcon:icon];

		NSNumber *aid = [albumRec objectForKey:@"AlbumId"];
		#ifndef SHOW_TOP_LEVEL_APERTURE_KNOT
		if ([aid longValue] == 1)
		{
			[pool release];
			continue;
		}	
		#endif
			
		// cp: Aperture does have albumID's so do we need the fake?
		if (!aid)
		{
			aid = [NSNumber numberWithInt:fakeAlbumID];
			fakeAlbumID++;
		}
		[lib fromThreadSetAttribute:aid forKey:@"AlbumId"];
		
		NSMutableArray *newPhotolist = [NSMutableArray array];
		NSEnumerator *pictureItemsEnum = [[albumRec objectForKey:@"KeyList"] objectEnumerator];
		NSString *key;
		
		while (key = [pictureItemsEnum nextObject])
		{
			NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			
            // It's always possible that the record might not exist. Can't fully trusty
            // the integrity of the librrary
            if (!imageRecord)
            {
                NSLog(@"IMBAperturePhotosParser: no image record found with key %@", key);
				[pool2 release];
                continue;
            }
            
			if ([imageRecord objectForKey:@"MediaType"] && ![[imageRecord objectForKey:@"MediaType"] isEqualToString:@"Image"])
			{
				[pool2 release];
				continue;
			}
			
			//	Better have the modification date than no date.
			if (![imageRecord objectForKey:@"DateAsTimerInterval"]) 
			{
				NSNumber* date = [imageRecord objectForKey:@"ModDateAsTimerInterval"];
				if (date) [imageRecord setObject:date forKey:@"DateAsTimerInterval"];
			}
			
 			[imageRecord setObject:key forKey:@"VersionUUID"];

			[newPhotolist addObject:imageRecord];
			
			//	cp: No keywords in Aperture XML.
			#if 0
				//swap the keyword index to names
				NSArray *keywords = [imageRecord objectForKey:@"Keywords"];
				if ([keywords count] > 0) {
					NSEnumerator *keywordEnum = [keywords objectEnumerator];
					NSString *keywordKey;
					NSMutableArray *realKeywords = [NSMutableArray array];
					
					while (keywordKey = [keywordEnum nextObject]) {
						NSString *actualKeyword = [keywordMap objectForKey:keywordKey];
						if (actualKeyword)
						{
							[realKeywords addObject:actualKeyword];
						}
					}
					
					NSMutableDictionary *mutatedKeywordRecord = [NSMutableDictionary dictionaryWithDictionary:imageRecord];
					[mutatedKeywordRecord setObject:realKeywords forKey:@"iMediaKeywords"];
					[imageRecord setObject:mutatedKeywordRecord forKey:key];
				}
			#endif
			[pool2 release];
		}

		if ([albumRec objectForKey:@"Parent"])
		{
			NSNumber* parentId = [albumRec objectForKey:@"Parent"];
			iMBLibraryNode *parent = root;
			#ifndef SHOW_TOP_LEVEL_APERTURE_KNOT
				if ([parentId intValue] != 1) {
					parent = [self nodeWithAlbumID:parentId withRoot:root];
				}
			#else
				parent = [self nodeWithAlbumID:parentId withRoot:root];
			#endif
			if (!parent)
				NSLog(@"iMBAperturePhotosParser failed to find parent node");
			[parent fromThreadAddItem:lib];
		}
		else
		{
			[root fromThreadAddItem:lib];
		}

        // set the "Images" key AFTER lib has been added into the library node tree.
        // this allows the "Images" change to be propagated up the tree so that the
        // outline view gets displayed properly.
        [lib fromThreadSetAttribute:newPhotolist forKey:@"Images"];
		[pool release];
    }
}

- (void)populateLibraryNode:(iMBLibraryNode *)rootLibraryNode name:(NSString *)name databasePath:(NSString *)databasePath
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [self parseOneDatabaseWithPath:databasePath intoLibraryNode:rootLibraryNode];
        
    [pool release];
}

- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate
{
    NSMutableArray *libraryNodes = [NSMutableArray array];
	//	Find all Aperture libraries
	NSArray *libraryURLs = [NSMakeCollectable(CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",
														(CFStringRef)@"com.apple.iApps"))  autorelease];
	unsigned int n = [libraryURLs count];
	NSEnumerator *enumerator = [libraryURLs objectEnumerator];
	NSString *currentURLString;
	while ((currentURLString = [enumerator nextObject]) != nil)
    {
        NSURL *currentURL = [NSURL URLWithString:currentURLString];
        if ( [currentURL isFileURL] )
        {
            NSString *currentPath = [currentURL path];
			NSString *name = LocalizedStringInIMedia(@"Aperture", @"Aperture");
            if (n>1) name = [NSString stringWithFormat:@"%@ (%@)", LocalizedStringInIMedia(@"Aperture", @"Aperture"), [[[currentPath stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension]];
			NSString *iconName = @"com.apple.Aperture:";
            iMBLibraryNode *libraryNode = [self parseDatabaseInThread:currentPath gate:gate name:name iconName:iconName icon:NULL];
            if (libraryNode != NULL)
            {
				[libraryNode setWatchedPath:currentPath];
                [libraryNode setPrioritySortOrder:1];
                [libraryNodes addObject:libraryNode];
            }
        }
    }
    return libraryNodes;
}

+ (NSDictionary*)enhancedRecordForRecord:(NSDictionary*)record
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *masterPath = nil;
	NSString *previewPath = [record valueForKey:@"ImagePath"];
	NSString *basePath = [[previewPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
	
	// Look for the master within the library
	NSString *infoPath = [[basePath stringByAppendingPathComponent:@"OriginalVersionInfo"] stringByAppendingPathExtension:@"apversion"];
    NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:infoPath];
	NSString *masterName = [infoDict objectForKey:@"fileName"];
	
	if (masterName != nil) {
		NSString *localPath = [basePath stringByAppendingPathComponent:masterName];
		
		if ([fileManager fileExistsAtPath:localPath]) {
			masterPath = localPath;
		}
		else {
			NSString *apFile = [localPath stringByAppendingPathExtension:@"apfile"];
			NSDictionary *apDict = [NSDictionary dictionaryWithContentsOfFile:apFile];
			NSString *imagePath = [apDict objectForKey:@"imagePath"];
			NSDictionary *volumeInfo = [apDict objectForKey:@"volumeInfo"];
			NSString *volumeName = [volumeInfo objectForKey:@"volumeName"];
			
			if (volumeName != nil) {
				imagePath = [[@"/Volumes" stringByAppendingPathComponent:volumeName] stringByAppendingPathComponent:imagePath];
			}
			else {
				imagePath = [@"/" stringByAppendingString:imagePath];
			}

			if ([fileManager fileExistsAtPath:imagePath]) {
				masterPath = imagePath;
			}
		}
	}
		
	if (masterPath == nil) { // The master file is a referenced external file	
		NSRange range = [previewPath rangeOfString:@".aplibrary/"];
		NSString *libraryPath = [previewPath substringToIndex:(range.location + range.length)];
		NSString *databasePath = [[libraryPath stringByAppendingPathComponent:@"Aperture.aplib"] stringByAppendingPathComponent:@"Library.apdb"];
		FMDatabase *database = [FMDatabase databaseWithPath:databasePath];
		
		if ([database open]) {
			NSString *fileUUID = nil;
			NSString *imagePath = nil;
			NSString *fileVolumeUUID = nil;
			NSString *volumeName = nil;
			
			NSString *versionUUID = [record valueForKey:@"VersionUUID"];
			FMResultSet *fileUUIDResult = [database executeQuery:@"SELECT zfileuuid FROM zrkversion WHERE zuuid = ?", versionUUID];
			
			if ([fileUUIDResult next]) {
				fileUUID = [fileUUIDResult stringForColumn:@"zfileuuid"];
			}
			
			[fileUUIDResult close];		

			if (fileUUID != nil) {
				FMResultSet *imagePathResult = [database executeQuery:@"SELECT zimagepath FROM zrkfile WHERE zuuid = ?", fileUUID];
			
				if ([imagePathResult next]) {
					imagePath =[imagePathResult stringForColumn:@"zimagepath"];
				}
				
				[imagePathResult close];		

				FMResultSet *fileVolumeUUIDResult = [database executeQuery:@"SELECT zfilevolumeuuid FROM zrkfile WHERE zuuid = ?", fileUUID];
				
				if ([fileVolumeUUIDResult next]) {
					fileVolumeUUID =[fileVolumeUUIDResult stringForColumn:@"zfilevolumeuuid"];
				}
				
				[fileVolumeUUIDResult close];		
			
				if (fileVolumeUUID != nil) {
					FMResultSet *volumeNameResult = [database executeQuery:@"SELECT zname FROM zrkvolume WHERE zuuid = ?", fileVolumeUUID];
						
					if ([volumeNameResult next]) {
						volumeName = [volumeNameResult stringForColumn:@"zname"];
					}

					[volumeNameResult close];		
				}
			}
			else { // We may be looking at a pre-2.0 library
				NSMutableString *imagePathQuery = [NSMutableString string];
				
				[imagePathQuery appendString:@"SELECT zimagepath FROM zrkfile"];
				[imagePathQuery appendString:@" WHERE z_pk = ("];
				[imagePathQuery appendString:@"    SELECT zoriginalfile FROM zrkmaster"];
				[imagePathQuery appendString:@"     WHERE z_pk = ("];
				[imagePathQuery appendString:@"        SELECT zmaster FROM zrkversion"];
				[imagePathQuery appendString:@"         WHERE zuuid = ?"];
				[imagePathQuery appendString:@"      )"];
				[imagePathQuery appendString:@" )"];
				
				FMResultSet *imagePathResult = [database executeQuery:imagePathQuery, versionUUID];
				
				if ([imagePathResult next]) {
					imagePath = [imagePathResult stringForColumn:@"zimagepath"];
				}

				[imagePathResult close];
				
				if (imagePath != nil) {
					NSMutableString *volumeNameQuery = [NSMutableString string];
					
					[volumeNameQuery appendString:@"SELECT zname FROM zrkvolume"];
					[volumeNameQuery appendString:@" WHERE z_pk = ("];
					[volumeNameQuery appendString:@"    SELECT zfilevolume FROM zrkfile"];
					[volumeNameQuery appendString:@"     WHERE z_pk = ("];
					[volumeNameQuery appendString:@"        SELECT zoriginalfile FROM zrkmaster"];
					[volumeNameQuery appendString:@"         WHERE z_pk = ("];
					[volumeNameQuery appendString:@"            SELECT zmaster FROM zrkversion"];
					[volumeNameQuery appendString:@"             WHERE zuuid = ?"];
					[volumeNameQuery appendString:@"         )"];
					[volumeNameQuery appendString:@"     )"];
					[volumeNameQuery appendString:@" )"];
					
					FMResultSet *volumeNameResult = [database executeQuery:volumeNameQuery, versionUUID];
					
					if ([volumeNameResult next]) {
						volumeName  =[volumeNameResult stringForColumn:@"zname"];
					}
					
					[volumeNameResult close];		
				}
			}
			
			if (imagePath != nil) {
				if (volumeName == nil) {
					volumeName = @"/";
				}
				else if (![volumeName hasPrefix:@"/Volumes/"]) {
					volumeName = [@"/Volumes/" stringByAppendingPathComponent:volumeName];
				}
				
				imagePath = [volumeName stringByAppendingPathComponent:imagePath];
				
				if ([fileManager fileExistsAtPath:imagePath]) {
					masterPath = imagePath;
				}
			}
			
			[database close];
		}
	}
	
	if (masterPath != nil) {
		NSMutableDictionary *enhancedRecord = [NSMutableDictionary dictionaryWithDictionary:record];
		
		[enhancedRecord setObject:masterPath forKey:@"OriginalPath"];
		[enhancedRecord setObject:masterPath forKey:@"MasterPath"];
		
		return enhancedRecord;
	}
	
	return record;
}

@end