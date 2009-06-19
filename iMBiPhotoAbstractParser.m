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


#import "iMBiPhotoAbstractParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSString+iMedia.h"
#import "NSImage+iMedia.h"

#ifndef NSMakeCollectable
#define NSMakeCollectable(x) (id)(x)
#endif

@interface iMBiPhotoAbstractParser (private)
- (void) parseAlbums: (NSEnumerator*) albumEnum 
		imageRecords: (NSDictionary*) imageRecords
		   mediaType: (NSString*) aMediaType 
		  keywordMap: (NSDictionary*) keywordMap
		 wantUntyped: (BOOL) aWantUntyped
	   wantThumbPath: (BOOL) aWantThumbPath
		   imagePath: (NSString*) anImagePath
			 forRoot: (iMBLibraryNode*) root;

- (void) parseRolls: (NSEnumerator*) rollsEnum 
	   imageRecords: (NSDictionary*) imageRecords
		  mediaType: (NSString*) aMediaType 
		 keywordMap: (NSDictionary*) keywordMap
		wantUntyped: (BOOL) aWantUntyped
	  wantThumbPath: (BOOL) aWantThumbPath
		  imagePath: (NSString*) anImagePath
			forRoot: (iMBLibraryNode*) root;
@end

@implementation iMBiPhotoAbstractParser

- (id)init
{
	if (self = [super initWithContentsOfFile:nil])
	{
	}
	return self;
}

- (NSImage*) iconForType:(NSString*)name 
{
	static const SiMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		// iPhoto 7
		{@"Book",					@"sl-icon-small_book.tiff",				@"folder",	nil,				nil},
		{@"Calendar",				@"sl-icon-small_calendar.tiff",			@"folder",	nil,				nil},
		{@"Card",					@"sl-icon-small_card.tiff",				@"folder",	nil,				nil},
		{@"Event",					@"sl-icon-small_event.tiff",			@"folder",	nil,				nil},
		{@"Events",					@"sl-icon-small_events.tiff",			@"folder",	nil,				nil},
		{@"Folder",					@"sl-icon-small_folder.tiff",			@"folder",	nil,				nil},
		{@"Photocasts",				@"sl-icon-small_subscriptions.tiff",	@"folder",	nil,				nil},
		{@"Photos",					@"sl-icon-small_library.tiff",			@"folder",	nil,				nil},
		{@"Published",				@"sl-icon-small_publishedAlbum.tiff",	nil,		@"dotMacLogo.icns",	@"/System/Library/CoreServices/CoreTypes.bundle"},
		{@"Regular",				@"sl-icon-small_album.tiff",			@"folder",	nil,				nil},
		{@"Roll",					@"sl-icon-small_roll.tiff",				@"folder",	nil,				nil},
		{@"Selected Event Album",	@"sl-icon-small_event.tiff",			@"folder",	nil,				nil},
		{@"Shelf",					@"sl-icon_flag.tiff",					@"folder",	nil,				nil},
		{@"Slideshow",				@"sl-icon-small_slideshow.tiff",		@"folder",	nil,				nil},
		{@"Smart",					@"sl-icon-small_smartAlbum.tiff",		@"folder",	nil,				nil},
		{@"Special Month",			@"sl-icon-small_cal.tiff",				@"folder",	nil,				nil},
		{@"Special Roll",			@"sl-icon_lastImport.tiff",				@"folder",	nil,				nil},
		{@"Subscribed",				@"sl-icon-small_subscribedAlbum.tiff",	@"folder",	nil,				nil},
	};

	static const SiMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"Regular",				@"sl-icon-small_album.tiff",			@"folder",	nil,				nil}	// fallback image
	};

	return [self iconForType:((name != nil) ? name : @"Photos") fromBundleID:@"com.apple.iPhoto" withMappingTable:&kIconTypeMapping];
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
		found = [self nodeWithAlbumID:aid withRoot:cur];
		if (found)
		{
			return found;
		}
	}
	return nil;
}

// General parser

