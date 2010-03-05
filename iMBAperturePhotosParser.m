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


@interface iMBAperturePhotosParser (Private)

+ (NSString*)pathForVolumeNamed:(NSString *)name;
+ (NSString*)pathForVolumeUUID:(NSString *)uuid;
+ (NSString*)cloneDatabase:(NSString*)databasePath;

@end


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


- (NSImage*) iconForType2:(NSString*)inType 
{
	// '12' ???
	// cp: I found icons for a 'smart journal' or a 'smart book' but no menu command to create on.
	
	static const SiMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		{@"v2-1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil},	// album
		{@"v2-2",	@"Project_I_SAlbum.tiff",			@"folder",	nil,	nil},	// smart album
		{@"v2-3",	@"List_Icons_LibrarySAlbum.tiff",	@"folder",	nil,	nil},	// library **** ... 200X
		{@"v2-4",	@"Project_I_Project.tiff",			@"folder",	nil,	nil},	// project
		{@"v2-5",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (top level)
		{@"v2-6",	@"Project_I_Folder.tiff",			@"folder",	nil,	nil},	// folder
		{@"v2-7",	@"Project_I_ProjectFolder.tiff",	@"folder",	nil,	nil},	// sub-folder of project
		{@"v2-8",	@"Project_I_Book.tiff",				@"folder",	nil,	nil},	// book
		{@"v2-9",	@"Project_I_WebPage.tiff",			@"folder",	nil,	nil},	// web gallery
		{@"v2-9",	@"Project_I_WebGallery.tiff",		@"folder",	nil,	nil},	// web gallery (alternate image)
		{@"v2-10",	@"Project_I_WebJournal.tiff",		@"folder",	nil,	nil},	// web journal
		{@"v2-11",	@"Project_I_LightTable.tiff",		@"folder",	nil,	nil},	// light table
		{@"v2-13",	@"Project_I_SWebGallery.tiff",		@"folder",	nil,	nil},	// smart web gallery
		{@"v2-97",	@"Project_I_Projects.tiff",			@"folder",	nil,	nil},	// library
		{@"v2-98",	@"AppIcon.icns",					@"folder",	nil,	nil},	// library
		{@"v2-99",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (knot holding all images)
	};
	
	static const SiMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"v2-1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil}	// fallback image
	};
	
	// Since icons are different for different versions of Aperture, we are adding the prefix v2- or v3- 
	// to the album type so that we can store different icons (for each version) in the icon cache...
	
	NSString* type = [@"v2-" stringByAppendingString:inType];

	return [self iconForType:type fromBundleID:@"com.apple.Aperture" withMappingTable:&kIconTypeMapping];
}

- (NSImage*) iconForType3:(NSString*)inType 
{
	static const SiMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		{@"v3-1",	@"SL-album.tiff",					@"folder",	nil,	nil},	// album
		{@"v3-2",	@"SL-smartAlbum.tiff",				@"folder",	nil,	nil},	// smart album
		{@"v3-3",	@"SL-smartAlbum.tiff",				@"folder",	nil,	nil},	// library **** ... 200X
		{@"v3-4",	@"SL-project.tiff",					@"folder",	nil,	nil},	// project
		{@"v3-5",	@"SL-allProjects.tiff",				@"folder",	nil,	nil},	// library (top level)
		{@"v3-6",	@"SL-folder.tiff",					@"folder",	nil,	nil},	// folder
		{@"v3-7",	@"SL-folder.tiff",					@"folder",	nil,	nil},	// sub-folder of project
		{@"v3-8",	@"SL-book.tiff",					@"folder",	nil,	nil},	// book
		{@"v3-9",	@"SL-webpage.tiff",					@"folder",	nil,	nil},	// web gallery
		{@"v3-9",	@"Project_I_WebGallery.tiff",		@"folder",	nil,	nil},	// web gallery (alternate image)
		{@"v3-10",	@"SL-webJournal.tiff",				@"folder",	nil,	nil},	// web journal
		{@"v3-11",	@"SL-lightTable.tiff",				@"folder",	nil,	nil},	// light table
		{@"v3-13",	@"sl-icon-small_webGallery.tiff",	@"folder",	nil,	nil},	// smart web gallery
		{@"v3-19",	@"SL-slideshow.tiff",				@"folder",	nil,	nil},	// slideshow
		{@"v3-94",	@"SL-photos.tiff",					@"folder",	nil,	nil},	// photos
		{@"v3-95",	@"SL-flag.tif",						@"folder",	nil,	nil},	// flagged
		{@"v3-96",	@"SL-smartLibrary.tiff",			@"folder",	nil,	nil},	// library albums
		{@"v3-97",	@"SL-allProjects.tiff",				@"folder",	nil,	nil},	// library
		{@"v3-98",	@"AppIcon.icns",					@"folder",	nil,	nil},	// library
	};
	
	static const SiMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"1",	@"SL-album.tiff",					@"folder",	nil,	nil}	// fallback image
	};
	
	// Since icons are different for different versions of Aperture, we are adding the prefix v2- or v3- 
	// to the album type so that we can store different icons (for each version) in the icon cache...
	
	NSString* type = [@"v3-" stringByAppendingString:inType];

	return [self iconForType:type fromBundleID:@"com.apple.Aperture" withMappingTable:&kIconTypeMapping];
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
	NSString *versionString = [library objectForKey:@"Application Version"];
	int versionInteger = [versionString intValue];

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
		NSString *albumType = [albumRec objectForKey:@"Album Type"];
		BOOL skipAlbum = NO;
		
		//	'99': library knot holding all images, not just the "top of the stack" images
		#ifndef SHOW_ALL_IMAGES_FOLDER
		skipAlbum = skipAlbum || [albumType isEqualToString:@"99"];
		#endif
		
		if (versionInteger == 3) {
			skipAlbum = skipAlbum || [albumType isEqualToString:@"5"];
			skipAlbum = skipAlbum || [albumType isEqualToString:@"94"];
			skipAlbum = skipAlbum || [albumType isEqualToString:@"97"];
			skipAlbum = skipAlbum || [albumType isEqualToString:@"98"];
			skipAlbum = skipAlbum || [albumType isEqualToString:@"99"];
		}
		
		if (skipAlbum) {
			[pool release];
			continue;
		}	
		
		iMBLibraryNode *lib = [[[iMBLibraryNode alloc] init] autorelease];
		[lib setName:[albumRec objectForKey:@"AlbumName"]];
        [lib setIdentifier:[albumRec objectForKey:@"AlbumName"]];
        [lib setParserClassName:NSStringFromClass([self class])];
		[lib setWatchedPath:myDatabase];
