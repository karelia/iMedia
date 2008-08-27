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


#import "iMBiPhotoAbstractParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSString+iMedia.h"
#import "NSImage+iMedia.h"

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

- (NSImage*) iconForType: (NSString*) name 
{
	// iPhoto 7
	
	if ([name isEqualToString:@"Events"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_events.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Event"])
		return [NSImage imageResourceNamed:@"sl-icon-small_event.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Roll"])
		return [NSImage imageResourceNamed:@"sl-icon-small_roll.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if (name == nil || [name isEqualToString:@"Photos"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_library.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Selected Event Album"])
		return [NSImage imageResourceNamed:@"sl-icon-small_event.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Special Month"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_cal.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Special Roll"]) 
		return [NSImage imageResourceNamed:@"sl-icon_lastImport.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Shelf"]) 		
		return [NSImage imageResourceNamed:@"sl-icon_flag.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Folder"])	
		return [NSImage imageResourceNamed:@"sl-icon-small_folder.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Regular"])
		return [NSImage imageResourceNamed:@"sl-icon-small_album.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Smart"]) 	
		return [NSImage imageResourceNamed:@"sl-icon-small_smartAlbum.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Slideshow"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_slideshow.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Book"]) 	
		return [NSImage imageResourceNamed:@"sl-icon-small_book.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Subscribed"]) 	
		return [NSImage imageResourceNamed:@"sl-icon-small_subscribedAlbum.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Photocasts"])	
		return [NSImage imageResourceNamed:@"sl-icon-small_subscriptions.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Card"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_card.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Calendar"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_calendar.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"Published"]) 
		return [NSImage imageResourceNamed:@"sl-icon-small_publishedAlbum.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];

	return [NSImage imageResourceNamed:@"sl-icon-small_album.tiff" fromApplication:@"com.apple.iPhoto" fallbackTo:@"folder"];
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
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:anImagePath];
	
	NSMutableDictionary *library = [NSMutableDictionary dictionary];
	
	//Find all iPhoto libraries
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",
														(CFStringRef)@"com.apple.iApps");
	
	//Iterate over libraries, pulling dictionary from contents and adding to array for processing;
	NSArray *libraries = (NSArray *)iApps;
    
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			[library addEntriesFromDictionary:db];
		}
	}
	[libraries autorelease];
	
	if ([[library allKeys] count] == 0)
	{
		return nil;
	}
	
	NSDictionary *imageRecords = [library objectForKey:@"Master Image List"];
	NSDictionary *keywordMap = [library objectForKey:@"List of Keywords"];
	myFakeAlbumID = 0;
	
	NSEnumerator *albumEnum = [[library objectForKey:@"List of Albums"] objectEnumerator];
	[self parseAlbums:albumEnum 
		 imageRecords:imageRecords
			mediaType:aMediaType 
		   keywordMap:keywordMap
		  wantUntyped:aWantUntyped
		wantThumbPath:aWantThumbPath
			imagePath:anImagePath
			  forRoot:root];	
    
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
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			if (imageRecord == nil) 
			{
				continue;	// skip if the whole record is missing for some reason
			}
			NSString *mediaType = [imageRecord objectForKey:@"MediaType"];
			if (!aWantUntyped && !mediaType)
			{
				continue;	// skip if media type is missing and we require a media type
			}
			if (mediaType && ![mediaType isEqualToString:aMediaType])
			{
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
            aid = [rollRec objectForKey:@"RollID"];
            parent = eventsFolder;
        }
        else if ([rollRec objectForKey:@"AlbumName"] != NULL)
        {
            // we're looking at iPhoto 6 records
            [lib setName:[rollRec objectForKey:@"AlbumName"]];
            [lib setIcon:[self iconForType:@"Event"]];
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
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			if (imageRecord == nil) 
			{
				continue;	// skip if the whole record is missing for some reason
			}
			NSString *mediaType = [imageRecord objectForKey:@"MediaType"];
			if (!aWantUntyped && !mediaType)
			{
				continue;	// skip if media type is missing and we require a media type
			}
			if (mediaType && ![mediaType isEqualToString:aMediaType])
			{
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
