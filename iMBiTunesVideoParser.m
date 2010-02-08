/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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
#import "NSString+iMedia.h"

#import <QTKit/QTKit.h>

#define RECURSIVE_PARSEDATABASE 1

#ifndef NSMakeCollectable
#define NSMakeCollectable(x) (id)(x)
#endif

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

- (BOOL)populateNode:(iMBLibraryNode *)inNode withTracks:(NSDictionary *)inTracks fromPlaylist:(NSDictionary *)inPlaylist
{
	BOOL hasVideos = NO;

	if (inNode != nil && inPlaylist != nil)
	{
		NSArray *playlistItems = [inPlaylist objectForKey:@"Playlist Items"];
		NSMutableArray *playlistTracks = [NSMutableArray array];
        NSMutableSet *locations = [NSMutableSet set];	// for avoiding duplicates
		NSMutableDictionary *track;
		NSAutoreleasePool* pool;
		NSString *key;

		if (playlistItems)
		{
			unsigned int i,n = [playlistItems count];
			
			for (i=0; i<n; i++)
			{
				// Get next track in this playlist...
				
				pool = [[NSAutoreleasePool alloc] init];
				key = [[[playlistItems objectAtIndex:i] objectForKey:@"Track ID"] stringValue];
				
				if (track = [NSMutableDictionary dictionaryWithDictionary:[inTracks objectForKey:key]])
				{
					NSString* location = [track objectForKey:@"Location"];
					
					// Only use it if it's a video and we don't already have it...
					
					if ([track objectForKey:@"Name"] && 
						[[track objectForKey:@"Has Video"] boolValue] &&
						[location length] > 0 &&
						[locations containsObject:location]==NO) 
					{
						NSURL *url = [NSURL URLWithString:location];
						NSString *path = [url path];
						if (path != nil)
						{
							[locations addObject:location];
							
							NSMutableDictionary* movieTrack = [track mutableCopy];
							[movieTrack setObject:path forKey:@"ImagePath"];
							[movieTrack setObject:path forKey:@"Preview"];
							[movieTrack setObject:[track objectForKey:@"Name"] forKey:@"Caption"];
							[playlistTracks addObject:movieTrack];
							[movieTrack release];
							hasVideos = YES;
						}
					}
				}
				[pool release];
			}
		}
		
		[inNode setAttribute:playlistTracks forKey:@"Movies"];
	}
	
	return hasVideos;
}

- (iMBLibraryNode *)parseDatabase:(NSMutableDictionary *)inLibrary forPlaylistWithKey:(NSString *)inKey name:(NSString *)inName iconName:(NSString *)inIconName
{
	// Create a node for the playlist with the specified key...
	
	iMBLibraryNode *node = nil;
	NSDictionary *tracks = nil;
	NSArray *playlists = nil;
	NSDictionary *playlist = nil;
	BOOL hasVideos = NO;
	 
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
							[node setIdentifier:inName];
							[node setParserClassName:NSStringFromClass([self class])];
//							[node setWatchedPath:myDatabase];
							
							hasVideos = [self populateNode:node withTracks:tracks fromPlaylist:playlist];
						}
					}
				}
			}
		}
	}
	
	// Only return this node if it does contain video tracks...
	
	return hasVideos ? node : nil;	
}

