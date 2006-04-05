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

#import "iMBiTunesVideoParser.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "NSWorkspace+Extensions.h"
#import "QTMovie+iMedia.h"

#import <QTKit/QTKit.h>

@implementation iMBiTunesVideoParser

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
	NSMutableDictionary *musicLibrary = [NSMutableDictionary dictionary];
	NSMutableArray *playLists = [NSMutableArray array];
	
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
	
	// purge empty entries here....
	
	NSEnumerator * enumerator = [[musicLibrary objectForKey:@"Tracks"] keyEnumerator];
	id key;
	int x = 0;
	
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:NSLocalizedString(@"iTunes", @"iTunes")];
	[root setIconName:@"MBiTunes"];
	
	iMBLibraryNode *library = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *podcastLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *partyShuffleLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *videoLib = [[iMBLibraryNode alloc] init];
	iMBLibraryNode *purchasedLib = [[iMBLibraryNode alloc] init];
	NSMutableArray *smartPlaylists = [NSMutableArray array];
	
	[library setName:NSLocalizedString(@"Library", @"Library")];
	[library setIconName:@"MBiTunesLibrary"];
	
	[podcastLib setName:NSLocalizedString(@"Podcasts", @"Podcasts")];
	[podcastLib setIconName:@"MBiTunesPodcast"];
	
	[partyShuffleLib setName:NSLocalizedString(@"Party Shuffle", @"Party Shuffle")];
	[partyShuffleLib setIconName:@"MBiTunesPartyShuffle"];
	
	[videoLib setName:NSLocalizedString(@"Videos", @"Videos")];
	[videoLib setIconName:@"iTunesVideo"];
	
	[purchasedLib setName:NSLocalizedString(@"Purchased", @"Purchased")];
	[purchasedLib setIconName:@"MBiTunesPurchasedPlaylist"];
	
	int playlistCount = [[musicLibrary objectForKey:@"Playlists"] count];
	
	for (x=0;x<playlistCount;x++)
	{
		NSMutableArray *newPlaylist = [NSMutableArray array];
		NSArray *libraryItems = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Playlist Items"];
		int i;
		BOOL hasVideos = NO;
		for (i=0; i<[libraryItems count]; i++)
		{
			NSDictionary * tracksDictionary = [musicLibrary objectForKey:@"Tracks"];
			NSDictionary * newPlaylistContent = [tracksDictionary objectForKey:[[[libraryItems objectAtIndex:i] objectForKey:@"Track ID"] stringValue]];
			if ([newPlaylistContent objectForKey:@"Name"] && 
				[[newPlaylistContent objectForKey:@"Location"] length] > 0 &&
				[newPlaylistContent objectForKey:@"Has Video"] && [[newPlaylistContent objectForKey:@"Has Video"] boolValue]) 
			{
				// only add video tracks
				NSImage *thumb = nil;
				NSMutableDictionary *movieRec = [NSMutableDictionary dictionaryWithDictionary:newPlaylistContent];
				NSError *error = nil;
				NSString *path = [[NSURL URLWithString:[newPlaylistContent objectForKey:@"Location"]] path];
				
				QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:path];
				QTMovie *movie = [[QTMovie alloc] initWithDataReference:ref error:&error];
				if (nil != movie)
				{
					thumb = [movie betterPosterImage];
					
					[movie release];
				}
				else
				{
					NSLog(@"Error reading movie '%@': %@", path, [error localizedDescription]);
				}
				if (thumb)
				{
					[movieRec setObject:thumb forKey:@"CachedThumb"];
					NSLog(@"Got thumb for %@", path);
				}
				else
				{
					[movieRec setObject:[[NSWorkspace sharedWorkspace]
						iconForAppWithBundleIdentifier:@"com.apple.quicktimeplayer"]
								   forKey:@"CachedThumb"];
				}
				
				[newPlaylist addObject:movieRec];
				hasVideos = YES;
			}
		}
		if (hasVideos)
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
				node = videoLib;
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
			[node setAttribute:newPlaylist forKey:@"Movies"];
		}
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
		if ([videoLib attributeForKey:@"Movies"])
		{
			[root insertItem:videoLib atIndex:idx];
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
