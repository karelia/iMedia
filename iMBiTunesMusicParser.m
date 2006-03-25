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
 
 In the case of iMediaBrowse, in addition to the terms noted above, in any 
 application that uses iMediaBrowse, we ask that you give a small attribution to 
 the members of CocoaDev.com who had a part in developing the project. Including, 
 but not limited to, Jason Terhorst, Greg Hulands and Ben Dunton.
 
 Greg doesn't really want acknowledgement he just want bug fixes as he has rewritten
 practically everything but the xml parsing stuff. Please send fixes to 
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 */

#import "iMBiTunesMusicParser.h"
#import "iMBLibraryNode.h"
#import "iMediaBrowser.h"

@implementation iMBiTunesMusicParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"music"];
	
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
	
	[library setName:@"Library"];
	[library setIconName:@"MBiTunesLibrary"];
	
	[podcastLib setName:@"Podcasts"];
	[podcastLib setIconName:@"MBiTunesPodcast"];
	
	[partyShuffleLib setName:@"Party Shuffle"];
	[partyShuffleLib setIconName:@"MBiTunesPartyShuffle"];
	
	int playlistCount = [[musicLibrary objectForKey:@"Playlists"] count];
	
	for (x=0;x<playlistCount;x++)
	{
		NSString * objectName = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Name"];
		iMBLibraryNode *node = nil;
		if ([objectName isEqualToString:@"Library"])
		{
			node = library;
		}
		else if ([objectName isEqualToString:@"Podcasts"])
		{
			node = podcastLib;		
		}
		else if ([objectName isEqualToString:@"Party Shuffle"])
		{
			node = partyShuffleLib;
		}
		else
		{
			node = [[iMBLibraryNode alloc] init];
			[node setName:objectName];
			if ([[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Smart Info"])
			{
				[node setIconName:@"photocast_folder"];
			}
			else
			{
				[node setIconName:[self iconNameForPlaylist:[node name]]];
			}
			[root addItem:node];
			[node release];
		}
		
		NSMutableArray *newPlaylist = [NSMutableArray array];
		NSArray *libraryItems = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Playlist Items"];
		int i;
		for (i=0; i<[libraryItems count]; i++)
		{
			NSDictionary * tracksDictionary = [musicLibrary objectForKey:@"Tracks"];
			NSDictionary * newPlaylistContent = [tracksDictionary objectForKey:[[[libraryItems objectAtIndex:i] objectForKey:@"Track ID"] stringValue]];
			if ([newPlaylistContent objectForKey:@"Name"] && [[newPlaylistContent objectForKey:@"Location"] length] > 0)
			{
				[newPlaylist addObject:newPlaylistContent];
			}
		}
		[node setAttribute:newPlaylist forKey:@"Tracks"];
	}
	[root insertItem:library atIndex:0];
	[root insertItem:podcastLib atIndex:1];
	[root insertItem:partyShuffleLib atIndex:2];
	
	[library release];
	[podcastLib release];
	[partyShuffleLib release];
	
	return [root autorelease];
}

@end
