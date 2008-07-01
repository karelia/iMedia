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
#import "iMedia.h"

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
		CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",
															(CFStringRef)@"com.apple.iApps");
		
		NSArray *libraries = (NSArray *)iApps;
		NSEnumerator *e = [libraries objectEnumerator];
		NSString *cur;
		
		while (cur = [e nextObject]) {
			[self watchFile:cur];
		}
		[libraries autorelease];
	}
	return self;
}

- (NSString *)iconNameForType:(NSString*)name
{
	if ([name isEqualToString:@"Special Roll"])
		return @"MBiPhotoRoll";
	else if ([name hasSuffix:@"Rolls"])
		return @"MBiPhotoRoll";
	else if ([name isEqualToString:@"Special Month"])
		return @"MBiPhotoCalendar";
	else if ([name hasSuffix:@"Months"])
		return @"MBiPhotoCalendar";
	else if ([name isEqualToString:@"Subscribed"])
		return @"photocast";
	else if ([name isEqualToString:@"Photocasts"])
		return @"photocast_folder";
	else if ([name isEqualToString:@"Slideshow"])
		return @"slideshow";
	else if ([name isEqualToString:@"Book"])
		return @"book";
	else if ([name isEqualToString:@"Calendar"])
		return @"calendar";
	else if ([name isEqualToString:@"Card"])
		return @"card";
	else if ([name hasSuffix:@"Events"])
		return @"MBiPhotoAlbum";
	else if ([name hasSuffix:@"EventsFolder"])
		return @"events";
	else if (name == nil)
		return @"com.apple.iPhoto:";			// top level library
	else
		return @"MBiPhotoAlbum";
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

// General parser

- (iMBLibraryNode *)parseDatabaseAttributeKey:(NSString *)anImagePath
								 mediaType:(NSString *)aMediaType
							   wantUntyped:(BOOL)aWantUntyped
							 wantThumbPath:(BOOL)aWantThumbPath
{
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	[root setName:LocalizedStringInIMedia(@"iPhoto", @"iPhoto")];
	[root setIconName:@"photo_tiny"];
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
		[lib setIconName:[self iconNameForType:[albumRec objectForKey:@"Album Type"]]];
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
				iMBLibraryNode *parent = [self nodeWithAlbumID:[albumRec objectForKey:@"Parent"]
													  withRoot:root];
				if (!parent)
					NSLog(@"Failed to find parent node");
				[parent addItem:lib];
			}
			else
			{
				[root addItem:lib];
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
	iMBLibraryNode *eventsFolder = nil;
	while (rollRec = [rollsEnum nextObject])
	{		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		iMBLibraryNode *lib = [[[iMBLibraryNode alloc] init] autorelease];
		[lib setName:[rollRec objectForKey:@"RollName"]];
		[lib setIconName:[self iconNameForType:@"Events"]];
		// iPhoto 2 doesn't have albumID's so let's just fake them
		NSNumber *aid = [rollRec objectForKey:@"RollID"];
		if (!aid)
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
			//	place the events in an own folder...
			if (!eventsFolder) {
				eventsFolder = [[iMBLibraryNode alloc] init];
				[root addItem:eventsFolder];
				[eventsFolder release];
				[eventsFolder setIconName:[self iconNameForType:@"EventsFolder"]];
				[eventsFolder setName:@"Events"];
				root = eventsFolder;
			}
			
			if ([rollRec objectForKey:@"Parent"])
			{
				iMBLibraryNode *parent = [self nodeWithAlbumID:[rollRec objectForKey:@"Parent"]
													  withRoot:root];
				if (!parent)
					NSLog(@"Failed to find parent node");
				[parent addItem:lib];
			}
			else
			{
				[root addItem:lib];
			}
		}		
		[pool release];
	}
}


- (BOOL) showAlbumType:(NSString *)albumType {
	return !([albumType isEqualToString:@"Book"] || [albumType isEqualToString:@"Slideshow"]);
}

@end