//		[lib setIcon:[self iconForType:[albumRec objectForKey:@"Album Type"]]];
		NSImage* icon = nil;
		
		if (versionInteger == 3) {
			icon = [self iconForType3:[albumRec objectForKey:@"Album Type"]];
		}
		else {
			icon = [self iconForType2:[albumRec objectForKey:@"Album Type"]];
		}
		
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
			
			if (versionInteger == 3) {
				if ([parentId intValue] == 3) {
					parentId = [NSNumber numberWithInt:1];
				}
			}
			
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
	
	NSRange range = [previewPath rangeOfString:@".aplibrary/"];
	NSString *libraryPath = [previewPath substringToIndex:(range.location + range.length)];
	NSString *databasePath = [[libraryPath stringByAppendingPathComponent:@"Database"] stringByAppendingPathComponent:@"Library.apdb"];
	
	if ([fileManager fileExistsAtPath:databasePath]) {
		// We are looking at Aperture 3
		NSString *readOnlyDatabasePath = [iMBAperturePhotosParser cloneDatabase:databasePath];
		FMDatabase *database = [FMDatabase databaseWithPath:readOnlyDatabasePath];
		
		if ([database open]) {
			NSString *masterUUID = nil;
			NSString *imagePath = nil;
			NSString *fileVolumeUUID = nil;
			NSString *diskUUID = nil;
			
			NSString *versionUUID = [record valueForKey:@"VersionUUID"];
			FMResultSet *masterUUIDResult =
				[database executeQuery:@"SELECT masterUuid, rawMasterUuid, nonRawMasterUuid FROM rkversion WHERE uuid = ?", versionUUID];
			
			if ([masterUUIDResult next]) {
				masterUUID = [masterUUIDResult stringForColumn:@"rawMasterUuid"];
				
				if (masterUUID  == nil) {
					masterUUID = [masterUUIDResult stringForColumn:@"nonRawMasterUuid"];

					if (masterUUID  == nil) {
						masterUUID = [masterUUIDResult stringForColumn:@"masterUuid"];
					}
				}
			}
			
			[masterUUIDResult close];		
			
			if (masterUUID != nil) {
				FMResultSet *imagePathResult = [database executeQuery:@"SELECT fileVolumeUuid, imagePath FROM rkmaster WHERE uuid = ?", masterUUID];
				
				if ([imagePathResult next]) {
					imagePath =[imagePathResult stringForColumn:@"imagePath"];
					fileVolumeUUID =[imagePathResult stringForColumn:@"fileVolumeUuid"];
				}
				
				[imagePathResult close];		
				
				if (fileVolumeUUID != nil) {
					FMResultSet *diskUUIDResult = [database executeQuery:@"SELECT diskUuid FROM rkvolume WHERE uuid = ?", fileVolumeUUID];
					
					if ([diskUUIDResult next]) {
						diskUUID = [diskUUIDResult stringForColumn:@"diskUuid"];
					}
					
					[diskUUIDResult close];		
				}
			}

			if (imagePath != nil) {
				if (fileVolumeUUID != nil) {
					if (diskUUID != nil) {
						NSString *volumePath = [iMBAperturePhotosParser pathForVolumeUUID:diskUUID];
						NSString *fullPath = [volumePath stringByAppendingPathComponent:imagePath];
						
						if ([fileManager fileExistsAtPath:fullPath]) {
							masterPath = fullPath;
						}
					}
				}
				else {
					NSString *mastersPath = [libraryPath stringByAppendingPathComponent:@"Masters"];
					NSString *fullPath = [mastersPath stringByAppendingPathComponent:imagePath];
					
					if ([fileManager fileExistsAtPath:fullPath]) {
						masterPath = fullPath;
					}					
				}
			}
			
			[database close];
		}		
	}
	else {
		// Aperture 2 or prior
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
				
				if (imagePath != nil) {
					NSDictionary *volumeInfo = [apDict objectForKey:@"volumeInfo"];
					NSString *volumeName = [volumeInfo objectForKey:@"volumeName"];
					NSString *volumePath = [iMBAperturePhotosParser pathForVolumeNamed:volumeName];
					NSString *fullPath = [volumePath stringByAppendingPathComponent:imagePath];
					
					if ([fileManager fileExistsAtPath:fullPath]) {
						masterPath = fullPath;
					}
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
					NSString *volumePath = [iMBAperturePhotosParser pathForVolumeNamed:volumeName];
					NSString *fullPath = [volumePath stringByAppendingPathComponent:imagePath];
					
					if ([fileManager fileExistsAtPath:fullPath]) {
						masterPath = fullPath;
					}
				}
				
				[database close];
			}
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

