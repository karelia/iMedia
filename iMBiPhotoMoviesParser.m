/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 */

#import "iMBiPhotoMoviesParser.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"

#import <QTKit/QTKit.h>

@implementation iMBiPhotoMoviesParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"movies"];
	
	[pool release];
}


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
	else if (name == nil)
		return @"com.apple.iPhoto";			// top level library
	else
		return @"MBiPhotoAlbum";
}

- (iMBLibraryNode *)nodeWithAlbumID:(NSNumber *)aid withRoot:(iMBLibraryNode *)root
{
	if ([[root attributeForKey:@"AlbumId"] longValue] == [aid longValue])
	{
		return root;
	}
	NSEnumerator *e = [[root items] objectEnumerator];
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

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"iPhoto", @"iPhoto")];
	[root setIconName:@"photo_tiny"];
	
	NSMutableDictionary *library = [NSMutableDictionary dictionary];
	NSMutableArray *photoLists = [NSMutableArray array];
	
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
	
	NSDictionary *imageRecords = [library objectForKey:@"Master Image List"];
	NSDictionary *keywordMap = [library objectForKey:@"List of Keywords"];
	NSEnumerator *albumEnum = [[library objectForKey:@"List of Albums"] objectEnumerator];
	NSDictionary *albumRec;
	
	//Parse dictionary creating libraries, and filling with track infromation
	while (albumRec = [albumEnum nextObject])
	{
		if ([[albumRec objectForKey:@"Album Type"] isEqualToString:@"Book"] ||
			[[albumRec objectForKey:@"Album Type"] isEqualToString:@"Slideshow"])
		{
			continue;
		}
		iMBLibraryNode *lib = [[iMBLibraryNode alloc] init];
		[lib setName:[albumRec objectForKey:@"AlbumName"]];
		[lib setIconName:[self iconNameForType:[albumRec objectForKey:@"Album Type"]]];
		[lib setAttribute:[albumRec objectForKey:@"AlbumId"] forKey:@"AlbumId"];
		
		NSMutableArray *newPhotolist = [NSMutableArray array];
		NSEnumerator *pictureItemsEnum = [[albumRec objectForKey:@"KeyList"] objectEnumerator];
		NSString *key;
		BOOL hasMovies = NO;
		
		while (key = [pictureItemsEnum nextObject])
		{
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			if (([imageRecord objectForKey:@"MediaType"] && ![[imageRecord objectForKey:@"MediaType"] isEqualToString:@"Movie"]) ||
				![imageRecord objectForKey:@"MediaType"])
			{
				continue;
			}
			hasMovies = YES;
			[newPhotolist addObject:imageRecord];
			[imageRecord setObject:[imageRecord objectForKey:@"ThumbPath"]forKey:@"Preview"];
			
			NSImage *thumb = nil;
			NSString *thumbPath = [imageRecord objectForKey:@"ThumbPath"];
			if (nil != thumbPath)
			{
				thumb = [[[NSImage alloc] initWithContentsOfFile:thumbPath] autorelease];
			}
			else
			{
				// find poster image from movie as a last resort, since it's slower
				NSString *path = [imageRecord objectForKey:@"ImagePath"];
				QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:path];
				NSError *error = nil;
				QTMovie *movie = [[QTMovie alloc] initWithAttributes:
					[NSDictionary dictionaryWithObjectsAndKeys: 
						ref, QTMovieDataReferenceAttribute,
						[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
						nil] error:&error];
				thumb = [movie betterPosterImage];
				[movie release];
			}
			if (thumb)
			{
				[imageRecord setObject:thumb forKey:@"CachedThumb"];
			}
			else
			{
				[imageRecord setObject:[[NSWorkspace sharedWorkspace]
					iconForAppWithBundleIdentifier:@"com.apple.quicktimeplayer"]
										forKey:@"CachedThumb"];
			}
			
			//swap the keyword index to names
			NSArray *keywords = [imageRecord objectForKey:@"Keywords"];
			if ([keywords count] > 0) {
				NSEnumerator *keywordEnum = [keywords objectEnumerator];
				NSString *keywordKey;
				NSMutableArray *realKeywords = [NSMutableArray array];
				
				while (keywordKey = [keywordEnum nextObject]) {
					NSString *actualKeyword = [keywordMap objectForKey:keywordKey];
					[realKeywords addObject:actualKeyword];
				}
				
				NSMutableDictionary *mutatedKeywordRecord = [NSMutableDictionary dictionaryWithDictionary:imageRecord];
				[mutatedKeywordRecord setObject:realKeywords forKey:@"iMediaKeywords"];
				[imageRecord setObject:mutatedKeywordRecord forKey:key];
			}
		}
		[lib setAttribute:newPhotolist forKey:@"Movies"];
		if (hasMovies) // only display albums that have movies.... what happens when a child album has a movie, but the parent doesn't?
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
		
		[lib release];
	}
	
	if ([[root valueForKey:@"Movies"] count] == 0)
	{
		[root release];
		return nil;
	}
	
	return [root autorelease];
}

@end
