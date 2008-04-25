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


#import "iMBiTunesVideoParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "QTMovie+iMedia.h"
#import "iMedia.h"

#import <QTKit/QTKit.h>

@implementation iMBiTunesVideoParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[iMediaConfiguration registerParser:[self class] forMediaType:@"movies"];

	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:nil])
	{
		//Find all iTunes libraries
		CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",
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

- (NSString *)iconNameForPlaylist:(NSString*)name{	
	if ([name isEqualToString:@"Library"])
		return @"MBiTunesLibrary";
	else if ([name isEqualToString:@"Party Shuffle"])
		return @"MBiTunesPartyShuffle";
	else if ([name isEqualToString:@"Purchased Music"])
		return @"MBiTunesPurchasedPlaylist";
	else if ([name isEqualToString:@"Podcasts"])
		return @"MBiTunesPodcast";
	else
		return @"MBiTunesPlaylist";
}

- (iMBLibraryNode *)parseDatabase
{
    // Load the iTunes Library dict 
	NSMutableDictionary *iTunesLibrary = [NSMutableDictionary dictionary];
	
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",
														(CFStringRef)@"com.apple.iApps");
	NSArray *libraries = [(NSArray *)iApps autorelease];
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			[iTunesLibrary addEntriesFromDictionary:db];
		}
	}
	
    // Create the root node
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"iTunes", @"iTunes")];
	[root setIconName:@"com.apple.iTunes"];
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Movies"];
	
    // Create default subnodes
	iMBLibraryNode *library = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *podcastLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *partyShuffleLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *moviesLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *purchasedLib = [[iMBLibraryNode alloc] init];
	NSMutableArray *smartPlaylists = [NSMutableArray array];
	
	[library setName:LocalizedStringInThisBundle(@"Library", @"Library as titled in iTunes source list")];
	[library setIconName:@"MBiTunesLibrary"];
	
	[podcastLib setName:LocalizedStringInThisBundle(@"Podcasts", @"Podcasts as titled in iTunes source list")];
	[podcastLib setIconName:@"MBiTunesPodcast"];
	
	[partyShuffleLib setName:LocalizedStringInThisBundle(@"Party Shuffle", @"Party Shuffle as titled in iTunes source list")];
	[partyShuffleLib setIconName:@"MBiTunesPartyShuffle"];
	
	[moviesLib setName:LocalizedStringInThisBundle(@"Videos", @"Videos as titled in iTunes source list")];
	[moviesLib setIconName:@"iTunesVideo"];
	
	[purchasedLib setName:LocalizedStringInThisBundle(@"Purchased", @"Purchased folder as titled in iTunes source list")];
	[purchasedLib setIconName:@"MBiTunesPurchasedPlaylist"];
	
    // Look through the iTunes playlists for movies
    NSDictionary    *tracksDictionary = [iTunesLibrary objectForKey:@"Tracks"];
    NSArray         *playListDicts = [iTunesLibrary objectForKey:@"Playlists"];
    NSEnumerator    *playListDictEnum = [playListDicts objectEnumerator];
    NSDictionary    *playListDict;
	
    while ((playListDict = [playListDictEnum nextObject]))
	{
        NSAutoreleasePool   *pool = [[NSAutoreleasePool allocWithZone:[self zone]] init];
        NSMutableSet        *addedLocations = [NSMutableSet set];       // for avoiding duplicates
		NSMutableArray      *attributeDicts = [NSMutableArray array];   // The records for the node
		NSArray             *playListTracks = [playListDict objectForKey:@"Playlist Items"];
        NSEnumerator        *tracksEnum = [playListTracks objectEnumerator];
        NSDictionary        *playListTrackDict;
        BOOL                 hasVideos = NO;
        
        while ((playListTrackDict = [tracksEnum nextObject]))
		{
            NSString    *trackId = [[playListTrackDict objectForKey:@"Track ID"] stringValue];
            if (!trackId)
                continue;
            
            NSDictionary    *trackDict = [tracksDictionary objectForKey:trackId];
            NSString        *urlString = [trackDict objectForKey:@"Location"];
            
			if ([trackDict objectForKey:@"Name"] && 
                [[trackDict objectForKey:@"Has Video"] boolValue] &&
				[urlString length] > 0 &&
                ![addedLocations containsObject:urlString]) 
			{
                NSMutableDictionary    *attributeDict = [trackDict mutableCopyWithZone:[self zone]];
                NSURL   *url = [NSURL URLWithString:urlString];
                NSString    *path = [url path];
                if (!path)
                    continue;
                
                [addedLocations addObject:urlString];
				[attributeDict setObject:path forKey:@"ImagePath"];
				[attributeDict setObject:path forKey:@"Preview"];
				[attributeDict setObject:[trackDict objectForKey:@"Name"] forKey:@"Caption"];
				[attributeDicts addObject:attributeDict];
                [attributeDict release];
				hasVideos = YES;
			}
		}
        
		if (hasVideos)
		{
			iMBLibraryNode *node = nil;
            
			if ([[playListDict objectForKey:@"Master"] boolValue])
				node = library;
			else if ([[playListDict objectForKey:@"Podcasts"] boolValue])
				node = podcastLib;		
			else if ([[playListDict objectForKey:@"Party Shuffle"] boolValue])
				node = partyShuffleLib;
			else if ([[playListDict objectForKey:@"Movies"] boolValue])
				node = moviesLib;
			else if ([[playListDict objectForKey:@"Purchased Music"] boolValue])
				node = purchasedLib;
			else
			{   // Create a new node for this playlist
				node = [[iMBLibraryNode alloc] init];
				[node setName:[playListDict objectForKey:@"Name"]];
				if ([playListDict objectForKey:@"Smart Info"])
				{
					[node setIconName:@"photocast_folder"];
					[smartPlaylists addObject:node];
				}
				else
				{
					[node setIconName:[self iconNameForPlaylist:[node name]]];
					[root addItem:node];
				}
				[node release];
			}
			[node setAttribute:attributeDicts forKey:@"Movies"];
		}
        [pool release];
	}
    
	BOOL libraryHasVideos = NO;
	
	if ([library attributeForKey:@"Movies"]) // there is a least one video
	{
		[root insertItem:library atIndex:0];
		libraryHasVideos = YES;
		int idx = 1;
		if ([podcastLib attributeForKey:@"Movies"])
		{
			[root insertItem:podcastLib atIndex:idx];
			idx++;
		}
		if ([moviesLib attributeForKey:@"Movies"])
		{
			[root insertItem:moviesLib atIndex:idx];
			idx++;
		}
		if ([partyShuffleLib attributeForKey:@"Movies"])
		{
			[root insertItem:partyShuffleLib atIndex:idx];
			idx++;
		}
		if ([purchasedLib attributeForKey:@"Movies"])
		{
			[root insertItem:purchasedLib atIndex:idx];
			idx++;
		}
		//insert the smart playlist
		int i;
		for (i = 0; i < [smartPlaylists count]; i++)
		{
			[root insertItem:[smartPlaylists objectAtIndex:i] atIndex:idx + i];
		}
	}
	
	[library release];
	[podcastLib release];
	[partyShuffleLib release];
	[moviesLib release];
    [purchasedLib release];
    
	if (libraryHasVideos)
	{
		return [root autorelease];
	}
	else
	{
		[root release];
		return nil;
	}
}

@end