- (NSMutableArray *)parseDatabase:(NSMutableDictionary *)inLibrary forPlaylistsWithParentID:(NSString *)inParentID
{
	// Create nodes for playlists at the specified level...
	
	NSMutableArray *nodes = [NSMutableArray array];
	iMBLibraryNode *node = nil;
	NSDictionary *tracks = nil;
	NSArray *playlists = nil;
	NSDictionary *playlist = nil;
	BOOL hasVideos = NO;
	 
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
								[node setIdentifier:[playlist objectForKey:@"Name"]];
								[node setParserClassName:NSStringFromClass([self class])];
//								[node setWatchedPath:myDatabase];
								
								NSMutableArray* subnodes = [self parseDatabase:inLibrary forPlaylistsWithParentID:selfID];
								if (node!=nil && subnodes!=nil && [subnodes count] > 0)
								{
									[node setAllItems:subnodes];
									[nodes addObject:node];
								}	
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
							if ([playlist objectForKey:@"Smart Info"] != nil && 
								[playlist objectForKey:@"Folder"] == nil &&
								[playlist objectForKey:@"Master"] == nil &&
								[playlist objectForKey:@"Music"] == nil &&
								[playlist objectForKey:@"Movies"] == nil &&
								[playlist objectForKey:@"TV Shows"] == nil &&
								[playlist objectForKey:@"Music Videos"] == nil &&
								[playlist objectForKey:@"Podcasts"] == nil &&
								[playlist objectForKey:@"Audiobooks"] == nil &&
								[playlist objectForKey:@"Purchased Music"] == nil &&
								[playlist objectForKey:@"Party Shuffle"] == nil)
							{
								node = [[[iMBLibraryNode alloc] init] autorelease];
								[node setName:[playlist objectForKey:@"Name"]];
								if (_version == 7) [node setIconName:@"itunes-icon-playlist-smart7"];
								else [node setIconName:@"itunes-icon-playlist-smart"];
								[node setIdentifier:[playlist objectForKey:@"Name"]];
								[node setParserClassName:NSStringFromClass([self class])];
//								[node setWatchedPath:myDatabase];
								
								if (node)
								{
									hasVideos = [self populateNode:node withTracks:tracks fromPlaylist:playlist];
									if (hasVideos) [nodes addObject:node];
								}	
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
								[playlist objectForKey:@"Movies"] == nil &&
								[playlist objectForKey:@"TV Shows"] == nil &&
								[playlist objectForKey:@"Music Videos"] == nil &&
								[playlist objectForKey:@"Podcasts"] == nil &&
								[playlist objectForKey:@"Audiobooks"] == nil &&
								[playlist objectForKey:@"Purchased Music"] == nil &&
								[playlist objectForKey:@"Party Shuffle"] == nil &&
								[playlist objectForKey:@"Folder"] == nil &&
								[playlist objectForKey:@"Smart Info"] == nil)
							{
								node = [[[iMBLibraryNode alloc] init] autorelease];
								[node setName:[playlist objectForKey:@"Name"]];
								if (_version == 7) [node setIconName:@"itunes-icon-playlist-normal7"];
								else [node setIconName:@"itunes-icon-playlist-normal"];
								[node setIdentifier:[playlist objectForKey:@"Name"]];
								[node setParserClassName:NSStringFromClass([self class])];
//								[node setWatchedPath:myDatabase];
								
								if (node)
								{
									hasVideos = [self populateNode:node withTracks:tracks fromPlaylist:playlist];
									if (hasVideos) [nodes addObject:node];
								}
							}
						}
					}
				}
			}
		}
	}
	
	return nodes;	
}

#if RECURSIVE_PARSEDATABASE

- (iMBLibraryNode *)parseDatabase
{
	// Read the iTunes database from the XML file...
	
	NSMutableDictionary *iTunesLibrary = [NSMutableDictionary dictionary];
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",(CFStringRef)@"com.apple.iApps");
	NSArray *libraries = [NSMakeCollectable(iApps) autorelease];
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject])
	{
		NSURL* url = [NSURL URLWithString:cur];
		[myDatabase release];
		myDatabase = [[url path] retain];
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:url];
		if (db)
		{
			_version = [[db objectForKey:@"Application Version"] intValue];
			[iTunesLibrary addEntriesFromDictionary:db];
		}
	}
	
	if ([iTunesLibrary count])
	{
		// Create the root node...
		
		iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
		[root setName:LocalizedStringInIMedia(@"iTunes", @"iTunes")];
		[root setIconName:@"com.apple.iTunes:"];
        [root setIdentifier:@"iTunes"];
        [root setParserClassName:NSStringFromClass([self class])];
		[root setWatchedPath:myDatabase];
		
		[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Movies"];
		
		// Create standard nodes for iTunes 7...
		
		iMBLibraryNode *node;
		NSString *name,*icon;

		if (_version == 7)
		{
			name = LocalizedStringInIMedia(@"Movies", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-movies";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Movies" name:name iconName:icon];
			if (node) [root addItem:node];

			name = LocalizedStringInIMedia(@"TV Shows", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-tvshows";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"TV Shows" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Podcasts", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-podcasts7";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Podcasts" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Purchased", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-purchased7";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Purchased Music" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Party Shuffle", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-partyshuffle7";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Party Shuffle" name:name iconName:icon];
			if (node) [root addItem:node];
		}
		
		// Create standard nodes for older iTunes versions...
		
		else
		{
			name = LocalizedStringInIMedia(@"Library", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-library";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Master" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Podcasts", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-podcasts";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Podcasts" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Purchased", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-purchased";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Purchased Music" name:name iconName:icon];
			if (node) [root addItem:node];
			
			name = LocalizedStringInIMedia(@"Party Shuffle", @"Library as titled in iTunes source list");
			icon = @"itunes-icon-partyshuffle";
			node = [self parseDatabase:iTunesLibrary forPlaylistWithKey:@"Party Shuffle" name:name iconName:icon];
			if (node) [root addItem:node];
		}
		
		// Create user nodes...
		
		NSEnumerator *nodes = [[self parseDatabase:iTunesLibrary forPlaylistsWithParentID:nil] objectEnumerator];
		while (node = [nodes nextObject]) [root addItem:node];
		
		// Return the root node if we have videos in iTunes...
		
		if ([[root allItems] count] > 0) return root;
	}
	
	return nil;
}