- (iMBLibraryNode *)parseDatabaseAttributeKey:(NSString *)anImagePath
								 mediaType:(NSString *)aMediaType
							   wantUntyped:(BOOL)aWantUntyped
							 wantThumbPath:(BOOL)aWantThumbPath
{
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	[root setName:LocalizedStringInIMedia(@"iPhoto", @"iPhoto")];
	[root setIconName:@"com.apple.iPhoto:"];
	[root setIdentifier:@"iPhoto"];
	[root setParserClassName:NSStringFromClass([self class])];
//	[root setWatchedPath:myDatabase];
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:anImagePath];
	
	NSMutableDictionary *library = [NSMutableDictionary dictionary];
	
	//Find all iPhoto libraries
	NSArray *libraries = [NSMakeCollectable(CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",
														(CFStringRef)@"com.apple.iApps")) autorelease];
	
	//Iterate over libraries, pulling dictionary from contents and adding to array for processing;
    
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSURL* url = [NSURL URLWithString:cur];
		[root setWatchedPath:[url path]];
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:url];
		if (db) {
			[library addEntriesFromDictionary:db];
		}
	}
	
	if ([[library allKeys] count] == 0)
	{
		return nil;
	}
	
	NSDictionary *imageRecords = [library objectForKey:@"Master Image List"];
	NSDictionary *keywordMap = [library objectForKey:@"List of Keywords"];
	myFakeAlbumID = 0;
	
	//	TODO: Should we do this only for dedicated iPhoto versions? Or is this
	//	"handled" implicitly by the existence of the key "List of Rolls"?
	NSEnumerator *rollsEnum = [[library objectForKey:@"List of Rolls"] objectEnumerator];
	[self parseRolls:rollsEnum 
		imageRecords:imageRecords
		   mediaType:aMediaType 
		  keywordMap:keywordMap
		 wantUntyped:aWantUntyped
	   wantThumbPath:aWantThumbPath
		   imagePath:anImagePath
			 forRoot:root];
	
	NSEnumerator *albumEnum = [[library objectForKey:@"List of Albums"] objectEnumerator];
	[self parseAlbums:albumEnum 
		 imageRecords:imageRecords
			mediaType:aMediaType 
		   keywordMap:keywordMap
		  wantUntyped:aWantUntyped
		wantThumbPath:aWantThumbPath
			imagePath:anImagePath
			  forRoot:root];	
    	
	if ([[root valueForKey:anImagePath] count] == 0)
	{
		root = nil;
	}
	
	[root setPrioritySortOrder:1];

	return root;
}


- (void) parseAlbums: (NSEnumerator*) albumEnum 
		imageRecords: (NSDictionary*) imageRecords
		   mediaType: (NSString*) aMediaType 
		  keywordMap: (NSDictionary*) keywordMap
		 wantUntyped: (BOOL) aWantUntyped
	   wantThumbPath: (BOOL) aWantThumbPath
		   imagePath: (NSString*) anImagePath
			 forRoot: (iMBLibraryNode*) root {
	
	//	Parse dictionary creating libraries, and filling with track infromation
	NSDictionary *albumRec;
	while (albumRec = [albumEnum nextObject])
	{
		if (![self showAlbumType:[albumRec objectForKey:@"Album Type"]])
		{
			continue;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		iMBLibraryNode *lib = [[[iMBLibraryNode alloc] init] autorelease];
		[lib setName:[albumRec objectForKey:@"AlbumName"]];
		[lib setIcon:[self iconForType:[albumRec objectForKey:@"Album Type"]]];
        [lib setIdentifier:[albumRec objectForKey:@"AlbumName"]];
        [lib setParserClassName:NSStringFromClass([self class])];
//		[lib setWatchedPath:myDatabase];
		// iPhoto 2 doesn't have albumID's so let's just fake them
		NSNumber *aid = [albumRec objectForKey:@"AlbumId"];
		if (!aid)
		{
			aid = [NSNumber numberWithInt:myFakeAlbumID]; 
			myFakeAlbumID++;
		}
		[lib setAttribute:aid forKey:@"AlbumId"];
		
		NSMutableArray *newPhotolist = [NSMutableArray array];
		NSEnumerator *pictureItemsEnum = [[albumRec objectForKey:@"KeyList"] objectEnumerator];
		NSString *key;
		BOOL hasItems = NO;
		
		while (key = [pictureItemsEnum nextObject])
		{
			NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			if (imageRecord == nil) 
			{
				[pool2 release];
				continue;	// skip if the whole record is missing for some reason
			}
			NSString *mediaType = [imageRecord objectForKey:@"MediaType"];
			if (!aWantUntyped && !mediaType)
			{
				[pool2 release];
				continue;	// skip if media type is missing and we require a media type
			}
			if (mediaType && ![mediaType isEqualToString:aMediaType])
			{
				[pool2 release];
				continue;	// skip if this media type doesn't match what we are looking for
			}
			hasItems = YES;
			NSString *thumbPath = [imageRecord objectForKey:@"ThumbPath"];
			if (aWantThumbPath && thumbPath)
			{
				[imageRecord setObject:thumbPath forKey:@"Preview"];
			}
			
			[newPhotolist addObject:imageRecord];
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
				
				[imageRecord setObject:realKeywords forKey:@"iMediaKeywords"];
			}
			
			[pool2 release];
		}
		[lib setAttribute:newPhotolist forKey:anImagePath];
		
		if (hasItems) // only display albums that have movies.... what happens when a child album has items we want, but the parent doesn't?
		{
			
			if ([albumRec objectForKey:@"Parent"])
			{
				iMBLibraryNode *parent = [self nodeWithAlbumID:[albumRec objectForKey:@"Parent"] withRoot:root];
				if (!parent)
					NSLog(@"iMBiPhotoAbstractParser (parseAlbums) failed to find parent node");
				[parent fromThreadAddItem:lib];
			}
			else
			{
				[root fromThreadAddItem:lib];
			}
		}		
		[pool release];
	}
}


