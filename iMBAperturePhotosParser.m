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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import "iMBAperturePhotosParser.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"


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
	
	//	un-comment this line to use see the Aperture library in your iMedia browser:
	[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:nil])
	{
		CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",
															(CFStringRef)@"com.apple.iApps");
		
		NSArray *libraries = [(NSArray *)iApps autorelease];
		NSEnumerator *e = [libraries objectEnumerator];
		NSString *cur;
		
		while (cur = [e nextObject]) {
			[self watchFile:cur];
		}
	}
	return self;
}


- (NSImage*) iconForType: (NSString*) name 
{
	// '12' ???
	// cp: I found icons for a 'smart journal' or a 'smart book' but no menu command to create on.
	
	if ([name isEqualToString:@"1"]) // album
		return [NSImage imageResourceNamed:@"Project_I_Album.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"2"]) // smart album
		return [NSImage imageResourceNamed:@"Project_I_SAlbum.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"3"]) // library **** ... 200X	
		return [NSImage imageResourceNamed:@"List_Icons_LibrarySAlbum.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"4"]) // project
		return [NSImage imageResourceNamed:@"Project_I_Project.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"5"]) // library (top level)		
		return [NSImage imageResourceNamed:@"List_Icons_Library.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"6"]) // folder		
		return [NSImage imageResourceNamed:@"Project_I_Folder.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"7"]) // sub-folder of project
		return [NSImage imageResourceNamed:@"Project_I_ProjectFolder.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"8"]) // book		
		return [NSImage imageResourceNamed:@"Project_I_Book.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"9"]) // web gallery		
		return [NSImage imageResourceNamed:@"Project_I_WebGallery.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"10"]) // web journal		
		return [NSImage imageResourceNamed:@"Project_I_WebJournal.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"11"]) // light	table	
		return [NSImage imageResourceNamed:@"Project_I_LightTable.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"13"]) // smart web gallery		
		return [NSImage imageResourceNamed:@"Project_I_SWebGallery.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"98"]) // library
		return [NSImage imageResourceNamed:@"AppIcon.icns" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"99"]) // library (knot holding all images)
		return [NSImage imageResourceNamed:@"List_Icons_Library.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];

	return [NSImage imageResourceNamed:@"Project_I_Album.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
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
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	[root setName:LocalizedStringInThisBundle(@"Aperture", @"Aperture")];
	[root setIconName:@"com.apple.Aperture"];
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
	
	NSMutableDictionary *library = [NSMutableDictionary dictionary];
	
	//	Find all Aperture libraries
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",
														(CFStringRef)@"com.apple.iApps");
	
	//	Iterate over libraries, pulling dictionary from contents and adding to array for processing;
	NSArray *libraries = [((NSArray *)iApps) autorelease];
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			[library addEntriesFromDictionary:db];
		}
	}
	
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
		
		//	'99': library knot holding all images, not just the "top of the stack" images
		#ifndef SHOW_ALL_IMAGES_FOLDER
			if ([[albumRec objectForKey:@"Album Type"] isEqualToString:@"99"]) continue;
		#endif
		
		iMBLibraryNode *lib = [[iMBLibraryNode alloc] init];
		[lib setName:[albumRec objectForKey:@"AlbumName"]];
		[lib setIcon:[self iconForType:[albumRec objectForKey:@"Album Type"]]];
		
		NSNumber *aid = [albumRec objectForKey:@"AlbumId"];
		#ifndef SHOW_TOP_LEVEL_APERTURE_KNOT
			if ([aid longValue] == 1) continue;
		#endif
			
		// cp: Aperture does have albumID's so do we need the fake?
		if (!aid)
		{
			aid = [NSNumber numberWithInt:fakeAlbumID];
			fakeAlbumID++;
		}
		[lib setAttribute:aid forKey:@"AlbumId"];
		
		NSMutableArray *newPhotolist = [NSMutableArray array];
		NSEnumerator *pictureItemsEnum = [[albumRec objectForKey:@"KeyList"] objectEnumerator];
		NSString *key;
		
		while (key = [pictureItemsEnum nextObject])
		{
			NSMutableDictionary *imageRecord = [[[imageRecords objectForKey:key] mutableCopy] autorelease];
			
			if ([imageRecord objectForKey:@"MediaType"] && ![[imageRecord objectForKey:@"MediaType"] isEqualToString:@"Image"])
			{
				continue;
			}
				
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
		}
		[lib setAttribute:newPhotolist forKey:@"Images"];
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
				NSLog(@"Failed to find parent node");
			[parent addItem:lib];
		}
		else
		{
			[root addItem:lib];
		}
		
		[lib release];
	}
	
	return [albums count] ? root : nil;
}

@end
