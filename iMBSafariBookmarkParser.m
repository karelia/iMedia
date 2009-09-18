/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#import "iMBSafariBookmarkParser.h"
#import <WebKit/WebKit.h>
#import "WebIconDatabase.h"
#import "NSImage+iMedia.h"
#import "IMBParserController.h"

@implementation iMBSafariBookmarkParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Force the shared instance to be build on main thread - some webkit versions
	// seem to complain when it's not the case
	[WebIconDatabase performSelectorOnMainThread:@selector(sharedIconDatabase)
									  withObject:nil
								   waitUntilDone:YES];
	
	[IMBParserController registerParserClass:self forMediaType:@"links"];

	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:[NSString stringWithFormat:@"%@/Library/Safari/Bookmarks.plist", NSHomeDirectory()]])
	{
		mySafariFaviconCache = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}

- (void)dealloc
{
	[mySafariFaviconCache release];
	[super dealloc];
}

- (IMBNode *)recursivelyParseItem:(NSDictionary *)item
{
	IMBNode *parsed = [[[IMBNode alloc] init] autorelease];
	[parsed setParserClassName:NSStringFromClass([self class])];
//	[parsed setWatchedPath:_database];
	NSArray *collectionArray = [item objectForKey:@"Children"];		// default group of children, if this is a collection
	
	if ([[item objectForKey:@"Title"] isEqualToString:@"BookmarksBar"])
	{
        [parsed setIdentifier:@"Bookmarks Bar"];
		[parsed setName:NSLocalizedStringWithDefaultValue(
														  @"Bookmarks Bar",
														  nil,IMBBundle(),
														  @"Bookmarks Bar",
														  @"Bookmarks Bar as titled in Safari")];
		
		
		[parsed setIconName:@"SafariBookmarksBar"];
	}
	else if ([[item objectForKey:@"Title"] isEqualToString:@"BookmarksMenu"])
	{
        [parsed setIdentifier:@"Bookmarks Menu"];
		[parsed setName:NSLocalizedStringWithDefaultValue(
														  @"Bookmarks Menu",
														  nil,IMBBundle(),
														  @"Bookmarks Menu",
														  @"Bookmarks Menu as titled in Safari")];
		[parsed setIconName:@"SafariBookmarksMenu"];
	}
	else if ([[item objectForKey:@"Title"] isEqualToString:@"Address Book"] ||
			 [[item objectForKey:@"Title"] isEqualToString:@"Bonjour"] ||
			 [[item objectForKey:@"Title"] isEqualToString:@"History"] ||
			 [[item objectForKey:@"Title"] isEqualToString:@"All RSS Feeds"])
	{
		return nil;
	}
	else if (nil == [item objectForKey:@"Title"] && nil != [item objectForKey:@"URIDictionary"])	// actual bookmark
	{
		NSDictionary *URIDictionary = [item objectForKey:@"URIDictionary"];
        [parsed setIdentifier:[URIDictionary objectForKey:@"title"]];
		[parsed setName:[URIDictionary objectForKey:@"title"]];
		[parsed setIconName:@"com.apple.Safari"];
		
		// This is the item, so fake things so that this is treated as a collection
		collectionArray = [NSArray arrayWithObject:item];
	}
	else if (nil != [item objectForKey:@"Title"])
	{
		[parsed setIdentifier:[item objectForKey:@"Title"]];
		[parsed setName:[item objectForKey:@"Title"]];
		[parsed setIcon:[NSImage genericFolderIcon]];
	}
	
	NSMutableArray *links = [NSMutableArray array];
	NSEnumerator *e = [collectionArray objectEnumerator];
	NSDictionary *cur;
	[[NSUserDefaults standardUserDefaults] setObject:@"~/Library/Safari/Icons" forKey:WebIconDatabaseDirectoryDefaultsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"WebBookmarkType"] isEqualToString:@"WebBookmarkTypeList"])
		{
			IMBNode *child = [self recursivelyParseItem:cur];
			if (child)
			{
				[parsed addItem:child];
			}
		}
		else 
		{
			NSMutableDictionary *link = [NSMutableDictionary dictionary];
			[link setObject:[[cur objectForKey:@"URIDictionary"] objectForKey:@"title"]
					 forKey:@"Name"];
			[link setObject:[cur objectForKey:@"URLString"] forKey:@"URL"];
			
			NSImage *icon = [[WebIconDatabase sharedIconDatabase] iconForURL:[item objectForKey:@"URLString"]
																	withSize:NSMakeSize(16,16)
																	   cache:YES];
			
			if (icon)
			{
				[link setObject:icon forKey:@"Icon"];
			}
			id nameWithIcon = [self name:[[cur objectForKey:@"URIDictionary"] objectForKey:@"title"]
							   withImage:icon];
			[link setObject:nameWithIcon forKey:@"NameWithIcon"];
			[links addObject:link];
		}
	}
	[parsed setAttribute:links forKey:@"Links"];
	
	return parsed;
}

- (IMBNode *)parseDatabase
{
	NSString *path = [self databasePath];
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
	
	IMBNode *library = [[[IMBNode alloc] init] autorelease];
	NSDictionary *xml = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[library setName:NSLocalizedStringWithDefaultValue(
													   @"Safari",
													   nil,IMBBundle(),
													   @"Safari",
													   @"Safari application name")];
	[library setIconName:@"com.apple.Safari"];
	[library setIdentifier:@"Safari"];
	[library setParserClassName:NSStringFromClass([self class])];
	[library setWatchedPath:_database];
	
	NSEnumerator *groupEnum = [[xml objectForKey:@"Children"] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [groupEnum nextObject])
	{
		
		IMBNode *child = [self recursivelyParseItem:cur];
		if (child)
		{
			[library addItem:child];
		}
	}
	return library;
}


@end