#else

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
		NSURL* url = [NSURL URLWithString:cur];
		[myDatabase release];
		myDatabase = [[url path] retain];
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:url];
		if (db) {
			[iTunesLibrary addEntriesFromDictionary:db];
		}
	}
	
    // Create the root node
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInIMedia(@"iTunes", @"iTunes")];
	[root setIconName:@"com.apple.iTunes"];
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Movies"];
	[root setIdentifier:@"iTunes"];
	[root setParserClassName:NSStringFromClass([self class])];
	[root setWatchedPath:myDatabase];
	
    // Create default subnodes
	iMBLibraryNode *library = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *podcastLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *partyShuffleLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *moviesLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *purchasedLib = [[iMBLibraryNode alloc] init];
	NSMutableArray *smartPlaylists = [NSMutableArray array];
	
	[library setName:LocalizedStringInIMedia(@"Library", @"Library as titled in iTunes source list")];
	[library setIconName:@"MBiTunesLibrary"];
	[library setIdentifier:@"Library"];
	[library setParserClassName:NSStringFromClass([self class])];
//	[library setWatchedPath:myDatabase];
	
	[podcastLib setName:LocalizedStringInIMedia(@"Podcasts", @"Podcasts as titled in iTunes source list")];
	[podcastLib setIconName:@"MBiTunesPodcast"];
	[podcastLib setIdentifier:@"Podcasts"];
	[podcastLib setParserClassName:NSStringFromClass([self class])];
//	[podcastLib setWatchedPath:myDatabase];
	
	[partyShuffleLib setName:LocalizedStringInIMedia(@"Party Shuffle", @"Party Shuffle as titled in iTunes source list")];
	[partyShuffleLib setIconName:@"MBiTunesPartyShuffle"];
	[partyShuffleLib setIdentifier:@"Party Shuffle"];
	[partyShuffleLib setParserClassName:NSStringFromClass([self class])];
//	[partyShuffleLib setWatchedPath:myDatabase];
	
	[moviesLib setName:LocalizedStringInIMedia(@"Videos", @"Videos as titled in iTunes source list")];
	[moviesLib setIconName:@"iTunesVideo"];
	[moviesLib setIdentifier:@"Videos"];
	[moviesLib setParserClassName:NSStringFromClass([self class])];
//	[moviesLib setWatchedPath:myDatabase];
	
	[purchasedLib setName:LocalizedStringInIMedia(@"Purchased", @"Purchased folder as titled in iTunes source list")];
	[purchasedLib setIconName:@"MBiTunesPurchasedPlaylist"];
	[purchasedLib setIdentifier:@"Purchased"];
	[purchasedLib setParserClassName:NSStringFromClass([self class])];
//	[purchasedLib setWatchedPath:myDatabase];
	
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
				[node setIdentifier:[playListDict objectForKey:@"Name"]];
				[node setParserClassName:NSStringFromClass([self class])];
//				[node setWatchedPath:myDatabase];
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

#endif

@end
