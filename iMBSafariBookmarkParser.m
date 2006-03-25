//
//  iMBSafariBookmarkParser.m
//  iMediaBrowse
//
//  Created by Greg Hulands on 24/03/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "iMBSafariBookmarkParser.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import <WebKit/WebKit.h>

@implementation iMBSafariBookmarkParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"links"];
	
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:[NSString stringWithFormat:@"%@/Library/Safari/Bookmarks.plist", NSHomeDirectory()]])
	{
		
	}
	return self;
}

- (iMBLibraryNode *)recursivelyParseItem:(NSDictionary *)item
{
	iMBLibraryNode *parsed = [[iMBLibraryNode alloc] init];
	
	if ([item objectForKey:@"Title"])
	{
		[parsed setName:[item objectForKey:@"Title"]];
		[parsed setIconName:@"folder"];
		// this is a group and we need to parse the children
		NSEnumerator *e = [[item objectForKey:@"Children"] objectEnumerator];
		NSDictionary *cur;
		
		while (cur = [e nextObject])
		{
			[parsed addItem:[self recursivelyParseItem:cur]];
		}
	}
	else 
	{
		[parsed setName:[[item objectForKey:@"URIDictionary"] objectForKey:@"title"]];
		[parsed setAttribute:[item objectForKey:@"URLString"] forKey:@"URL"];
		
		WebHistoryItem *web = [[WebHistoryItem alloc] initWithURLString:[item objectForKey:@"URLString"]
																  title:[[item objectForKey:@"URIDictionary"] objectForKey:@"title"]
												lastVisitedTimeInterval:60];
		[parsed setIcon:[web icon]];
		[web release];
	}
	
	return parsed;
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *library = [[iMBLibraryNode alloc] init];
	NSDictionary *xml = [NSDictionary dictionaryWithContentsOfFile:[self databasePath]];
	
	[library setName:NSLocalizedString(@"Safari", @"Safari")];
	
	NSEnumerator *groupEnum = [[xml objectForKey:@"Children"] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [groupEnum nextObject])
	{
		[library addItem:[self recursivelyParseItem:cur]];
	}
	return library;
}

@end
