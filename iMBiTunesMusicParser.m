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


#import "iMBiTunesMusicParser.h"
#import "iMBLibraryNode.h"
#import "iMediaConfiguration.h"
#import "NSString+iMedia.h"

#define RECURSIVE_PARSEDATABASE 1

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
		_version = 0;
		
		//Find all iTunes libraries
		CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",
															(CFStringRef)@"com.apple.iApps");
		
		NSArray *libraries = (NSArray *)iApps;
		NSEnumerator *e = [libraries objectEnumerator];
		NSString *cur;
		
		while (cur = [e nextObject]) {
			[self watchFile:[cur pathForURLString]];
		}
		[libraries autorelease];
	}
	return self;
}

- (NSString *)iconNameForPlaylist:(NSString*)name
{	
	if (_version < 7)
	{
		if ([name isEqualToString:@"Library"])
			return @"itunes-icon-library";
		else if ([name isEqualToString:@"Party Shuffle"])
			return @"itunes-icon-partyshuffle";
		else if ([name isEqualToString:@"Purchased Music"])
			return @"itunes-icon-playlist-purchased";
		else if ([name isEqualToString:@"Podcasts"])
			return @"itunes-icon-podcasts";
	}
	else
	{
		if ([name isEqualToString:@"Library"])
			return @"itunes-icon-music";
		else if ([name isEqualToString:@"Party Shuffle"])
			return @"itunes-icon-partyshuffle7";
		else if ([name isEqualToString:@"Purchased Music"])
			return @"itunes-icon-purchased7";
		else if ([name isEqualToString:@"Podcasts"])
			return @"itunes-icon-podcasts7";
		else if ([name isEqualToString:@"Audiobooks"])
			return @"itunes-icon-audiobooks";
	}
	
	return @"MBiTunesPlaylist";
}

- (void)populateNode:(iMBLibraryNode *)inNode withTracks:(NSDictionary *)inTracks fromPlaylist:(NSDictionary *)inPlaylist
{
	if (inNode != nil && inPlaylist != nil)
	{
		NSImage *songIcon = [[NSWorkspace sharedWorkspace] iconForFileType:@"mp3"];
		NSImage *drmIcon = [[NSWorkspace sharedWorkspace] iconForFileType:@"m4p"];

		NSArray *playlistItems = [inPlaylist objectForKey:@"Playlist Items"];
		NSMutableArray *playlistTracks = [NSMutableArray array];
		NSMutableDictionary *track;
		NSString *key;
						
		if (playlistItems)
		{
			unsigned int i,n = [playlistItems count];
			
			for (i=0; i<n; i++)
			{
				key = [[[playlistItems objectAtIndex:i] objectForKey:@"Track ID"] stringValue];
				
				if (track = [NSMutableDictionary dictionaryWithDictionary:[inTracks objectForKey:key]])
				{
					if ([track objectForKey:@"Name"] && [[track objectForKey:@"Location"] length] > 0)
					{
						[track setObject:[track objectForKey:@"Location"] forKey:@"Preview"];
						if ([[track objectForKey:@"Protected"] boolValue]) [track setObject:drmIcon forKey:@"Icon"];
						else [track setObject:songIcon forKey:@"Icon"];
							
						[playlistTracks addObject:track];	
					}
				}
			}
		}
		
		[inNode setAttribute:playlistTracks forKey:@"Tracks"];
	}
}

- (iMBLibraryNode *)parseDatabase:(NSMutableDictionary *)inLibrary forPlaylistWithKey:(NSString *)inKey name:(NSString *)inName iconName:(NSString *)inIconName
{
	// Create a node for the playlist with the specified key...
	
	iMBLibraryNode *node = nil;
	NSDictionary *tracks = nil;
	NSArray *playlists = nil;
	NSDictionary *playlist = nil;
	 
	if (inLibrary)
	{
		if (tracks = [inLibrary objectForKey:@"Tracks"])
		{
			if (playlists = [inLibrary objectForKey:@"Playlists"])
			{
				unsigned int i,n = [playlists count];
				
				for (i=0; i<n; i++)
				{
					if (playlist = [playlists objectAtIndex:i])
					{
						if ([playlist objectForKey:inKey])
						{
							node = [[[iMBLibraryNode alloc] init] autorelease];
							[node setName:inName];
							[node setIconName:inIconName];
							[node setParser:self];
							
							[self populateNode:node withTracks:tracks fromPlaylist:playlist];
						}
					}
				}
			}
		}
	}
	
	return node;	
}

