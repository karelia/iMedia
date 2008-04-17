/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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


#import "iMBiTunesMusicParser.h"
#import "iMBLibraryNode.h"
#import "iMediaConfiguration.h"
#import "iMedia.h"


@implementation iMBiTunesMusicParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	    
	[iMediaConfiguration registerParser:[self class] forMediaType:@"music"];

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
	iMBLibraryNode *root = nil;
	NSMutableDictionary *musicLibrary = [NSMutableDictionary dictionary];
	
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",
														(CFStringRef)@"com.apple.iApps");
	NSArray *libraries = [(NSArray *)iApps autorelease];
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			[musicLibrary addEntriesFromDictionary:db];
		}
	}
	if ([musicLibrary count])
	{
		// purge empty entries here....
		
		int x = 0;
		
		root = [[[iMBLibraryNode alloc] init] autorelease];
		[root setName:LocalizedStringInThisBundle(@"iTunes", @"iTunes")];
		[root setIconName:@"com.apple.iTunes:"];
		
		iMBLibraryNode *library = [[iMBLibraryNode alloc] init];
		iMBLibraryNode *podcastLib = [[iMBLibraryNode alloc] init];
		iMBLibraryNode *partyShuffleLib = [[iMBLibraryNode alloc] init];
		iMBLibraryNode *purchasedLib = [[iMBLibraryNode alloc] init];
		NSMutableArray *smartPlaylists = [NSMutableArray array];
		
		[library setName:LocalizedStringInThisBundle(@"Library", @"Library as titled in iTunes source list")];
		[library setIconName:@"MBiTunesLibrary"];
		
		[podcastLib setName:LocalizedStringInThisBundle(@"Podcasts", @"Podcasts as titled in iTunes source list")];
		[podcastLib setIconName:@"MBiTunesPodcast"];
		
		[partyShuffleLib setName:LocalizedStringInThisBundle(@"Party Shuffle", @"Party Shuffle as titled in iTunes source list")];
		[partyShuffleLib setIconName:@"MBiTunesPartyShuffle"];
		
		[purchasedLib setName:LocalizedStringInThisBundle(@"Purchased", @"Purchased folder as titled in iTunes source list")];
		[purchasedLib setIconName:@"MBiTunesPurchasedPlaylist"];
		
		int playlistCount = [[musicLibrary objectForKey:@"Playlists"] count];
		
		NSBundle *bndl = [NSBundle bundleForClass:[self class]];
		NSString *iconPath = [bndl pathForResource:@"MBiTunes4Song" ofType:@"png"];
		NSImage *songIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
		iconPath = [bndl pathForResource:@"iTunesDRM" ofType:@"png"];
		NSImage *drmIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
		
		for (x=0;x<playlistCount;x++)
		{
			NSDictionary *playlistRecord = [[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x];
			NSString * objectName = [playlistRecord objectForKey:@"Name"];
			
			iMBLibraryNode *node = nil;
			if ([playlistRecord objectForKey:@"Master"] && [[playlistRecord objectForKey:@"Master"] boolValue])
			{
				node = library;
			}
			else if ([playlistRecord objectForKey:@"Podcasts"] && [[playlistRecord objectForKey:@"Podcasts"] boolValue])
			{
				node = podcastLib;		
			}
			else if ([playlistRecord objectForKey:@"Party Shuffle"] && [[playlistRecord objectForKey:@"Party Shuffle"] boolValue])
			{
				node = partyShuffleLib;
			}
			else if ([playlistRecord objectForKey:@"Videos"] && [[playlistRecord objectForKey:@"Videos"] boolValue])
			{
				continue;
			}
			else if ([playlistRecord objectForKey:@"Purchased Music"] && [[playlistRecord objectForKey:@"Purchased Music"] boolValue])
			{
				node = purchasedLib;
			}
			else
			{
				node = [[iMBLibraryNode alloc] init];
				[node setName:objectName];
				if ([[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Smart Info"])
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
			
			NSMutableArray *newPlaylist = [NSMutableArray array];
			NSArray *libraryItems = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Playlist Items"];
			unsigned int i;
			for (i=0; i<[libraryItems count]; i++)
			{
				NSDictionary * tracksDictionary = [musicLibrary objectForKey:@"Tracks"];
				
				// This seems to be a mutable dictionary, so we can change it.
				NSMutableDictionary *playlistTrack = (NSMutableDictionary *)[tracksDictionary objectForKey:[[[libraryItems objectAtIndex:i] objectForKey:@"Track ID"] stringValue]];

				//[((NSMutableDictionary *)playlist) setObject:@"foo" forKey:@"bar"];	// TEST
				if ([playlistTrack objectForKey:@"Name"] && [[playlistTrack objectForKey:@"Location"] length] > 0)
				{
					if ([[playlistTrack objectForKey:@"Protected"] boolValue])
					{
						[playlistTrack setObject:drmIcon forKey:@"Icon"];
					}
					else
					{
						[playlistTrack setObject:songIcon forKey:@"Icon"];
					}
					[playlistTrack setObject:[playlistTrack objectForKey:@"Location"] forKey:@"Preview"];
					[newPlaylist addObject:playlistTrack];
				}
			}
			[node setAttribute:newPlaylist forKey:@"Tracks"];
		}
		[songIcon release];
		[root insertItem:library atIndex:0];
		[root insertItem:podcastLib atIndex:1];
		[root insertItem:partyShuffleLib atIndex:2];
		[root insertItem:purchasedLib atIndex:3];
		
		//insert the smart playlist
		unsigned int i;
		for (i = 0; i < [smartPlaylists count]; i++)
		{
			[root insertItem:[smartPlaylists objectAtIndex:i] atIndex:4 + i];
		}
		
		[library release];
		[podcastLib release];
		[partyShuffleLib release];
		
		[root setFilterDuplicateKey:@"Location" forAttributeKey:@"Tracks"];
	}
	return root;
}

@end