+ (NSString*)pathForVolumeNamed:(NSString *)name
{
	if (name != nil) {
		HFSUniStr255 volumeName;
		FSRef volumeFSRef;
		unsigned int volumeIndex = 1;
		
		while (FSGetVolumeInfo(kFSInvalidVolumeRefNum, volumeIndex++, NULL, kFSVolInfoNone, NULL, &volumeName, &volumeFSRef) == noErr) {
			if ([[NSString stringWithCharacters:volumeName.unicode length:volumeName.length] isEqualToString:name]) {
				NSURL *url = [(NSURL *)CFURLCreateFromFSRef(NULL, &volumeFSRef) autorelease];
				
				return [url path];
			}
		}
		
		return [@"/Volumes" stringByAppendingPathComponent:name];
	}
	
	return @"/";
}


+ (NSString*)pathForVolumeUUID:(NSString *)uuid
{
	if (uuid != nil) {
		NSString *path = @"/usr/sbin/diskutil";

		NSMutableArray *arguments = [NSMutableArray array];
		
		[arguments addObject:@"info"];
		[arguments addObject:@"-plist"];
		[arguments addObject:uuid];
		
		NSTask *task = [[NSTask alloc] init];
		
		[task setLaunchPath:path];	
		[task setArguments:arguments];
		
		NSPipe *outputPipe = [NSPipe pipe];
		NSPipe *errorPipe = [NSPipe pipe];
		
		[task setStandardOutput:outputPipe];
		[task setStandardError:errorPipe];
		
		NSFileHandle *outputFileHandle = [outputPipe fileHandleForReading];
		NSFileHandle *errorFileHandle = [errorPipe fileHandleForReading];
		
		@try {
			[task launch];
			[task waitUntilExit];
		}
		@catch (NSException *localException) {
			NSLog(@"Caught %@: %@", [localException name], [localException reason]);

			return nil;
		}
		
		NSData *outputData = [outputFileHandle readDataToEndOfFile];
		NSData *errorData = [errorFileHandle readDataToEndOfFile];
		NSString *result = nil;
		
		if ((errorData != nil) && [errorData length]) {
			NSLog(@"Got error message: %@",  [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease]);
		}
		
		if ([task terminationStatus] == noErr) {
			if ((outputData != nil) && [outputData length]) {
				result = [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease];
			}
		}
		
		[outputFileHandle closeFile];
		[errorFileHandle closeFile];
		
		[task release];
		
		if (result != nil) {
			NSDictionary *volumeInfo = [result propertyList];
			NSString *mountPoint = [volumeInfo objectForKey:@"MountPoint"];
			
			return mountPoint;
		}
	}
	
	return nil;
}

