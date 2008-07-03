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


#import "iMBAperturePhotosParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"

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
		CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",
															(CFStringRef)@"com.apple.iApps");
		
		NSArray *libraries = [(NSArray *)iApps autorelease];
		NSEnumerator *e = [libraries objectEnumerator];
		NSString *cur;
		
		while (cur = [e nextObject]) {
			[self watchFile:[cur pathForURLString]];
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
	{
		NSImage* icon = [NSImage imageResourceNamed:@"Project_I_WebPage.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:nil];
		if (icon==nil) icon = [NSImage imageResourceNamed:@"Project_I_WebGallery.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
		return icon;
	}
	else if ([name isEqualToString:@"10"]) // web journal		
		return [NSImage imageResourceNamed:@"Project_I_WebJournal.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"11"]) // light	table	
		return [NSImage imageResourceNamed:@"Project_I_LightTable.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"13"]) // smart web gallery		
		return [NSImage imageResourceNamed:@"Project_I_SWebGallery.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
	else if ([name isEqualToString:@"97"]) // library
		return [NSImage imageResourceNamed:@"Project_I_Projects.tiff" fromApplication:@"com.apple.Aperture" fallbackTo:@"folder"];
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


- (iMBLibraryNode *)parseOneDatabaseWithContentsOfURL:(NSURL *)url
{
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	if (myHasMultipleLibraries)
	{
		NSLog(@"%@", url);
		[root setName:[NSString stringWithFormat:@"%@ (%@)", LocalizedStringInIMedia(@"Aperture", @"Aperture"), [[[[url path] stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension]]];
	}
	else
	{
		[root setName:LocalizedStringInIMedia(@"Aperture", @"Aperture")];
	}
	[root setIconName:@"com.apple.Aperture:"];
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Images"];
	
    NSDictionary *library = [NSDictionary dictionaryWithContentsOfURL:url];
	
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
			
            // It's always possible that the record might not exist. Can't fully trusty
            // the integrity of the librrary
            if (!imageRecord)
            {
                NSLog(@"IMBAperturePhotosParser: no image record found with key %@", key);
                continue;
            }
            
			if ([imageRecord objectForKey:@"MediaType"] && ![[imageRecord objectForKey:@"MediaType"] isEqualToString:@"Image"])
			{
				continue;
			}
			
			//	Better have the modification date than no date.
			if (![imageRecord objectForKey:@"DateAsTimerInterval"]) 
			{
				NSNumber* date = [imageRecord objectForKey:@"ModDateAsTimerInterval"];
				if (date) [imageRecord setObject:date forKey:@"DateAsTimerInterval"];
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

// Note: we do NOT implement parseDatabase; we implement this to return multiple top level nodes
- (NSArray *)nodesFromParsingDatabase
{
	NSMutableArray *libraryNodes = [NSMutableArray array];
	
	//	Find all Aperture libraries
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",
														(CFStringRef)@"com.apple.iApps");
	
	//	Iterate over libraries, pulling dictionary from contents and adding to array for processing;
	NSArray *libraries = [((NSArray *)iApps) autorelease];
	myHasMultipleLibraries = [libraries count] > 1;
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
        iMBLibraryNode *library = [self parseOneDatabaseWithContentsOfURL:[NSURL URLWithString:cur]];
		if (library) {
			[library setPrioritySortOrder:1];

			[libraryNodes addObject:library];
		}
	}
    
    return [libraryNodes count] ? libraryNodes : nil;
}

@end