- (NSMutableArray *)parseDatabase:(NSMutableDictionary *)inLibrary forPlaylistsWithParentID:(NSString *)inParentID
{
	// Create nodes for playlists at the specified level...
	
	NSMutableArray *nodes = [NSMutableArray array];
	iMBLibraryNode *node = nil;
	NSDictionary *tracks = nil;
	NSArray *playlists = nil;
	NSDictionary *playlist = nil;
	 
	if (inLibrary)
	{
		if (tracks = [inLibrary objectForKey:@"Tracks"])
		{
			if (playlists = [inLibrary objectForKey:@"Playlists"])
			{
				unsigned int i,n = [playlists count];
				
				// First look for folders...
				
				for (i=0; i<n; i++)
				{
					if (playlist = [playlists objectAtIndex:i])
					{
						if ([playlist objectForKey:@"Folder"]) 
						{
							NSString *selfID = [playlist objectForKey:@"Playlist Persistent ID"];
							NSString *parentID = [playlist objectForKey:@"Parent Persistent ID"];

							if (inParentID==nil && parentID==nil || parentID!=nil && [parentID isEqualToString:inParentID])
							{
								node = [[[iMBLibraryNode alloc] init] autorelease];
								[node setName:[playlist objectForKey:@"Name"]];
								[node setIconName:@"itunes-icon-folder7"];
								[node setParser:self];
								
								[node setAllItems:[self parseDatabase:inLibrary forPlaylistsWithParentID:selfID]];
								if (node) [nodes addObject:node];
							}
						}
					}
				}
				
				// Next look for smart playlists...
				
				for (i=0; i<n; i++)
				{
					if (playlist = [playlists objectAtIndex:i])
					{
						NSString *parentID = [playlist objectForKey:@"Parent Persistent ID"];

						if (inParentID==nil && parentID==nil || parentID!=nil && [parentID isEqualToString:inParentID])
						{
							if ([playlist objectForKey:@"Folder"] == nil &&
								[playlist objectForKey:@"Smart Info"] != nil && 
								[playlist objectForKey:@"Master"] == nil &&
								[playlist objectForKey:@"Music"] == nil &&
								[playlist objectForKey:@"Podcasts"] == nil &&
								[playlist objectForKey:@"Audiobooks"] == nil &&
								[playlist objectForKey:@"Purchased Music"] == nil &&
								[playlist objectForKey:@"Party Shuffle"] == nil &&
								[playlist objectForKey:@"Movies"] == nil &&
								[playlist objectForKey:@"Music Videos"] == nil &&
								[playlist objectForKey:@"TV Shows"] == nil)
							{
								node = [[[iMBLibraryNode alloc] init] autorelease];
								[node setName:[playlist objectForKey:@"Name"]];
								if (_version == 7) [node setIconName:@"itunes-icon-playlist-smart7"];
								else [node setIconName:@"itunes-icon-playlist-smart"];
								[node setParser:self];
								
								[self populateNode:node withTracks:tracks fromPlaylist:playlist];
								if (node) [nodes addObject:node];
							}
						}
					}
				}

				// Finally look for normal playlists...
				
				for (i=0; i<n; i++)
				{
					if (playlist = [playlists objectAtIndex:i])
					{
						NSString *parentID = [playlist objectForKey:@"Parent Persistent ID"];

						if (inParentID==nil && parentID==nil || parentID!=nil && [parentID isEqualToString:inParentID])
						{
							if ([playlist objectForKey:@"Master"] == nil &&
								[playlist objectForKey:@"Music"] == nil &&
								[playlist objectForKey:@"Podcasts"] == nil &&
								[playlist objectForKey:@"Audiobooks"] == nil &&
								[playlist objectForKey:@"Purchased Music"] == nil &&
								[playlist objectForKey:@"Party Shuffle"] == nil &&
								[playlist objectForKey:@"Movies"] == nil &&
								[playlist objectForKey:@"Music Videos"] == nil &&
								[playlist objectForKey:@"TV Shows"] == nil &&
								[playlist objectForKey:@"Folder"] == nil &&
								[playlist objectForKey:@"Smart Info"] == nil)
							{
								node = [[[iMBLibraryNode alloc] init] autorelease];
								[node setName:[playlist objectForKey:@"Name"]];
								if (_version == 7) [node setIconName:@"itunes-icon-playlist-normal7"];
								else [node setIconName:@"itunes-icon-playlist-normal"];
								[node setParser:self];
								
								[self populateNode:node withTracks:tracks fromPlaylist:playlist];
								if (node) [nodes addObject:node];
							}
						}
					}
				}
			}
		}
	}
	
	return nodes;	
}