+ (NSString*)cloneDatabase:(NSString*)databasePath
{
	// BEGIN ugly hack to work around Aperture locking its database

	NSString *basePath = [databasePath stringByDeletingPathExtension];	
	NSString *pathExtension = [databasePath pathExtension];	
	NSString *readOnlyDatabasePath = [[NSString stringWithFormat:@"%@-readOnly", basePath] stringByAppendingPathExtension:pathExtension];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL needToCopyFile = YES;		// probably we will need to copy but let's check
	
	if ([fileManager fileExistsAtPath:readOnlyDatabasePath]) {
		NSDictionary *attributesOfCopy = [fileManager fileAttributesAtPath:readOnlyDatabasePath traverseLink:YES];
		NSDate *modDateOfCopy = [attributesOfCopy fileModificationDate];
		
		NSDictionary *attributesOfOrig = [fileManager fileAttributesAtPath:databasePath traverseLink:YES];
		NSDate *modDateOfOrig = [attributesOfOrig fileModificationDate];
		
		if (NSOrderedSame == [modDateOfOrig compare:modDateOfCopy]) {
			needToCopyFile = NO;
		}
	}
	
	if (needToCopyFile) {
		(void) [fileManager removeFileAtPath:readOnlyDatabasePath handler:nil];
		BOOL copied = [fileManager copyPath:databasePath toPath:readOnlyDatabasePath handler:nil];
		
		if (!copied) {
			NSLog(@"Unable to copy database file at %@", databasePath);
		}
	}
	
	// END ugly hack
	
	return readOnlyDatabasePath;
}

@end