- (void) parseRolls: (NSEnumerator*) rollsEnum 
	   imageRecords: (NSDictionary*) imageRecords
		  mediaType: (NSString*) aMediaType 
		 keywordMap: (NSDictionary*) keywordMap
		wantUntyped: (BOOL) aWantUntyped
	  wantThumbPath: (BOOL) aWantThumbPath
		  imagePath: (NSString*) anImagePath
			forRoot: (iMBLibraryNode*) root {
	
	//	Parse dictionary creating libraries, and filling with track infromation
	NSDictionary *rollRec;

    // create the events folder but don't add it unless we actually have an event
    BOOL eventsFolderAdded = NO;
	iMBLibraryNode *eventsFolder = [[[iMBLibraryNode alloc] init] autorelease];
    [eventsFolder setIcon:[self iconForType:@"Events"]];
    [eventsFolder setName:@"Events"];
	[eventsFolder setIdentifier:@"Events"];
	[eventsFolder setParserClassName:NSStringFromClass([self class])];
//	[eventsFolder setWatchedPath:myDatabase];
    
	while (rollRec = [rollsEnum nextObject])
	{		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		iMBLibraryNode *lib = [[[iMBLibraryNode alloc] init] autorelease];

        NSNumber *aid = NULL;
        iMBLibraryNode *parent = NULL;

        if ([rollRec objectForKey:@"RollName"] != NULL)
        {
            // we're looking at iPhoto 7 records or better
            [lib setName:[rollRec objectForKey:@"RollName"]];
            [lib setIcon:[self iconForType:@"Event"]];
			[lib setIdentifier:[rollRec objectForKey:@"RollName"]];
			[lib setParserClassName:NSStringFromClass([self class])];
//			[lib setWatchedPath:myDatabase];
            aid = [rollRec objectForKey:@"RollID"];
            parent = eventsFolder;
        }
        else if ([rollRec objectForKey:@"AlbumName"] != NULL)
        {
            // we're looking at iPhoto 6 records
            [lib setName:[rollRec objectForKey:@"AlbumName"]];
            [lib setIcon:[self iconForType:@"Event"]];
			[lib setIdentifier:[rollRec objectForKey:@"AlbumName"]];
			[lib setParserClassName:NSStringFromClass([self class])];
//			[lib setWatchedPath:myDatabase];
            aid = [rollRec objectForKey:@"AlbumId"];
            parent = [self nodeWithAlbumID:[rollRec objectForKey:@"Parent"] withRoot:root];
        }
        
		// iPhoto 2 doesn't have albumID's so let's just fake them.
        // this code may be unnecessary now. anyone have older files to check?
        // in any case, it seems like a good fallback.
		if (aid == NULL)
		{
			aid = [NSNumber numberWithInt:myFakeAlbumID];
			myFakeAlbumID++;
		}
		[lib setAttribute:aid forKey:@"RollID"];
		
		NSMutableArray *newPhotolist = [NSMutableArray array];
		NSEnumerator *pictureItemsEnum = [[rollRec objectForKey:@"KeyList"] objectEnumerator];
		NSString *key;
		BOOL hasItems = NO;
		
		while (key = [pictureItemsEnum nextObject])
		{
			NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			if (imageRecord == nil) 
			{
				[pool2 release]; 
				continue;	// skip if the whole record is missing for some reason
			}
			NSString *mediaType = [imageRecord objectForKey:@"MediaType"];
			if (!aWantUntyped && !mediaType)
			{
				[pool2 release]; 
				continue;	// skip if media type is missing and we require a media type
			}
			if (mediaType && ![mediaType isEqualToString:aMediaType])
			{
				[pool2 release]; 
				continue;	// skip if this media type doesn't match what we are looking for
			}
			hasItems = YES;
			NSString *thumbPath = [imageRecord objectForKey:@"ThumbPath"];
			if (aWantThumbPath && thumbPath)
			{
				[imageRecord setObject:thumbPath forKey:@"Preview"];
			}
			
			[newPhotolist addObject:imageRecord];
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
				
				[imageRecord setObject:realKeywords forKey:@"iMediaKeywords"];
			}
			[pool2 release];
		}
		[lib setAttribute:newPhotolist forKey:anImagePath];
		
		if (hasItems) // only display events that have movies.... what happens when a child album has items we want, but the parent doesn't?
		{
            // check to see if we need to add the 'events' folder.
            if (!eventsFolderAdded && parent == eventsFolder)
            {
                [root fromThreadAddItem:eventsFolder];
                eventsFolderAdded = YES;
            }

            [parent fromThreadAddItem:lib];
		}		
		[pool release];
	}
}


- (BOOL) showAlbumType:(NSString *)albumType {
	return !([albumType isEqualToString:@"Book"] || [albumType isEqualToString:@"Slideshow"]);
}

@end