- (iMBLibraryNode *)parseDatabase
{
	// Read the iTunes database from the XML file...
	
	iMBLibraryNode *root = nil;
	NSMutableDictionary *musicLibrary = [NSMutableDictionary dictionary];
	
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",(CFStringRef)@"com.apple.iApps");
	NSArray *libraries = [(NSArray *)iApps autorelease];
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			_version = [[db objectForKey:@"Application Version"] intValue];
			[musicLibrary addEntriesFromDictionary:db];
		}
	}

	if ([musicLibrary count])
	{
		iMBLibraryNode *node;
		NSString *name,*icon;
		
		// Create a root node for iTunes...
		
		root = [[[iMBLibraryNode alloc] init] autorelease];
		[root setName:LocalizedStringInIMedia(@"iTunes", @"iTunes")];
		[root setIconName:@"com.apple.iTunes:"];
		[root setParser:self];
		
		#if RECURSIVE_PARSEDATABASE
	
		// Create standard nodes for iTunes 7...
		
		if (_version == 7)
		{
			name = LocalizedStringInIMedia(@"Music", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-music";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Music" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Podcasts", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-podcasts7";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Podcasts" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Audiobooks", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-audiobooks";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Audiobooks" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Purchased", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-purchased7";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Purchased Music" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Party Shuffle", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-partyshuffle7";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Party Shuffle" name:name iconName:icon];
			if (node) [root addItem:node];
		}
		
		// Create standard nodes for older iTunes versions...
		
		else
		{
			name = LocalizedStringInIMedia(@"Library", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-library";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Master" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Podcasts", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-podcasts";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Podcasts" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Purchased", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-purchased";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Purchased Music" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Party Shuffle", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-partyshuffle";
			node = [self parseDatabase:musicLibrary forPlaylistWithKey:@"Party Shuffle" name:name iconName:icon];
			if (node) [root addItem:node];
		}
		
		// Create user nodes...
		
		NSEnumerator *nodes = [[self parseDatabase:musicLibrary forPlaylistsWithParentID:nil] objectEnumerator];
		while (node = [nodes nextObject]) [root addItem:node];
		
		#else
	
		// purge empty entries here....
		
		int x = 0;
		
		iMBLibraryNode *library = [[iMBLibraryNode alloc] init];
		iMBLibraryNode *podcastLib = [[iMBLibraryNode alloc] init];
		iMBLibraryNode *partyShuffleLib = [[iMBLibraryNode alloc] init];
		iMBLibraryNode *purchasedLib = [[iMBLibraryNode alloc] init];
		NSMutableArray *smartPlaylists = [NSMutableArray array];
		
		if (_version<7) [library setName:LocalizedStringInIMedia(@"Library", @"Library as titled in iTunes source list")];
		else [library setName:LocalizedStringInIMedia(@"Music", @"Library as titled in iTunes source list")];
		[library setIconName:[self iconNameForPlaylist:@"Library"]]; //@"MBiTunesLibrary"];
		[library setParser:self];
		
		[podcastLib setName:LocalizedStringInIMedia(@"Podcasts", @"Podcasts as titled in iTunes source list")];
		[podcastLib setIconName:[self iconNameForPlaylist:@"Podcasts"]]; //@"MBiTunesPodcast"];
		[podcastLib setParser:self];
		
		[partyShuffleLib setName:LocalizedStringInIMedia(@"Party Shuffle", @"Party Shuffle as titled in iTunes source list")];
		[partyShuffleLib setIconName:[self iconNameForPlaylist:@"Party Shuffle"]]; //@"MBiTunesPartyShuffle"];
		[partyShuffleLib setParser:self];
		
		[purchasedLib setName:LocalizedStringInIMedia(@"Purchased", @"Purchased folder as titled in iTunes source list")];
		[purchasedLib setIconName:[self iconNameForPlaylist:@"Purchased Music"]]; //@"MBiTunesPurchasedPlaylist"];
		[purchasedLib setParser:self];
		
		int playlistCount = [[musicLibrary objectForKey:@"Playlists"] count];
		
		NSImage* songIcon = [[NSWorkspace sharedWorkspace] iconForFileType:@"mp3"];
		NSImage* drmIcon = [[NSWorkspace sharedWorkspace] iconForFileType:@"m4p"];
		
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
			else if ([playlistRecord objectForKey:@"Purchased Music"] && [[playlistRecord objectForKey:@"Purchased Music"] boolValue])
			{
				node = purchasedLib;
			}
			else if ([playlistRecord objectForKey:@"Movies"] && [[playlistRecord objectForKey:@"Movies"] boolValue])
			{
				continue;
			}
			else if ([playlistRecord objectForKey:@"Videos"] && [[playlistRecord objectForKey:@"Videos"] boolValue])
			{
				continue;
			}
			else if ([playlistRecord objectForKey:@"TV Shows"] && [[playlistRecord objectForKey:@"TV Shows"] boolValue])
			{
				continue;
			}
			else if ([playlistRecord objectForKey:@"Music Videos"] && [[playlistRecord objectForKey:@"Music Videos"] boolValue])
			{
				continue;
			}
			else
			{
				node = [[iMBLibraryNode alloc] init];
				[node setName:objectName];
				[node setParser:self];
				
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
	
		#endif
	}
	
	return root;
}

@end
